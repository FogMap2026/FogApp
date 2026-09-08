import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../models/conquest.dart';
import '../models/footprint.dart';
import '../models/spot.dart';
import '../services/background_tracking_setting.dart';
import '../services/character_overlay.dart';
import '../services/conquest_service.dart';
import '../services/fog_location_tracker.dart';
import '../services/fog_overlay_controller.dart';
import '../services/footprint_location_gate.dart';
import '../services/footprint_marker_controller.dart';
import '../services/footprint_service.dart';
import '../services/location_permission_gate.dart';
import '../services/location_service.dart';
import '../services/profile_service.dart';
import '../services/proximity_notifier.dart';
import '../services/region_lookup_service.dart';
import '../services/spot_geofence_controller.dart';
import '../services/spot_marker_controller.dart';
import '../services/spot_service.dart';
import '../services/visit_service.dart';
import '../widgets/footprint_card.dart';
import 'footprint_nearby_create_screen.dart';
import 'match_candidates_screen.dart';
import 'match_list_screen.dart';
import 'profile_screen.dart';
import 'social/personality_test_screen.dart';
import 'spot_detail_screen.dart';
import 'visit_verify_screen.dart';

/// 지도에 띄울 안내(#144, #146). 한 번에 하나만 뜬다.
enum MapNotice {
  /// 아무것도 띄우지 않는다.
  none,

  /// 서버에 닿지 못했다 — 스팟이 있는지 없는지 **알 수 없는** 상태.
  serverError,

  /// 조회는 됐는데 이 근처에 스팟이 0건이다.
  emptyArea,
}

