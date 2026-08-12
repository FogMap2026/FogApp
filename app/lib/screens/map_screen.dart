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
import '../services/visited_spots_service.dart';
import 'social/personality_test_screen.dart';

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

  /// 정복률(#51) 조회 결과 전체. 표시할 지역만 골라 쓴다.
  List<ConquestRegion> _conquest = const [];
  /// 카메라 중심에서 가장 가까운(=현재 보고 있는) 스팟. 정복률 표시 지역을 고르는 데 쓴다.
  Spot? _nearestLoadedSpot;

  /// 마지막으로 받은 내 위치. "내 위치로 이동" 버튼(#64)에 쓴다.
  double? _myLat;
  double? _myLng;

  /// 이미 인증한 스팟 id 목록(#46) — 이 스팟들은 반경에 들어와도 알리지 않는다.
  Set<int> _visitedSpotIds = const {};
  /// 이번 앱 실행 세션에서 이미 알림을 띄운 스팟(#46) — 같은 스팟에 재진입해도
  /// 세션당 1회만 알린다. geofencing의 히스테리시스는 경계 떨림만 막을 뿐,
  /// 반경을 벗어났다가 다시 들어오는 재진입까지는 막지 않기 때문에 별도로 둔다.
  final Set<int> _notifiedSpotIds = {};
  /// 지금 화면에 떠 있는 근접 알림 배너(#46). 새 스팟에 진입하면 큐잉하지 않고
  /// 가장 최근 것으로 교체한다 — 오래된 배너를 계속 쌓아두는 것보다 "지금 여기"가
  /// 사용자에게 더 유용한 정보라고 판단했다.
  GeofenceEnterEvent? _proximityBanner;

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
    final spotId = event.spot.id;
    if (_visitedSpotIds.contains(spotId)) return; // 이미 인증한 스팟은 알리지 않는다.
    if (_notifiedSpotIds.contains(spotId)) return; // 세션당 1회.
    _notifiedSpotIds.add(spotId);
    if (mounted) setState(() => _proximityBanner = event);
  }

  void _onGeofenceExit(Spot spot) {
    // 배너를 보기 전에 반경을 벗어나면(예: 그냥 지나침) 더 이상 유효하지 않으니 닫는다.
    if (_proximityBanner?.spot.id == spot.id && mounted) {
      setState(() => _proximityBanner = null);
    }
  }

  void _dismissProximityBanner() {
    if (mounted) setState(() => _proximityBanner = null);
  }

  void _openVisitVerify(Spot spot) {
    setState(() => _proximityBanner = null);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _MockVisitVerifyScreen(spot: spot, onVerified: () => _onVisitVerified(spot)),
      ),
    );
  }

  /// 이미 인증한 스팟 목록(#46)을 새로 불러오고, 그 좌표로 안개 상태를 복원한다(#49).
  /// 실패해도 지도 자체는 동작해야 하므로(조용히 필터·복원이 안 걸릴 뿐) 예외를 삼킨다
  /// — 정복률(#51)과 같은 원칙.
  Future<void> _refreshVisitedSpots() async {
    try {
      final visited = await ref.read(visitedSpotsServiceProvider).fetchVisitedSpots();
      if (!mounted) return;
      setState(() => _visitedSpotIds = {for (final v in visited) v.spotId});
      // 애니메이션 없이 즉시 걷어낸다 — 이미 걷힌 영역을 매번 앱을 켤 때마다 다시
      // "퍼지는" 연출로 보여줄 이유는 없다(#49 to-do: 재진입 시 유지).
      _fogOverlay?.clearCircles({for (final v in visited) v.spotId.toString(): v.center});
    } catch (_) {
      // no-op
    }
  }

  /// 방문 인증에 성공했을 때 호출한다(#49). 해당 스팟 반경의 안개를 퍼지는 애니메이션과
  /// 함께 걷어내고, 이후 이 스팟에는 근접 알림(#46)을 다시 띄우지 않도록 방문 목록에
  /// 반영한다. 정복률(#51)도 즉시 갱신해 인증 직후 숫자가 바로 올라간 것처럼 보이게 한다.
  void _onVisitVerified(Spot spot) {
    unawaited(
      _fogOverlay?.clearCircleAnimated(spot.id.toString(), NLatLng(spot.lat, spot.lng)),
    );
    if (mounted) {
      setState(() => _visitedSpotIds = {..._visitedSpotIds, spot.id});
    }
    unawaited(_refreshConquest());
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
    unawaited(_refreshVisitedSpots());
    await _requestLocationPermission();
  }

  /// 정복률(#51) 목록을 새로 불러온다. 스팟 인증(#47)이 이 화면에 연결되면
  /// 인증 성공 직후에도 호출해 최신 수치를 반영해야 한다.
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
                  if (_proximityBanner != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _ProximityBanner(
                        event: _proximityBanner!,
                        onDismiss: _dismissProximityBanner,
                        onVerify: () => _openVisitVerify(_proximityBanner!.spot),
                      ),
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

/// 스팟 반경 진입 알림 배너(#46). "여기서 인증할 수 있다"는 것을 알리고 방문 인증
/// 화면으로 가는 버튼을 제공한다.
class _ProximityBanner extends StatelessWidget {
  const _ProximityBanner({
    required this.event,
    required this.onDismiss,
    required this.onVerify,
  });

  final GeofenceEnterEvent event;
  final VoidCallback onDismiss;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distanceLabel = '${event.distanceMeters.toStringAsFixed(0)}m';

    return Material(
      color: theme.colorScheme.primaryContainer,
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          children: [
            Icon(Icons.explore_outlined, size: 20, color: theme.colorScheme.onPrimaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${event.spot.title} 근처예요 ($distanceLabel) — 지금 인증할 수 있어요',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimaryContainer),
              ),
            ),
            TextButton(onPressed: onVerify, child: const Text('인증하러 가기')),
            IconButton(
              onPressed: onDismiss,
              icon: Icon(Icons.close, size: 18, color: theme.colorScheme.onPrimaryContainer),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

/// 방문 인증 화면(#47)이 병합되기 전까지 붙여두는 자리표시자(#46 issue의 "목으로 먼저
/// 붙여도 됨" 제안). #47이 merge되면 이 위젯 대신 실제 화면으로 교체하고, 안개 걷힘
/// 연출(#49)은 실제 인증 API 성공 응답을 받는 지점에서 [onVerified]를 호출하도록 옮긴다.
class _MockVisitVerifyScreen extends StatelessWidget {
  const _MockVisitVerifyScreen({required this.spot, required this.onVerified});

  final Spot spot;

  /// 실제로는 `POST /api/visits`(#48) 성공 응답을 받는 지점에서 호출돼야 한다.
  /// 여기서는 그 지점이 아직 없어 버튼으로 대신 트리거한다 — #47이 merge되면 사라진다.
  final VoidCallback onVerified;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(spot.title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined, size: 48),
              const SizedBox(height: 16),
              Text(
                '현장 사진 촬영 → 방문 인증 화면은 준비 중입니다.\n(#47에서 연결될 예정)',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  onVerified();
                  Navigator.of(context).pop();
                },
                child: const Text('인증 완료 (임시 — #47 병합 전 테스트용)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
