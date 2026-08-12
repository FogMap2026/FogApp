import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../models/conquest.dart';
import '../models/spot.dart';
import '../services/conquest_service.dart';
import '../services/fog_location_tracker.dart';
import '../services/fog_overlay_controller.dart';
import '../services/location_permission_gate.dart';
import '../services/region_lookup_service.dart';
import '../services/spot_geofence_controller.dart';
import '../services/spot_marker_controller.dart';
import '../services/spot_service.dart';
import 'social/personality_test_screen.dart';
import 'visit_verify_screen.dart';

/// 대한민국 전역을 보여주는 기본 카메라 위치(안개 지도의 시작 화면).
const _southKoreaCenter = NLatLng(36.5, 127.8);

/// 지도 이동(pan) 가능 범위. FogApp은 국내 탐험이 목적이므로 대한민국 전역
/// (마라도~독도) 정도만 여유 있게 덮는 범위로 제한한다.
const _mapExtent = NLatLngBounds(
  southWest: NLatLng(32.5, 124.0),
  northEast: NLatLng(39.0, 132.5),
);

/// 탐험의 메인 화면. Naver Map 기반 지도를 표시한다.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> with WidgetsBindingObserver {
  NaverMapController? _controller;
  StreamSubscription<OnCameraChangedParams>? _cameraSubscription;
  FogOverlayController? _fogOverlay;
  SpotMarkerController? _spotMarkers;
  SpotGeofenceController? _geofence;
  StreamSubscription<Position>? _geofencePositionSubscription;
  StreamSubscription<GeofenceEnterEvent>? _geofenceEnterSubscription;
  StreamSubscription<Spot>? _geofenceExitSubscription;

  bool _mapReady = false;
  bool? _locationServiceEnabled;
  LocationPermission? _permission;
  String? _regionName;
  bool _regionLookupFailed = false;

  /// 반경 안에 들어와 인증 가능한 스팟(#45 진입 이벤트로 채워짐, #47 진입점).
  Spot? _nearbySpot;

  /// 정복률(#51) 조회 결과 전체. 표시할 지역만 골라 쓴다.
  List<ConquestRegion> _conquest = const [];
  /// 카메라 중심에서 가장 가까운(=현재 보고 있는) 스팟. 정복률 표시 지역을 고르는 데 쓴다.
  Spot? _nearestLoadedSpot;

  /// 마지막으로 받은 내 위치. "내 위치로 이동" 버튼(#64)과 인증 화면 진입(#47)에 쓴다.
  double? _myLat;
  double? _myLng;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 위치 권한 요청은 onMapReady에서 한 번만 수행한다(중복 요청 시 Android가
    // "Can request only one set of permissions at a time"로 두 번째 요청을 무시함).
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraSubscription?.cancel();
    _geofencePositionSubscription?.cancel();
    _geofenceEnterSubscription?.cancel();
    _geofenceExitSubscription?.cancel();
    _fogOverlay?.dispose();
    _spotMarkers?.dispose();
    _geofence?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 백그라운드 진입 시 위치 추적을 끄고, 포그라운드 복귀 시 다시 켠다.
    // geofencing(#45)도 같은 정책을 따른다 — 백그라운드 감지는 #46에서 별도로 다룬다.
    final controller = _controller;
    if (controller == null) return;
    if (state == AppLifecycleState.resumed) {
      if (_permission == LocationPermission.always ||
          _permission == LocationPermission.whileInUse) {
        controller.setLocationTrackingMode(NLocationTrackingMode.follow);
        _startGeofenceTracking();
      }
    } else if (state == AppLifecycleState.paused) {
      controller.setLocationTrackingMode(NLocationTrackingMode.none);
      _geofencePositionSubscription?.cancel();
      _geofencePositionSubscription = null;
    }
  }

  Future<void> _requestLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (mounted) setState(() => _locationServiceEnabled = serviceEnabled);
    if (!serviceEnabled) return;

    final permission = await LocationPermissionGate.request();
    if (mounted) setState(() => _permission = permission);

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    _controller?.setLocationTrackingMode(NLocationTrackingMode.follow);
    _startGeofenceTracking();
  }

  /// 실시간 위치 스트림을 구독해 [_geofence]에 반영한다(#45). [FogLocationTracker]와
  /// 같은 [LocationSettings]를 재사용해 서로 다른 배터리 절충안이 섞이지 않게 한다.
  void _startGeofenceTracking() {
    if (_geofencePositionSubscription != null) return;
    _geofencePositionSubscription = Geolocator.getPositionStream(
      locationSettings: FogLocationTracker.locationSettings,
    ).listen((position) {
      // 위치를 처음 받는 순간만 rebuild해서 "내 위치로 이동" 버튼을 활성화한다.
      // 매 위치 갱신마다 다시 그릴 필요는 없다.
      final hadLocation = _myLat != null;
      _myLat = position.latitude;
      _myLng = position.longitude;
      if (!hadLocation && mounted) setState(() {});
      _geofence?.updatePosition(lat: position.latitude, lng: position.longitude);
    });
  }

  /// 카메라를 마지막으로 받은 내 위치로 이동한다. SDK 기본 위치 버튼
  /// (`locationButtonEnable`) 대신 우측 컨트롤에 이 버튼을 직접 그린다(#64) —
  /// 지도 좌하단(Naver 로고 자리)과 겹치지 않게 하기 위함.
  void _recenterToMe() {
    final lat = _myLat;
    final lng = _myLng;
    if (lat == null || lng == null) return;
    _controller?.updateCamera(NCameraUpdate.withParams(target: NLatLng(lat, lng)));
  }

  void _onGeofenceEnter(GeofenceEnterEvent event) {
    // TODO(#46): 근접 알림(로컬/푸시)으로 보강. 지금은 이 화면에 인증 버튼을 띄우는
    // 것으로 진입점(#47)을 연결하고, 로그도 함께 남긴다.
    debugPrint(
      '[Geofence] 진입: ${event.spot.title} (${event.distanceMeters.toStringAsFixed(0)}m)',
    );
    if (mounted) setState(() => _nearbySpot = event.spot);
  }

  void _onGeofenceExit(Spot spot) {
    debugPrint('[Geofence] 이탈: ${spot.title}');
    if (mounted && _nearbySpot?.id == spot.id) {
      setState(() => _nearbySpot = null);
    }
  }

  Future<void> _openVisitVerify() async {
    final spot = _nearbySpot;
    final lat = _myLat;
    final lng = _myLng;
    if (spot == null || lat == null || lng == null) return;

    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VisitVerifyScreen(spot: spot, currentLat: lat, currentLng: lng),
      ),
    );
    // 인증 성공(또는 이미 반경을 벗어난 경우)이면 배너를 내린다. 실패/취소 시에는
    // 반경 안에 계속 있는 한 다시 시도할 수 있도록 배너를 유지한다.
    if (verified == true) {
      if (mounted && _nearbySpot?.id == spot.id) {
        setState(() => _nearbySpot = null);
      }
      // 방금 인증한 스팟만큼 정복률이 올랐을 것이므로 다시 불러온다.
      unawaited(_refreshConquest());
    }
  }

  void _onMapReady(NaverMapController controller) async {
    _controller = controller;
    controller.setMyLocationTracker(FogLocationTracker());
    _fogOverlay = await FogOverlayController.attach(controller);
    _geofence = SpotGeofenceController();
    _geofenceEnterSubscription = _geofence!.onEnter.listen(_onGeofenceEnter);
    _geofenceExitSubscription = _geofence!.onExit.listen(_onGeofenceExit);
    _spotMarkers = SpotMarkerController(
      controller,
      ref.read(spotServiceProvider),
      onSpotsLoaded: (spots) {
        _geofence?.updateCandidates(spots);
        // fetchNearby는 가까운 순으로 내려주므로 첫 번째가 현재 보고 있는 지역의 대표 스팟이다.
        if (mounted) setState(() => _nearestLoadedSpot = spots.isEmpty ? null : spots.first);
      },
    );
    _cameraSubscription = controller.nowCameraPositionStream.listen(_onCameraChanged);
    if (mounted) setState(() => _mapReady = true);
    final initialTarget = controller.nowCameraPosition.target;
    unawaited(_lookupRegion(initialTarget));
    unawaited(_spotMarkers?.loadAround(initialTarget));
    unawaited(_refreshConquest());
    await _requestLocationPermission();
  }

  /// 정복률(#51) 목록을 새로 불러온다. 지도 진입 시, 그리고 방문 인증(#47) 성공 직후 호출한다.
  Future<void> _refreshConquest() async {
    try {
      final regions = await ref.read(conquestServiceProvider).myConquest();
      if (mounted) setState(() => _conquest = regions);
    } catch (_) {
      // 정복률은 보조 정보라 실패해도 지도 사용을 막지 않는다 — 플레이스홀더로 남겨둔다.
    }
  }

  /// 현재 보고 있는 지역의 정복률. 대표 스팟의 areaCode/sigunguCode로 [_conquest]에서 찾는다.
  ConquestRegion? get _currentConquest {
    final spot = _nearestLoadedSpot;
    final areaCode = spot?.areaCode;
    if (areaCode == null) return null;
    final code = regionCodeFor(areaCode: areaCode, sigunguCode: spot?.sigunguCode);
    for (final region in _conquest) {
      if (region.regionCode == code) return region;
    }
    return null;
  }

  void _onCameraChanged(OnCameraChangedParams params) {
    if (!params.isIdle) return;
    unawaited(_lookupRegion(params.position.target));
    unawaited(_spotMarkers?.loadAround(params.position.target));
  }

  Future<void> _lookupRegion(NLatLng target) async {
    try {
      final placemarks = await placemarkFromCoordinates(target.latitude, target.longitude);
      final name = placemarks.isEmpty ? null : regionNameFromPlacemark(placemarks.first);
      if (!mounted) return;
      setState(() {
        _regionName = name;
        _regionLookupFailed = name == null;
      });
    } catch (_) {
      if (mounted) setState(() => _regionLookupFailed = true);
    }
  }

  void _zoomBy(double delta) {
    _controller?.updateCamera(NCameraUpdate.zoomBy(delta));
  }

  _LocationIssue? get _locationIssue {
    if (_locationServiceEnabled == false) {
      return _LocationIssue(
        message: '위치 서비스가 꺼져 있어 내 위치를 표시할 수 없습니다.',
        actionLabel: '설정 열기',
        onAction: () async {
          await Geolocator.openLocationSettings();
        },
      );
    }
    if (_permission == LocationPermission.deniedForever) {
      return _LocationIssue(
        message: '위치 권한이 거부되어 있습니다. 설정에서 허용해주세요.',
        actionLabel: '설정 열기',
        onAction: () async {
          await Geolocator.openAppSettings();
        },
      );
    }
    if (_permission == LocationPermission.denied) {
      return _LocationIssue(
        message: '위치 권한을 허용하면 내 위치를 지도에서 확인할 수 있어요.',
        actionLabel: '권한 허용',
        onAction: _requestLocationPermission,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final safeAreaPadding = MediaQuery.paddingOf(context);
    final locationIssue = _locationIssue;

    // SDK 콘텐츠 패딩에 우리 오버레이가 차지하는 대략적인 높이를 더한다 — 안 그러면
    // "내 위치로 이동" 시 마커가 상단 정보 바·하단 액션 영역 뒤에 숨을 수 있다(#64).
    final contentPadding = EdgeInsets.only(
      left: safeAreaPadding.left,
      right: safeAreaPadding.right,
      top: safeAreaPadding.top + 64,
      bottom: safeAreaPadding.bottom + 96,
    );

    return Scaffold(
      body: Stack(
        children: [
          NaverMap(
            options: NaverMapViewOptions(
              contentPadding: contentPadding,
              initialCameraPosition: const NCameraPosition(
                target: _southKoreaCenter,
                zoom: 6.7,
              ),
              // FogApp은 국내 탐험이 목적이므로 대한민국 밖으로 축소/이동할 이유가 없어 제한한다.
              minZoom: 6,
              extent: _mapExtent,
              // SDK 기본 위치 버튼 대신 우측 컨트롤에 직접 그린다(#64) — 좌하단 Naver
              // 로고 자리와 겹치는 걸 피하고, 우리 UI를 한 곳(우측 세로 스택)으로 모은다.
              locationButtonEnable: false,
              logoAlign: NLogoAlign.leftBottom,
              logoMargin: const EdgeInsets.only(left: 12, bottom: 12),
            ),
            onMapReady: _onMapReady,
          ),
          if (!_mapReady)
            const ColoredBox(
              color: Colors.black12,
              child: Center(child: CircularProgressIndicator()),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopInfoBar(
                    regionName: _regionName,
                    regionLookupFailed: _regionLookupFailed,
                    conquestRate: _currentConquest?.rate,
                  ),
                  if (locationIssue != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _LocationBanner(issue: locationIssue),
                    ),
                ],
              ),
            ),
          ),
          // 하단 좌측 액션 영역. 여러 오버레이가 늘어도 이 Column 하나에 세로로
          // 쌓이므로 서로 겹치지 않는다(#64 — 예전엔 독립된 Align끼리 포개졌음).
          // Naver 로고(좌하단, logoMargin 12)를 가리지 않도록 하단 여백을 넉넉히 둔다.
          SafeArea(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 64),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_nearbySpot != null) ...[
                      _NearbySpotBanner(spot: _nearbySpot!, onVerify: _openVisitVerify),
                      const SizedBox(height: 8),
                    ],
                    FilledButton.tonal(
                      // 지도 위 탐험 UI가 준비될 때까지 성향 테스트(#31)로 가는 임시 진입점.
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PersonalityTestScreen()),
                      ),
                      child: const Text('여행 성향 테스트 하기'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _MapControls(
                  onZoomIn: () => _zoomBy(1),
                  onZoomOut: () => _zoomBy(-1),
                  onRecenter: _myLat != null ? _recenterToMe : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 지도 상단 정보 바. 현재 지역(시/도)과 정복률(#51)을 보여준다.
class _TopInfoBar extends StatelessWidget {
  const _TopInfoBar({
    required this.regionName,
    required this.regionLookupFailed,
    required this.conquestRate,
  });

  final String? regionName;
  final bool regionLookupFailed;

  /// 0.0~1.0. 아직 못 구했으면(스팟 미로드·API 실패 등) null — 플레이스홀더로 표시한다.
  final double? conquestRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = regionName ?? (regionLookupFailed ? '지역 정보를 가져올 수 없어요' : '지역 확인 중…');
    final rate = conquestRate;
    final rateLabel = rate == null ? '정복률 --%' : '정복률 ${(rate * 100).round()}%';

    return Material(
      color: theme.colorScheme.surface.withOpacity(0.92),
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.place_outlined, size: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Chip(
              label: Text(rateLabel),
              visualDensity: VisualDensity.compact,
              backgroundColor: theme.colorScheme.secondaryContainer,
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationIssue {
  const _LocationIssue({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;
}

class _LocationBanner extends StatelessWidget {
  const _LocationBanner({required this.issue});

  final _LocationIssue issue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.location_off_outlined, size: 20, color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                issue.message,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onErrorContainer),
              ),
            ),
            TextButton(
              onPressed: issue.onAction,
              child: Text(issue.actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// 인증 가능 반경 안에 들어왔을 때 뜨는 배너(#45 진입 이벤트 → #47 인증 화면 진입점).
class _NearbySpotBanner extends StatelessWidget {
  const _NearbySpotBanner({required this.spot, required this.onVerify});

  final Spot spot;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer,
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt_outlined, color: theme.colorScheme.onPrimaryContainer),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${spot.title} 반경 안이에요',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onPrimaryContainer),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(onPressed: onVerify, child: const Text('인증하기')),
          ],
        ),
      ),
    );
  }
}

/// 지도 우측 세로 컨트롤(#64) — 줌 인/아웃 + 내 위치로 이동을 한 곳에 모은다.
/// SDK 기본 위치 버튼과 중복되지 않도록 이 화면에서는 이 버튼만 쓴다.
class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRecenter,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback? onRecenter;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface.withOpacity(0.92),
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(onPressed: onZoomIn, icon: const Icon(Icons.add)),
          const Divider(height: 1),
          IconButton(onPressed: onZoomOut, icon: const Icon(Icons.remove)),
          const Divider(height: 1),
          IconButton(onPressed: onRecenter, icon: const Icon(Icons.my_location)),
        ],
      ),
    );
  }
}