/// 지금 어떤 안내를 띄울지 판정한다(#144, #146).
///
/// 반환값이 하나뿐인 것이 핵심이다. 불리언 두 개로 두면 **두 배너가 동시에 뜨는**
/// 상태를 만들 수 있는데, 여기서는 타입이 그걸 막는다.
///
/// ## 왜 실패가 "빈 지역"보다 먼저인가
///
/// 서버에 못 닿았으면 **이 근처에 스팟이 있는지 없는지 자체를 모른다.** 그런데도
/// "이 지역엔 탐험할 곳이 없어요"라고 하면 **틀린 정보다** — 보는 사람은 "데이터가
/// 없는 앱"으로 판단하는데, 실제로는 서버가 꺼진 것뿐이다(#146).
///
/// ## 조회 전과 "조회했는데 0건"도 다른 상태다
///
/// [spotsEverLoaded]를 보지 않으면 첫 조회가 끝나기 전에 "탐험할 곳이 없다"고 잘못
/// 알리게 된다 — 스팟이 있는 지역에서도 앱을 켤 때마다 잠깐씩 안내가 번쩍인다.
MapNotice mapNoticeFor({
  required bool loadFailed,
  required bool spotsEverLoaded,
  required int spotCount,
  required bool serverErrorDismissed,
  required bool emptyAreaDismissed,
}) {
  if (loadFailed) {
    return serverErrorDismissed ? MapNotice.none : MapNotice.serverError;
  }
  if (!spotsEverLoaded) return MapNotice.none;
  if (spotCount > 0) return MapNotice.none;
  return emptyAreaDismissed ? MapNotice.none : MapNotice.emptyArea;
}

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
  FootprintMarkerController? _footprintMarkers;
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

  /// 스팟 조회가 최소 한 번 끝났는지(#144). 조회 전과 "조회했는데 0건"은 다른 상태라,
  /// 이걸 구분하지 않으면 로딩 중에 "스팟이 없다"고 잘못 알리게 된다.
  bool _spotsEverLoaded = false;

  /// 빈 지도 안내를 사용자가 닫았는지(#144). 세션 동안만 유지한다 —
  /// 지역을 옮겨 다시 비어도 이미 읽은 안내를 또 띄우지 않는다.
  bool _emptyNoticeDismissed = false;

  /// 첫 위치를 받고 카메라를 내 위치로 한 번 맞췄는지(#144).
  ///
  /// `setLocationTrackingMode(follow)`는 카메라를 **옮기기만 하고 줌은 그대로 둔다.**
  /// 그래서 권한을 허용해도 전국 뷰(6.7)에 머물러 스팟이 한 점에 뭉쳐 보였다.
  /// 첫 측위 때 한 번만 줌을 맞추고, 그 뒤로는 사용자의 카메라 조작을 건드리지 않는다.
  bool _didZoomToFirstFix = false;

  /// 마지막 스팟 조회가 실패했는지(#146). 성공하면 다시 false가 된다.
  bool _spotLoadFailed = false;

  /// 서버 연결 안내를 사용자가 닫았는지(#146).
  ///
  /// 빈 지역 안내와 달리 **조회에 성공하면 다시 false로 되돌린다.** 한 번 닫았다고
  /// 이후의 모든 장애를 영영 숨기면, 서버가 다시 죽었을 때 또 아무 말도 못 하게 된다.
  bool _serverErrorDismissed = false;

  /// 마지막으로 스팟을 불러온 카메라 중심(#146). "다시 시도"가 쓴다.
  NLatLng? _lastLoadCenter;

  /// 마지막으로 받은 내 위치. "내 위치로 이동" 버튼(#64)과 인증 화면 진입(#47)에 쓴다.
  double? _myLat;
  double? _myLng;

  /// 이미 인증한 스팟 id 목록(#46) — 이 스팟들은 반경에 들어와도 알리지 않는다.
  Set<int> _visitedSpotIds = const {};
  /// 이미 인증한 스팟의 좌표(#117) — 해금된 스팟 반경(150m) 안에 있는지 판정해
  /// 발자취 조회 반경을 넓히는 데 쓴다.
  Map<int, NLatLng> _visitedSpotCoords = const {};
  /// 이번 앱 실행 세션에서 이미 알림을 띄운 스팟(#46) — 같은 스팟에 재진입해도
  /// 세션당 1회만 알린다. geofencing의 히스테리시스는 경계 떨림만 막을 뿐,
  /// 반경을 벗어났다가 다시 들어오는 재진입까지는 막지 않기 때문에 별도로 둔다.
  final Set<int> _notifiedSpotIds = {};
  /// 지금 화면에 떠 있는 근접 알림 배너(#46). 새 스팟에 진입하면 큐잉하지 않고
  /// 가장 최근 것으로 교체한다 — 오래된 배너를 계속 쌓아두는 것보다 "지금 여기"가
  /// 사용자에게 더 유용한 정보라고 판단했다.
  GeofenceEnterEvent? _proximityBanner;

  /// 남은 발자취 작성 횟수(#116, #118). null이면 아직 못 받아온 것 —
  /// 그동안은 버튼을 낙관적으로 활성 상태로 둔다(실제 소진 여부는 작성 시 429로도 걸러진다).
  int? _footprintQuota;
  /// GPS 측정+정확도 확인이 진행 중일 때 버튼 연타를 막는다.
  bool _footprintLocationChecking = false;

  /// 공유 위치 소스(#135). [dispose]에서도 써야 하는데 그 시점에는 `ref`를 쓸 수 없으므로
  /// 여기서 미리 잡아둔다.
  late final LocationService _locationService;

  /// 백그라운드 근접 알림(#135).
  late final ProximityNotifier _proximityNotifier;

  /// 앱이 화면에 떠 있는지. 근접을 배너로 알릴지 알림으로 보낼지를 가른다(#135).
  bool _appInForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locationService = ref.read(locationServiceProvider);
    _proximityNotifier = ref.read(proximityNotifierProvider);
    _restoreBackgroundTracking();
    // 위치 권한 요청은 onMapReady에서 한 번만 수행한다(중복 요청 시 Android가
    // "Can request only one set of permissions at a time"로 두 번째 요청을 무시함).
    _loadFootprintQuota();
  }

  /// 저장된 백그라운드 추적 설정을 서비스에 반영한다(#135). 기본값은 꺼짐이라,
  /// 켠 적 없는 사용자에게는 아무 변화가 없다.
  Future<void> _restoreBackgroundTracking() async {
    final mode = await BackgroundTrackingSetting.load();
    if (mode == LocationTrackingMode.foregroundOnly) return;
    await _locationService.setMode(mode);
    await _proximityNotifier.init();
  }

  /// 프로필에서 잔여 발자취 횟수만 읽어온다(#118). 실패해도 버튼을 막지 않는다 —
  /// 표시가 갱신되지 않을 뿐, 실제 소진 여부는 작성 시 서버가 429로 가른다.
  Future<void> _loadFootprintQuota() async {
    try {
      final profile = await ref.read(profileServiceProvider).me();
      if (mounted) setState(() => _footprintQuota = profile.footprintQuota);
    } catch (_) {
      // 조용히 넘어간다 — 위 주석 참고.
    }
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
    _footprintMarkers?.dispose();
    _geofence?.dispose();
    // 지금은 이 화면이 유일한 소비자라 화면이 사라지면 GPS도 끈다. 백그라운드 추적(#135)이
    // 붙으면 **이 판단만** 사용자 설정으로 옮기면 된다 — 서비스와 구독자는 그대로다.
    _locationService.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 백그라운드 진입 시 위치 추적을 끄고, 포그라운드 복귀 시 다시 켠다.
    // geofencing(#45)도 같은 정책을 따른다 — 백그라운드 감지는 #46에서 별도로 다룬다.
    final controller = _controller;
    if (controller == null) return;
    if (state == AppLifecycleState.resumed) {
      _appInForeground = true;
      unawaited(_locationService.setAppInForeground(true));
      if (_permission == LocationPermission.always ||
          _permission == LocationPermission.whileInUse) {
        controller.setLocationTrackingMode(NLocationTrackingMode.follow);
        _startGeofenceTracking();
      }
    } else if (state == AppLifecycleState.paused) {
      _appInForeground = false;
      controller.setLocationTrackingMode(NLocationTrackingMode.none);
      // 위치 구독은 끊지 않는다 — 백그라운드 추적을 켠 사용자에게는 여기서 끊으면
      // 기능 자체가 없어진다. GPS 를 끌지 말지는 설정을 아는 서비스가 정한다(#135).
      unawaited(_locationService.setAppInForeground(false));
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

  /// 공유 위치 소스([LocationService])를 구독해 [_geofence]·발자취 조회에 반영한다(#45, #117).
  ///
  /// 예전에는 여기서 `Geolocator.getPositionStream()`을 직접 열어, 지도 SDK 트래커가
  /// 연 것과 합쳐 GPS 구독이 두 개 돌았다. 이제 소스는 하나고 여기서는 구독만 한다(#135).
  void _startGeofenceTracking() {
    if (_geofencePositionSubscription != null) return;
    unawaited(_locationService.start());
    _geofencePositionSubscription = _locationService.positions.listen(_onPosition);

    // 이미 알고 있는 위치가 있으면 먼저 반영한다. `distanceFilter: 15`라 제자리에 서
    // 있으면 다음 이벤트가 오지 않아서, 화면을 다시 열었을 때 "내 위치로 이동"이 계속
    // 비활성으로 남아 있었다 — 캐시가 생기면서 풀리는 문제다.
    final lastKnown = _locationService.lastKnown;
    if (lastKnown != null) _onPosition(lastKnown);
  }

  void _onPosition(Position position) {
    // 위치를 처음 받는 순간만 rebuild해서 "내 위치로 이동" 버튼을 활성화한다.
    // 매 위치 갱신마다 다시 그릴 필요는 없다.
    final hadLocation = _myLat != null;
    _myLat = position.latitude;
    _myLng = position.longitude;
    if (!hadLocation && mounted) setState(() {});

    // 첫 측위에 한 번만 내 위치로 줌을 맞춘다(#144). 이게 없으면 권한을 허용해도
    // 전국 뷰에 머물러 "회색 화면에 점 하나"로 보인다 — 스팟이 없어서가 아니라
    // 전부 겹쳐 있어서다. 이후 갱신에서는 사용자의 카메라를 건드리지 않는다.
    if (!_didZoomToFirstFix) {
      _didZoomToFirstFix = true;
      _moveToMyLocation(position.latitude, position.longitude);
    }
    _geofence?.updatePosition(lat: position.latitude, lng: position.longitude);
    unawaited(
      _footprintMarkers?.updatePosition(
        lat: position.latitude,
        lng: position.longitude,
        insideUnlockedSpot: _isInsideUnlockedSpot(position.latitude, position.longitude),
      ),
    );
  }

  /// 해금된(방문 인증한) 스팟의 안개 걷힘 반경(150m) 안에 있는지(#117) — 발자취
  /// 조회 반경을 50m에서 150m로 넓힐지 판단하는 데 쓴다(문서 3-3).
  static const _unlockedSpotRadiusMeters = 150.0;

  bool _isInsideUnlockedSpot(double lat, double lng) {
    for (final coord in _visitedSpotCoords.values) {
      final distance = Geolocator.distanceBetween(lat, lng, coord.latitude, coord.longitude);
      if (distance <= _unlockedSpotRadiusMeters) return true;
    }
    return false;
  }

  /// 카메라를 마지막으로 받은 내 위치로 이동한다. SDK 기본 위치 버튼
  /// (`locationButtonEnable`) 대신 우측 컨트롤에 이 버튼을 직접 그린다(#64) —
  /// 지도 좌하단(Naver 로고 자리)과 겹치지 않게 하기 위함.
  ///
  /// **줌도 함께 올린다(#144).** 옮기기만 하면 초기 줌(6.7, 전국 뷰)에 그대로 머물러
  /// 조회 반경 5km가 화면에서 반경 4px쯤이 되고, 로드된 스팟이 전부 한 점에 겹쳐 쌓인다.
  void _recenterToMe() {
    final lat = _myLat;
    final lng = _myLng;
    if (lat == null || lng == null) return;
    _moveToMyLocation(lat, lng);
  }

  /// 내 위치를 볼 때 쓰는 줌. 위도 37.5에서 약 3.8m/px라 100m 떨어진 스팟이 26px쯤
  /// 벌어져 서로 구분된다(#144). 실제 밀도를 보고 조정할 튜닝값이다.
  ///
  /// 발자취 표시 기준([FootprintMarkerController] 줌 17)보다는 낮다 — 여기서 바로
  /// 발자취까지 보이게 하면 스팟이 화면 밖으로 밀려난다. 발자취는 더 확대해야 나온다.
  static const _myLocationZoom = 15.0;

  /// 내 위치로 카메라를 옮긴다. **줌은 [_myLocationZoom]보다 낮을 때만 올린다** —
  /// 사용자가 더 확대해 보고 있으면 그 배율을 빼앗지 않는다.
  void _moveToMyLocation(double lat, double lng) {
    final controller = _controller;
    if (controller == null) return;

    // flutter_naver_map 이 experimental 로 표시한 API 지만 현재 줌을 얻을 다른 경로가 없다.
    // SDK 가 정식 API 를 제공하면 교체할 것(위 initialPosition 과 같은 이유).
    // ignore: experimental_member_use
    final currentZoom = controller.nowCameraPosition.zoom;
    controller.updateCamera(
      NCameraUpdate.withParams(
        target: NLatLng(lat, lng),
        zoom: currentZoom < _myLocationZoom ? _myLocationZoom : null,
      ),
    );
  }

  void _onGeofenceEnter(GeofenceEnterEvent event) {
    final spotId = event.spot.id;
    if (_visitedSpotIds.contains(spotId)) return; // 이미 인증한 스팟은 알리지 않는다.
    if (_notifiedSpotIds.contains(spotId)) return; // 세션당 1회.
    _notifiedSpotIds.add(spotId);

    // 화면이 꺼져 있으면 배너를 띄워도 볼 수 없다 — 알림 표시줄로 보낸다(#135).
    // 반대로 앱을 보고 있는데 알림으로 보내면 흐름이 끊기므로, 그때는 배너 그대로(#46).
    if (!_appInForeground) {
      unawaited(
        _proximityNotifier.notifySpotNearby(
          spotId: spotId,
          spotTitle: event.spot.title,
          distanceMeters: event.distanceMeters,
        ),
      );
      return;
    }
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

  /// 지금 띄울 안내(#144, #146).
  ///
  /// 처음 켠 사람에게는 이 화면이 **회색 안개와 버튼 몇 개**가 전부다. 스팟이 없으면
  /// 탭할 것도, 인증할 것도, 걷어낼 안개도 없어서 앱이 고장 난 것처럼 보인다.
  /// 그 원인이 "이 지역에 데이터가 없다"인지 "서버에 못 닿았다"인지는 사용자가
  /// 구분할 방법이 없으므로, 화면이 구분해서 말해준다.
  MapNotice get _notice => mapNoticeFor(
        loadFailed: _spotLoadFailed,
        spotsEverLoaded: _spotsEverLoaded,
        spotCount: _nearestLoadedSpot == null ? 0 : 1,
        serverErrorDismissed: _serverErrorDismissed,
        emptyAreaDismissed: _emptyNoticeDismissed,
      );

  void _dismissEmptyNotice() {
    if (mounted) setState(() => _emptyNoticeDismissed = true);
  }

  void _dismissServerErrorNotice() {
    if (mounted) setState(() => _serverErrorDismissed = true);
  }

  /// 스팟 조회를 지금 위치에서 다시 시도한다(#146).
  ///
  /// 카메라를 움직이면 어차피 다시 불러오지만, 서버가 죽어 회색 화면만 보는 사람에게
  /// **당장 할 수 있는 동작 하나**는 있어야 한다.
  void _retrySpotLoad() {
    final center = _lastLoadCenter;
    if (center == null) return;
    unawaited(_spotMarkers?.loadAround(center));
  }

  /// 지도의 "발자취 남기기" 버튼(#118). GPS로 현재 위치를 새로 측정해 정확도가
  /// 10m 이내일 때만 그 좌표로 작성 화면을 연다 — 이유는 [FootprintLocationGate] 참고.
  Future<void> _openFootprintCreate() async {
    if (_footprintLocationChecking) return;
    setState(() => _footprintLocationChecking = true);

    final check = await FootprintLocationGate.check();
    if (!mounted) return;
    setState(() => _footprintLocationChecking = false);

    switch (check) {
      case FootprintLocationReady(:final lat, :final lng):
        await _writeFootprintAt(lat, lng);
      case FootprintLocationUnavailable():
        _showFootprintLocationMessage('위치 확인이 필요해요. 위치 권한과 GPS를 켜주세요.');
      case FootprintLocationInaccurate(:final accuracyMeters, :final lat, :final lng):
        // 막다른 길로 두지 않는다. 10m는 보안 규칙이 아니라 "여기라고 말할 수
        // 있는 범위"를 지키는 UX 규칙이고(docs/footprint-redesign.md 3-1·5-2,
        // 서버는 좌표 범위와 횟수만 본다), 실내 GPS는 보통 20~50m라 그대로
        // 막으면 실내에서는 글을 영영 남길 수 없다.
        //
        // 대신 오차를 숫자로 보여주고 사용자가 정하게 한다 — 정확도 신호를
        // 버리지 않으면서 길은 열어둔다.
        if (!await _confirmInaccurateFootprint(accuracyMeters)) return;
        // 다이얼로그가 떠 있는 동안 화면이 사라질 수 있다(로그아웃 → AuthGate 재빌드 등).
        // _writeFootprintAt 은 자기 함수 안에서는 await 앞에 context 를 써서
        // use_build_context_synchronously 가 잡지 못한다 — 여기서 직접 확인한다.
        if (!mounted) return;
        await _writeFootprintAt(lat, lng);
      case FootprintLocationTooInaccurate(:final accuracyMeters):
        // 동의를 받아도 쓰지 않는다. 오차를 숫자로 보여주는 것만으로는 판단을 맡길 수
        // 없는 범위다 — 사용자는 "35m 면 뭐" 하고 누르지 2km 를 상상하지 않는다.
        _showFootprintLocationMessage(
          '위치 오차가 너무 큽니다(약 ${accuracyMeters.round()}m). '
          '실외로 이동해 잠시 후 다시 시도해주세요.',
        );
      case FootprintLocationFailed():
        _showFootprintLocationMessage('위치를 확인하지 못했어요. 다시 시도해주세요.');
    }
  }

  /// 오차가 큰 위치에 그대로 남길지 묻는다(#118). 취소가 기본 동작이다.
  Future<bool> _confirmInaccurateFootprint(double accuracyMeters) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치가 정확하지 않아요'),
        content: Text(
          '지금 위치의 오차가 약 ${accuracyMeters.round()}m입니다.\n'
          '이대로 남기면 글귀가 실제 있는 자리에서 그만큼 떨어져 보일 수 있어요.\n\n'
          '실외로 나가면 더 정확해집니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('여기에 남기기'),
          ),
        ],
      ),
    );
    return proceed ?? false;
  }

  Future<void> _writeFootprintAt(double lat, double lng) async {
    final written = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => FootprintNearbyCreateScreen(lat: lat, lng: lng)),
    );
    if (written == true) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('발자취를 남겼어요.')));
      }
      unawaited(_loadFootprintQuota());
    }
  }

  void _showFootprintLocationMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// 스팟 마커를 탭하면 상세 화면(#50)을 연다. 해금 전이면 잠긴 상태로,
  /// 해금 후면 명칭·주소·소개로 보여준다 — 발자취 작성(#70) 진입점도 그 화면에 있다.
  Future<void> _onSpotTapped(Spot spot) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: spot)),
    );
  }

  /// 근접 알림(#46)의 "인증하러 가기"에서 실제 인증 화면(#47)으로 진입한다.
  Future<void> _openVisitVerify(Spot spot) async {
    setState(() => _proximityBanner = null);
    final lat = _myLat;
    final lng = _myLng;
    if (lat == null || lng == null) return; // 이론상 거의 없음 — geofencing 자체가 위치 스트림에서 나온다.

    final verified = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VisitVerifyScreen(spot: spot, currentLat: lat, currentLng: lng),
      ),
    );
    if (verified == true) {
      // 방금 인증한 스팟은 바로 반영해, 재조회 전이라도 다시 알리지 않는다.
      setState(() {
        _visitedSpotIds = {..._visitedSpotIds, spot.id};
        _visitedSpotCoords = {..._visitedSpotCoords, spot.id: NLatLng(spot.lat, spot.lng)};
      });
      unawaited(_refreshConquest());
      // 안개 걷힘 연출(#49) — 스팟 좌표 기준 반경을 퍼지듯 넓혀가며 걷어낸다.
      unawaited(_fogOverlay?.clearCircleAnimated(spot.id.toString(), NLatLng(spot.lat, spot.lng)));
      unawaited(_openUnlockedSpotDetail(spot));
    }
  }

  /// 인증 직후 상세 화면으로 자연스럽게 전환한다(#50) — "해금되는 느낌"을 준다.
  /// [spot]은 인증 전에 받은 스냅샷이라 아직 unlocked=false/overview=null이므로,
  /// 방금 해금된 최신 정보를 반경 조회로 다시 가져온다.
  Future<void> _openUnlockedSpotDetail(Spot spot) async {
    try {
      final nearby = await ref.read(spotServiceProvider).fetchNearby(
            lat: spot.lat,
            lng: spot.lng,
            radiusMeters: 100,
          );
      Spot? refreshed;
      for (final s in nearby) {
        if (s.id == spot.id) {
          refreshed = s;
          break;
        }
      }
      if (refreshed == null || !mounted) return;
      final unlockedSpot = refreshed;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: unlockedSpot)),
      );
    } catch (_) {
      // 인증 자체(안개 걷힘·정복률)는 이미 반영됐으니 상세 전환 실패는 조용히 넘어간다.
    }
  }

  /// 이미 인증한 스팟 목록(#46)을 새로 불러오고, 그 좌표로 안개 상태를 복원한다(#49).
  /// 실패해도 지도 자체는 동작해야 하므로(조용히 필터·복원이 안 걸릴 뿐) 예외를 삼킨다
  /// — 정복률(#51)과 같은 원칙.
  ///
  /// #46이 만든 `VisitedSpotsService`는 `VisitService.myVisits()`와 조회 범위가
  /// 겹쳐서 흡수했다 — 방문 목록을 두 곳에서 따로 관리할 이유가 없다.
  Future<void> _refreshVisitedSpots() async {
    try {
      final visits = await ref.read(visitServiceProvider).myVisits();
      if (!mounted) return;
      setState(() {
        _visitedSpotIds = visits.map((v) => v.spotId).toSet();
        _visitedSpotCoords = {for (final v in visits) v.spotId: NLatLng(v.lat, v.lng)};
      });
      // 애니메이션 없이 즉시 걷어낸다 — 이미 걷힌 영역을 매번 앱을 켤 때마다 다시
      // "퍼지는" 연출로 보여줄 이유는 없다(#49 to-do: 재진입 시 유지).
      _fogOverlay?.clearCircles({for (final v in visits) v.spotId.toString(): NLatLng(v.lat, v.lng)});
    } catch (_) {
      // no-op
    }
  }

  void _onMapReady(NaverMapController controller) async {
    _controller = controller;
    // 트래커 인스턴스를 들고 있어야 캐릭터 아이콘을 등록할 수 있다(#161) —
    // 아이콘은 트래킹 모드가 바뀔 때마다 트래커가 다시 씌운다.
    final locationTracker = FogLocationTracker(_locationService);
    controller.setMyLocationTracker(locationTracker);
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
        if (mounted) {
          setState(() {
            _nearestLoadedSpot = spots.isEmpty ? null : spots.first;
            _spotsEverLoaded = true;
            // 성공했으니 장애 상태를 푼다(#146). 닫아둔 것도 함께 풀어, 다음에 또
            // 죽으면 다시 알릴 수 있게 한다.
            _spotLoadFailed = false;
            _serverErrorDismissed = false;
          });
        }
      },
      onLoadFailed: (_) {
        if (mounted) setState(() => _spotLoadFailed = true);
      },
      onSpotTapped: _onSpotTapped,
    );
    // 발자취 아이콘은 위젯을 이미지로 구워 만든다 — 마커마다 만들지 않고 한 번만 만들어
    // 공유한다. 앞선 await 이후라 context를 쓰기 전에 mounted를 확인한다.
    if (!mounted) return;
    NOverlayImage? footprintIcon;
    try {
      footprintIcon = await FootprintMarkerController.createIcon(context);
    } catch (e) {
      // 아이콘을 못 구우면 발자취만 안 뜬다 — 지도·스팟·안개는 그대로 동작해야 하므로
      // 여기서 멈추지 않는다.
      debugPrint('[MapScreen] 발자취 아이콘 생성 실패: $e');
    }
    if (!mounted) return;
    if (footprintIcon != null) {
      _footprintMarkers = FootprintMarkerController(
        controller,
        ref.read(footprintServiceProvider),
        icon: footprintIcon,
        onTapped: _onFootprintTapped,
      );
    }
    // 내 위치를 기본 점 대신 캐릭터로 그린다(#131). 실패해도 SDK 기본 표시가 남으므로
    // 지도 사용에는 지장이 없다 — 발자취 아이콘과 같은 원칙.
    if (!mounted) return;
    try {
      final characterIcon = await CharacterOverlay.createIcon(context);
      CharacterOverlay.attach(controller, locationTracker, characterIcon);
    } catch (e) {
      debugPrint('[MapScreen] 캐릭터 아이콘 생성 실패: $e');
    }
    _cameraSubscription = controller.nowCameraPositionStream.listen(_onCameraChanged);
    if (mounted) setState(() => _mapReady = true);
    // flutter_naver_map 이 experimental 로 표시한 API 지만, 초기 카메라 위치를 얻을
    // 다른 경로가 없다. SDK 가 정식 API 를 제공하면 교체할 것.
    // ignore: experimental_member_use
    final initialPosition = controller.nowCameraPosition;
    final initialTarget = initialPosition.target;
    _footprintMarkers?.setZoom(initialPosition.zoom);
    unawaited(_lookupRegion(initialTarget));
    _lastLoadCenter = initialTarget;
    unawaited(_spotMarkers?.loadAround(initialTarget));
    unawaited(_refreshConquest());
    unawaited(_refreshVisitedSpots());
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
    // 줌 임계값에 따른 발자취 표시/숨김(#117)은 카메라가 멈추기 전에도 즉시
    // 반영한다 — 핀치 줌 도중에도 "확대하면 보인다"가 바로 느껴져야 한다.
    _footprintMarkers?.setZoom(params.position.zoom);
    if (!params.isIdle) return;
    unawaited(_lookupRegion(params.position.target));
    _lastLoadCenter = params.position.target;
    unawaited(_spotMarkers?.loadAround(params.position.target));
  }

  /// 발자취 도형 탭(#117). 지도를 벗어나지 않도록 화면 전환 대신 바텀시트로 띄운다
  /// (docs/footprint-redesign.md 4-2 "팝업이지 화면 전환이 아니다"). 좋아요·작성자·시각은
  /// [FootprintCard]가 그대로 그린다 — 목록/스팟 상세와 같은 카드를 재사용한다.
  void _onFootprintTapped(Footprint footprint) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // 스크롤 없이 두면 사진이 붙은 긴 글에서 '더 보기'를 눌렀을 때 넘친다 —
      // `isScrollControlled`는 시트가 커질 수 있게 할 뿐 내용을 스크롤시키지 않는다.
      // 목록 화면에서는 카드가 ListView 안에 있어 드러나지 않던 문제다(PR #130 리뷰).
      builder: (context) => SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: FootprintCard(footprint: footprint),
      ),
    );
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
                  switch (_notice) {
                    MapNotice.serverError => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _ServerErrorNotice(
                          onDismiss: _dismissServerErrorNotice,
                          onRetry: _lastLoadCenter == null ? null : _retrySpotLoad,
                        ),
                      ),
                    MapNotice.emptyArea => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _EmptyAreaNotice(onDismiss: _dismissEmptyNotice),
                      ),
                    MapNotice.none => const SizedBox.shrink(),
                  },
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
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      // 제대로 된 네비게이션(하단 바 등)이 붙기 전까지의 최소 진입점(#73) —
                      // 성향 테스트 버튼과 같은 임시 성격이다.
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                      ),
                      icon: const Icon(Icons.person_outline),
                      label: const Text('내 프로필'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      // 같은 이유의 임시 진입점(5-1).
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MatchCandidatesScreen()),
                      ),
                      icon: const Icon(Icons.people_outline),
                      label: const Text('동행 추천'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      // 같은 이유의 임시 진입점(5-2).
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MatchListScreen()),
                      ),
                      icon: const Icon(Icons.mark_email_unread_outlined),
                      label: const Text('내 동행 요청'),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      // 발자취 남기기(#118). 임시 진입점이 아니라 상시 노출 버튼이다 —
                      // 위 항목들과 달리 하단 네비게이션이 생겨도 계속 여기 있을 기능이다.
                      onPressed: (_footprintQuota == 0 || _footprintLocationChecking)
                          ? null
                          : _openFootprintCreate,
                      icon: _footprintLocationChecking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.edit_location_alt_outlined),
                      label: Text(
                        _footprintQuota == null ? '발자취 남기기' : '발자취 남기기 ($_footprintQuota)',
                      ),
                    ),
                    if (_footprintQuota == 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Text(
                          '스팟을 정복하면 다시 채워집니다',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
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
      color: theme.colorScheme.surface.withValues(alpha: 0.92),
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

/// 서버에 닿지 못했을 때 띄우는 안내(#146).
///
/// **[_EmptyAreaNotice]와 반드시 문구가 달라야 한다.** 서버가 죽었는데 "이 지역엔
/// 스팟이 없어요"라고 하면 틀린 정보다 — 보는 사람은 "데이터가 없는 앱"으로 판단하는데
/// 실제로는 연결이 안 된 것뿐이다.
///
/// 빈 지역 안내와 달리 **오류 톤(errorContainer)으로 그린다.** 이쪽은 실제로 잘못된
/// 상태이고, 사용자가 잠시 후 다시 시도해볼 여지가 있기 때문이다.
class _ServerErrorNotice extends StatelessWidget {
  const _ServerErrorNotice({required this.onDismiss, required this.onRetry});

  final VoidCallback onDismiss;

  /// 아직 한 번도 불러온 적이 없어 재시도할 좌표를 모르면 null — 버튼을 감춘다.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onError = theme.colorScheme.onErrorContainer;

    return Material(
      color: theme.colorScheme.errorContainer,
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_off_outlined, size: 20, color: onError),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '서버에 연결할 수 없어요',
                    style: theme.textTheme.titleSmall?.copyWith(color: onError),
                  ),
                ),
                if (onRetry != null)
                  TextButton(
                    onPressed: onRetry,
                    child: const Text('다시 시도'),
                  ),
                IconButton(
                  onPressed: onDismiss,
                  icon: Icon(Icons.close, size: 18, color: onError),
                  visualDensity: VisualDensity.compact,
                  tooltip: '닫기',
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '지도의 스팟을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요. '
              '지도와 내 위치는 그대로 사용할 수 있어요.',
              style: theme.textTheme.bodySmall?.copyWith(color: onError),
            ),
          ],
        ),
      ),
    );
  }
}

/// 지금 보고 있는 곳에 스팟이 없을 때 띄우는 안내(#144).
///
/// 이게 없으면 회색 안개만 보이고 아무 일도 일어나지 않아, 처음 켠 사람은
/// **앱이 고장 났다고 생각한다.** 실제로는 "여기엔 아직 데이터가 없다"일 뿐이다.
///
/// 오류 배너(빨강)가 아니라 안내 톤으로 그린다 — 잘못된 상태가 아니라
/// 이 앱이 원래 장소에 가야 동작한다는 사실을 알리는 것이기 때문이다.
/// 서버에 못 닿은 경우는 [_ServerErrorNotice]가 따로 맡는다.
class _EmptyAreaNotice extends StatelessWidget {
  const _EmptyAreaNotice({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.94),
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.travel_explore_outlined, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '이 근처에는 아직 탐험할 곳이 없어요',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close, size: 18),
                  visualDensity: VisualDensity.compact,
                  tooltip: '닫기',
                ),
              ],
            ),
            const SizedBox(height: 2),
            // ⚠️ "서울·부산·제주"는 서버의 TOUR_COLLECT_AREA_CODES(1,6,39)와 묶여 있다.
            //    수집 지역을 넓히면(#144 1번) 이 문구도 함께 고칠 것 — 안 고치면
            //    스팟이 있는 지역인데도 "없는 지역"이라고 잘못 안내하게 된다.
            Text(
              'FogApp은 실제로 그 장소에 도착해야 안개가 걷히는 앱이에요. '
              '지금은 서울·부산·제주의 관광 스팟이 준비돼 있어요 — '
              '그 지역에서 열면 주변에 숨겨진 스팟이 나타납니다.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
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
