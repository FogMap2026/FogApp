import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../models/conquest.dart';
import '../models/footprint.dart';
import '../models/nearby_traveler.dart';
import '../models/spot.dart';
import '../services/character_overlay.dart';
import '../services/conquest_service.dart';
import '../services/favorite_spot_store.dart';
import '../services/fog_location_tracker.dart';
import '../services/fog_overlay_controller.dart';
import '../services/province_boundary_overlay.dart';
import '../services/fog_regions.dart';
import '../services/journey_service.dart';
import '../services/footprint_location_gate.dart';
import '../services/footprint_marker_controller.dart';
import '../services/footprint_service.dart';
import '../services/location_permission_gate.dart';
import '../services/profile_service.dart';
import '../services/region_lookup_service.dart';
import '../services/spot_marker_controller.dart';
import '../services/spot_proximity.dart';
import '../services/spot_service.dart';
import '../services/traveler_marker_controller.dart';
import '../services/traveler_service.dart';
import '../services/traveler_sharing.dart';
import '../services/visit_service.dart';
import '../theme/app_theme.dart';
import '../widgets/footprint_card.dart';
import '../widgets/map_controls.dart';
import '../widgets/proximity_prompt.dart';
import 'conquest_screen.dart';
import 'footprint_nearby_create_screen.dart';
import 'friends_screen.dart';
import 'profile_screen.dart';
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
/// 네이버 지도 커스텀 스타일 ID — 콘솔 계정: 시진. 비밀값이 아니다(클라이언트 ID 처럼 앱에 실린다).
const _mapStyleId = '650c32b2-9a57-4187-a6ab-9be4638556b4';

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
  ProvinceBoundaryOverlay? _provinceBoundary;
  SpotMarkerController? _spotMarkers;
  FootprintMarkerController? _footprintMarkers;
  StreamSubscription<Position>? _geofencePositionSubscription;

  bool _mapReady = false;
  bool? _locationServiceEnabled;
  LocationPermission? _permission;
  String? _regionName;
  bool _regionLookupFailed = false;

  /// 정복률(#51) 조회 결과 전체. 표시할 지역만 골라 쓴다.
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

  /// 마지막으로 스팟을 불러온 중심(#146). "다시 시도"가 쓴다.
  NLatLng? _lastLoadCenter;

  /// 마지막으로 «내 위치 기준» 스팟을 불러왔을 때의 내 위치. 여기서
  /// [_spotReloadDistanceMeters] 이상 벗어나면 다시 불러온다.
  NLatLng? _spotLoadMyPosition;

  /// 📍 「이 지역 스팟 보기」 토글. 켜면 스팟을 **화면 중심** 기준으로 불러오고, 지도를
  /// 움직여 멈출 때마다 다시 불러온다. 조회 범위(3km)를 원으로 그려 화면 중심을 따라
  /// 움직이게 한다 — 「지금 어디를 뒤지고 있나」가 보여야 지도를 어디까지 밀지 안다.
  /// 끄면 내 위치 기준으로 되돌아간다.
  bool _searchHereMode = false;

  /// 켜져 있는 동안 화면 중심을 따라다니는 조회 범위 원. 꺼지면 지운다.
  NCircleOverlay? _searchRangeCircle;

  /// 스팟은 내 위치 3km 안을 불러온다. 15m 마다 다시 부르면 요청이 쏟아지고 결과도
  /// 거의 같으므로, 이만큼 움직였을 때만 다시 부른다 — 반경(3km)의 1/10 이라
  /// 가장자리 스팟이 빠지거나 새로 들어오는 것이 한 박자 늦어도 표가 안 난다.
  static const _spotReloadDistanceMeters = 300.0;

  /// 아직 서버에 못 올린 궤적(#131). 위치가 갱신될 때마다 쌓이고, [_journeyBatchSize]
  /// 가 차거나 앱이 백그라운드로 갈 때 한 번에 올린다.
  ///
  /// 점 하나마다 POST 하면 걷는 내내 요청이 쏟아진다 — 발자취 반경 조회(#115)에
  /// 스로틀을 둔 것과 같은 이유다.
  final List<JourneyPointUpload> _journeyBuffer = [];

  /// 15m 마다 한 점이므로 20점 ≒ **300m**. 이 정도면 요청이 잦지 않으면서,
  /// 앱이 갑자기 죽어도 잃는 궤적이 한 블록 남짓이다.
  static const _journeyBatchSize = 20;

  /// 업로드가 겹치지 않게 한다. 실패해도 버퍼를 비우지 않으므로 다음에 다시 시도된다.
  bool _journeyUploading = false;

  /// 마지막으로 받은 내 위치. "내 위치로 이동" 버튼(#64)과 인증 화면 진입(#47)에 쓴다.
  double? _myLat;
  double? _myLng;

  /// 마지막 측위의 정확도(m). 위치공유(#133) 게시 전에 [isTrailWorthyAccuracy]로
  /// 거른다 — 3km 반경에서 최근접 스팟을 고르므로 오차 수백 m 면 다른 스팟이
  /// 잡힌다. 콜드 스타트 직후가 특히 그렇다(oorony, PR #201 리뷰).
  double? _myAccuracy;

  /// 이미 인증한 스팟 id 목록(#46) — 이 스팟들은 반경에 들어와도 알리지 않는다.
  Set<int> _visitedSpotIds = const {};

  /// 이미 인증한 스팟의 좌표(#117) — 그 스팟의 구역이 걷히고([_applyRegionHoles]), 그 구역
  /// 안에 있으면 발자취 조회 반경을 넓힌다.
  Map<int, NLatLng> _visitedSpotCoords = const {};

  /// 안개 구역([FogRegions]) — 전국 스팟 좌표를 받아 만든다. 만들기 전엔 null 이고, 그동안
  /// 들어온 위치·궤적은 [_journeyRestored]·[_journeyBuffer] 에 남아 있다가 만들어지면 반영된다.
  FogRegions? _fogRegions;

  /// 들어가 본 빈 땅 구역(씨앗 index). 서버에 따로 저장하지 않는다 — 궤적(`journey_points`)이
  /// 이미 «어디를 지났나»이고, 점→구역 변환은 앱이 하면 된다. 앱을 켤 때 [_restoreJourney] 가
  /// 받은 점으로 되살린다. 스팟 구역은 여기 없다: 인증해야 걷히고, 그건 [_visitedSpotCoords] 다.
  final Set<int> _enteredEmptyRegions = {};

  /// 서버에서 되살린 궤적 점 — 구역이 궤적보다 늦게 만들어지면 여기서 다시 센다.
  List<NLatLng> _journeyRestored = const [];

  /// 근접 판정 후보 — 스팟 마커가 카메라 idle 마다 불러오는 목록을 그대로 쓴다(따로 조회하지 않는다).
  List<Spot> _proximityCandidates = const [];

  /// 지금 우하단에 띄운 근접 아이콘의 대상과 단계. null 이면 아이콘 없음.
  SpotProximity? _proximity;

  /// «근처» 아이콘을 눌러 알림 카드로 펼쳤는지.
  bool _proximityExpanded = false;

  /// 이번 실행에서 «인증 가능» 진동을 이미 낸 스팟. 130m 경계를 드나들 때마다 울리면 주머니
  /// 속에서 계속 떨린다 — 아이콘은 매번 뜨지만 진동은 스팟당 한 번.
  final Set<int> _buzzedSpotIds = {};

  /// 남은 발자취 작성 횟수(#116, #118). null이면 아직 못 받아온 것 —
  /// 그동안은 버튼을 낙관적으로 활성 상태로 둔다(실제 소진 여부는 작성 시 429로도 걸러진다).
  int? _footprintQuota;

  /// GPS 측정+정확도 확인이 진행 중일 때 버튼 연타를 막는다.
  bool _footprintLocationChecking = false;

  /// 좌하단 액션 목록을 펼쳤는지. **기본값은 접힘** — 버튼 5개가 상시로 서 있으면
  /// 지도를 그만큼 가리는데, 이 앱에서 화면의 주인공은 지도다.
  ///
  /// 임시 진입점들(#73·5-1·5-2)이 하나씩 늘면서 열이 길어졌고, 결국 네이버 로고와
  /// 지도 컨트롤까지 밀어냈다(#64·#187·#190·#194). 근본은 "상시 노출 항목이 계속
  /// 늘어난 것"이라 접어서 해결한다.
  bool _actionsExpanded = false;

  TravelerMarkerController? _travelerMarkers;

  /// 내 위치 공유(#133) 게시 타이머. 스위치는 프로필 화면에 있고([travelerSharingProvider]),
  /// 여기는 켜져 있을 때 [_travelerSharePeriod]마다 내 위치를 올리는 쪽이다. 꺼져 있으면 null.
  Timer? _travelerShareTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 위치 권한 요청은 onMapReady에서 한 번만 수행한다(중복 요청 시 Android가
    // "Can request only one set of permissions at a time"로 두 번째 요청을 무시함).
    _loadFootprintQuota();
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
    // ⛔ 여기서 _flushJourney() 를 부르지 않는다 — ref 를 쓸 수 없다(위젯이 해체되는
    //    중이라 프로바이더 조회가 던진다). 대신 앱이 백그라운드로 갈 때
    //    didChangeAppLifecycleState 에서 비운다. 여기서 잃는 것은 마지막 묶음
    //    최대 19점(≈300m)이고, 다음 실행에 그 구간만 비어 보인다.
    WidgetsBinding.instance.removeObserver(this);
    _cameraSubscription?.cancel();
    _geofencePositionSubscription?.cancel();
    _travelerShareTimer?.cancel();
    _fogOverlay?.dispose();
    _provinceBoundary?.dispose();
    _spotMarkers?.dispose();
    _footprintMarkers?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 백그라운드 진입 시 위치 추적을 끄고, 포그라운드 복귀 시 다시 켠다.
    // geofencing(#45)도 같은 정책을 따른다 — 백그라운드 감지는 #46에서 별도로 다룬다.
    final controller = _controller;
    if (controller == null) return;
    if (state == AppLifecycleState.resumed) {
      if (_permission == LocationPermission.always || _permission == LocationPermission.whileInUse) {
        controller.setLocationTrackingMode(NLocationTrackingMode.follow);
        _startGeofenceTracking();
      }
      if (ref.read(travelerSharingProvider)) {
        _startTravelerShareTimer();
      }
    } else if (state == AppLifecycleState.paused) {
      controller.setLocationTrackingMode(NLocationTrackingMode.none);
      _geofencePositionSubscription?.cancel();
      _geofencePositionSubscription = null;
      // 위치 스트림이 끊기는 동안 타이머가 울려도 _myLat/_myLng는 갱신되지 않은
      // 옛 값이다 — 배터리만 쓰고 낡은 좌표를 올리는 꼴이라 여기서도 멈춘다.
      // "위치 수집은 앱 실행 중에만"이라는 신고서·방침 전제와도 어긋난다
      // (oorony, PR #201 리뷰).
      _travelerShareTimer?.cancel();
      _travelerShareTimer = null;
      // 화면을 벗어나기 전에 남은 궤적을 올린다 — 배치가 차기 전에 앱을 닫으면
      // 그 구간이 사라진다.
      unawaited(_flushJourney());
    }
  }

  Future<void> _requestLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (mounted) setState(() => _locationServiceEnabled = serviceEnabled);
    if (!serviceEnabled) return;

    final permission = await LocationPermissionGate.request();
    if (mounted) setState(() => _permission = permission);

    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return;
    }

    _controller?.setLocationTrackingMode(NLocationTrackingMode.follow);
    _startGeofenceTracking();
  }

  /// 실시간 위치 스트림을 구독해 근접 아이콘([_recomputeProximity])에 반영한다(#45). [FogLocationTracker]와
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
      _myAccuracy = position.accuracy;
      if (!hadLocation && mounted) setState(() {});
      // 빈 땅 구역은 들어가기만 하면 걷힌다 — 정확도 게이트는 궤적과 같다(튄 점 하나가 구역
      // 하나를 영영 걷어낸다).
      if (isTrailWorthyAccuracy(position.accuracy)) {
        _enterRegionAt(position.latitude, position.longitude);
      }

      // 첫 측위에 한 번만 내 위치로 줌을 맞춘다(#144). 이게 없으면 권한을 허용해도
      // 전국 뷰에 머물러 "회색 화면에 점 하나"로 보인다 — 스팟이 없어서가 아니라
      // 전부 겹쳐 있어서다. 이후 갱신에서는 사용자의 카메라를 건드리지 않는다.
      if (!_didZoomToFirstFix) {
        _didZoomToFirstFix = true;
        _moveToMyLocation(position.latitude, position.longitude);
      }
      // 스팟은 «내 위치» 기준으로 불러온다 — 카메라가 아니라. 지도를 밀어도 내 주변
      // 스팟이 그대로 남고, 300m 이상 걸었을 때만 다시 부른다.
      _reloadSpotsIfMoved(position.latitude, position.longitude);
      // 걸어온 자리의 안개를 걷는다. 스트림이 15m 이상 움직였을 때만 오므로
      // (FogLocationTracker.locationSettings) 갱신마다 15m 원을 뚫으면 원들이
      // 맞닿아 끊기지 않는 길이 된다.
      //
      // ⚠️ 인증(스팟 반경)과 «다른 축»이다 — 이건 지나간 자리 표시일 뿐 정복률에는
      //    영향이 없다. 걸어서 걷힌 안개가 정복으로 세어지면 사진 인증을 할 이유가
      //    없어진다(planning.md 3장 「도달 → 인증 → 해제」).
      //
      // 🔴 정확도부터 본다. distanceFilter 는 «움직였나»만 말하고 «진짜 움직였나»는
      //    안 말한다 — 콜드 스타트 첫 fix 는 오차가 수백 m 라 그 자체로 15m 를
      //    만든다. 궤적 구멍은 지우는 길이 없어서, 튄 점 하나가 영영 남는다.
      if (isTrailWorthyAccuracy(position.accuracy)) {
        _fogOverlay?.clearTrail(NLatLng(position.latitude, position.longitude));
        // 화면에는 바로 반영하고(위), 서버에는 모아서 올린다(#131) — 앱을 다시 켜도
        // 걸어온 자리가 남아야 한다. 인증 안개가 GET /api/visits 로 복원되는 것과 같다.
        _journeyBuffer.add(
          JourneyPointUpload(
            lat: position.latitude,
            lng: position.longitude,
            recordedAt: position.timestamp,
          ),
        );
        if (_journeyBuffer.length >= _journeyBatchSize) unawaited(_flushJourney());
      }

      // ⚠️ 아래 둘은 «정확도 판정 밖»이다 — 화면 표시라 튀어도 다음 갱신에 되돌아온다.
      //    되돌아오지 않는 것(구멍·서버 저장)만 거른다.
      _recomputeProximity();
      unawaited(
        _footprintMarkers?.updatePosition(
          lat: position.latitude,
          lng: position.longitude,
          insideUnlockedSpot: _isInsideUnlockedSpot(position.latitude, position.longitude),
        ),
      );
    });
  }

  /// 해금된(방문 인증한) 스팟의 구역 안에 있는지(#117) — 발자취 조회 반경을 50m에서 넓힐지
  /// 판단하는 데 쓴다(문서 3-3). 안개가 걷힌 곳과 같은 기준이다 — 「밝힌 동네」 안이면
  /// 발자취도 넓게 보인다. 구역이 아직 없으면(좌표 받는 중) 스팟 150m 로 대신한다.
  bool _isInsideUnlockedSpot(double lat, double lng) {
    final regions = _fogRegions;
    if (regions != null) {
      final spotId = regions.nearest(lat, lng)?.spotId;
      return spotId != null && _visitedSpotIds.contains(spotId);
    }
    for (final coord in _visitedSpotCoords.values) {
      if (Geolocator.distanceBetween(lat, lng, coord.latitude, coord.longitude) <= 150) return true;
    }
    return false;
  }

  // ── 안개 구역 ───────────────────────────────────────────────────────────

  /// 전국 스팟 좌표(`GET /api/spots/coords`, 기기 캐시)와 시/도 경계로 구역을 만든다. 지도가
  /// 준비되면 한 번. 만들어지면 그때까지 받아 둔 방문 목록·궤적으로 걷힌 구역을 센다.
  ///
  /// 실패하면 조금 있다 다시 한다([_fogRegionsRetries]) — 첫 실행은 좌표를 받아야 해서 잠깐의
  /// 연결 끊김(터널 재접속 등)에 통째로 걸리고, 그러면 이번 세션 내내 구역 없는 지도가 된다.
  Future<void> _buildFogRegions() async {
    try {
      final coords = await ref.read(spotServiceProvider).fetchAllCoords();
      final rings = await FogOverlayController.loadProvinceRings();
      final sw = Stopwatch()..start();
      final regions = FogRegions.build(coords, land: LandMask.fromRings(rings));
      debugPrint('[FogRegions] 스팟 ${coords.length} → 씨앗 ${regions.seeds.length} (${sw.elapsedMilliseconds}ms)');
      if (!mounted) return;
      _fogRegions = regions;
      for (final p in _journeyRestored) {
        _markEmptyRegion(p.latitude, p.longitude);
      }
      for (final p in _journeyBuffer) {
        _markEmptyRegion(p.lat, p.lng);
      }
      final lat = _myLat;
      final lng = _myLng;
      final accuracy = _myAccuracy;
      if (lat != null && lng != null && accuracy != null && isTrailWorthyAccuracy(accuracy)) {
        _markEmptyRegion(lat, lng);
      }
      _applyRegionHoles();
    } catch (e) {
      // 구역 없이도 지도는 돈다 — 궤적 원은 그대로 걷힌다.
      debugPrint('[FogRegions] 구역 생성 실패: $e');
      if (_fogRegionsRetries++ < 3 && mounted) {
        unawaited(
          Future<void>.delayed(const Duration(seconds: 20), () {
            if (mounted && _fogRegions == null) unawaited(_buildFogRegions());
          }),
        );
      }
    }
  }

  int _fogRegionsRetries = 0;

  /// [lat],[lng] 가 빈 땅 구역이면 «들어간 구역»에 넣는다. 스팟 구역은 넣지 않는다 —
  /// 그건 인증해야 걷힌다(시진, 09-15). 새로 들어간 구역이면 true.
  bool _markEmptyRegion(double lat, double lng) {
    final seed = _fogRegions?.nearest(lat, lng);
    if (seed == null || seed.isSpot) return false;
    return _enteredEmptyRegions.add(seed.index);
  }

  void _enterRegionAt(double lat, double lng) {
    if (_markEmptyRegion(lat, lng)) _applyRegionHoles();
  }

  /// 걷힌 구역 = 인증한 스팟의 구역 + 들어가 본 빈 땅 구역. 셀을 다시 잘라 통째로 준다 —
  /// 많아야 수백 개고 셀 하나가 이웃 수십 개만 보므로 몇 ms 다.
  void _applyRegionHoles() {
    final regions = _fogRegions;
    final fog = _fogOverlay;
    if (regions == null || fog == null) return;
    final seeds = <FogRegionSeed>{
      for (final i in _enteredEmptyRegions) regions.seeds[i],
      for (final id in _visitedSpotIds)
        if (regions.seedOfSpot(id) case final seed?) seed,
    };
    fog.setRegionHoles(regions.cellsOf(seeds));
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

  /// 위치·후보·인증 목록 중 하나라도 바뀌면 부른다 — 우하단 근접 아이콘의 대상과 단계를 다시 정한다.
  ///
  /// «인증 가능»으로 막 올라선 순간에만 진동한다. 같은 스팟에서 단계가 유지되는 동안은 조용하다.
  void _recomputeProximity() {
    final lat = _myLat;
    final lng = _myLng;
    final previous = _proximity;
    final next = (lat == null || lng == null)
        ? null
        : resolveSpotProximity(
            candidates: _proximityCandidates,
            lat: lat,
            lng: lng,
            visitedSpotIds: _visitedSpotIds,
            previous: previous,
            accuracyMeters: _myAccuracy,
          );

    final becameVerifiable = next != null &&
        next.level == ProximityLevel.verifiable &&
        !(previous?.level == ProximityLevel.verifiable && previous?.spot.id == next.spot.id);
    if (becameVerifiable && _buzzedSpotIds.add(next.spot.id)) unawaited(_buzzVerifiable());

    final spotChanged = previous?.spot.id != next?.spot.id;
    final levelChanged = previous?.level != next?.level;
    // 거리만 바뀐 갱신은 펼친 카드(거리 문구가 보이는 때)가 아니면 다시 그릴 필요가 없다.
    if (!mounted || (!spotChanged && !levelChanged && !_proximityExpanded)) {
      _proximity = next;
      return;
    }
    setState(() {
      _proximity = next;
      // 대상이 바뀌었거나 인증 단계로 올라서면 펼친 카드는 접는다 — 다른 스팟 이야기를 하던 카드가
      // 그대로 남거나, 인증 아이콘과 카드가 섞이지 않게.
      if (spotChanged || next?.level != ProximityLevel.near) _proximityExpanded = false;
    });
  }

  /// 인증할 수 있을 만큼 가까워진 순간의 진동 — 짧게 두 번.
  ///
  /// 진동 패키지와 `VIBRATE` 권한을 새로 들이지 않고 [HapticFeedback] 을 쓴다. APK 권한 목록이
  /// 바뀌면 스토어 상품 설명의 권한 표기와 어긋난다(#189 — 쓰지 않는 마이크 권한을 뺀 것과 같은
  /// 이유). 대신 기기 설정에서 «터치 진동»을 꺼 두면 울리지 않는다 — 아이콘은 그래도 뜬다.
  Future<void> _buzzVerifiable() async {
    await HapticFeedback.vibrate();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await HapticFeedback.vibrate();
  }

  void _expandProximity() {
    // 좌하단 메뉴를 펼친 채로 카드가 자라면 메뉴 아래쪽 버튼과 겹친다 — 하나만 펼친다.
    setState(() {
      _proximityExpanded = true;
      _actionsExpanded = false;
    });
  }

  void _collapseProximity() => setState(() => _proximityExpanded = false);

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

  /// 📍 토글. 켜면 화면 중심 기준 + 범위 원, 끄면 내 위치 기준으로 즉시 되돌린다.
  ///
  /// 스팟은 평소 내 위치 주변만 불러오므로, 지도를 멀리 밀어 「거기엔 뭐가 있나」를
  /// 볼 길이 이것이다. 한 번 누를 때 한 번만 불러오는 방식도 써봤는데, 지도를 조금
  /// 옮길 때마다 다시 눌러야 해서 토글로 바꿨다(시진, 09-14).
  void _toggleSearchHere() {
    final controller = _controller;
    if (controller == null) return;
    // ignore: experimental_member_use
    final target = controller.nowCameraPosition.target;
    setState(() => _searchHereMode = !_searchHereMode);

    if (_searchHereMode) {
      final circle = NCircleOverlay(
        id: 'spot-search-range',
        center: target,
        radius: SpotMarkerController.radiusMeters,
        color: AppColors.primary.withValues(alpha: 0.08),
        outlineColor: AppColors.primary.withValues(alpha: 0.6),
        outlineWidth: 1.5,
      );
      _searchRangeCircle = circle;
      unawaited(controller.addOverlay(circle));
      _loadSpotsAt(target);
      return;
    }

    final circle = _searchRangeCircle;
    _searchRangeCircle = null;
    if (circle != null) unawaited(controller.deleteOverlay(circle.info));
    // 내 위치 기준으로 «지금» 되돌린다 — 300m 걸을 때까지 화면 중심 스팟이 남아 있으면
    // 끈 것 같지 않다.
    final lat = _myLat;
    final lng = _myLng;
    if (lat != null && lng != null) {
      _spotLoadMyPosition = null;
      _reloadSpotsIfMoved(lat, lng);
    }
  }

  void _loadSpotsAt(NLatLng center) {
    _lastLoadCenter = center;
    unawaited(_spotMarkers?.loadAround(center));
  }

  /// 내 위치가 마지막 조회 지점에서 충분히 멀어졌으면 내 주변 스팟을 다시 불러온다.
  /// 📍 모드에서는 안 한다 — 화면 중심이 기준이다.
  void _reloadSpotsIfMoved(double lat, double lng) {
    if (_searchHereMode) return;
    final last = _spotLoadMyPosition;
    if (last != null &&
        Geolocator.distanceBetween(last.latitude, last.longitude, lat, lng) < _spotReloadDistanceMeters) {
      return;
    }
    final here = NLatLng(lat, lng);
    _spotLoadMyPosition = here;
    _lastLoadCenter = here;
    unawaited(_spotMarkers?.loadAround(here));
  }

  /// 지도의 "발자취 남기기" 버튼(#118). GPS로 현재 위치를 새로 측정해 정확도가
  /// 10m 이내일 때만 그 좌표로 작성 화면을 연다 — 이유는 [FootprintLocationGate] 참고.
  /// 쌓인 궤적을 서버로 올린다(#131).
  ///
  /// **실패해도 버퍼를 비우지 않는다** — 다음 기회에 다시 올라간다. 서버가
  /// `(user_id, recorded_at)` 유니크로 멱등하게 받으므로 **재전송이 안전하다**.
  /// 성공했을 때만 비우는 것이 핵심이다: 비우고 실패하면 그 구간이 영영 사라진다.
  Future<void> _flushJourney() async {
    if (_journeyUploading || _journeyBuffer.isEmpty) return;
    _journeyUploading = true;
    final batch = List<JourneyPointUpload>.from(_journeyBuffer);
    try {
      await ref.read(journeyServiceProvider).upload(batch);
      _journeyBuffer.removeRange(0, batch.length);
    } catch (e) {
      // 궤적은 지도 위 보조 표시라 실패해도 탐험은 계속돼야 한다
      // (SpotMarkerController·FootprintMarkerController 와 같은 원칙).
      debugPrint('[Journey] 궤적 업로드 실패: $e');
    } finally {
      _journeyUploading = false;
    }
  }

  /// 서버에 남은 궤적으로 안개를 복원한다(#131). 지도 준비 직후 한 번.
  ///
  /// 인증 안개를 `GET /api/visits` 로 복원하는 것([_loadVisitedSpots])과 같은 자리다 —
  /// 이게 없으면 앱을 다시 켤 때마다 걸어온 자리가 사라진다.
  ///
  /// 🔑 **아직 안 올라간 버퍼도 같이 그린다.** 위치 스트림은 권한 직후에 시작하고
  /// 오버레이는 지도 준비 후에 붙으므로, 그 사이에 온 점은 `_fogOverlay` 가 null 이라
  /// 구멍이 안 난다. 서버에는 올라가니 «다음 실행»부터는 보이지만 **이번 세션엔 첫
  /// 몇십 m 가 비어 있다** — 첫 실행 인상이 걸리는 자리다.
  Future<void> _restoreJourney() async {
    // 서버 응답을 기다리는 동안에도 버퍼는 늘어나므로 «먼저» 그린다.
    _drawBufferedJourney();
    try {
      final points = await ref.read(journeyServiceProvider).fetchMine();
      if (!mounted || points.isEmpty) return;
      _journeyRestored = points;
      // 점마다 부르지 않는다 — landmass 하나당 setHoles 한 번으로 끝낸다.
      _fogOverlay?.clearTrails(points);
      // 지나간 빈 땅 구역도 되살린다 — 점→구역은 앱이 센다(서버엔 궤적만 있다).
      var entered = false;
      for (final p in points) {
        entered = _markEmptyRegion(p.latitude, p.longitude) || entered;
      }
      if (entered) _applyRegionHoles();
    } catch (e) {
      debugPrint('[Journey] 궤적 복원 실패: $e');
    }
  }

  /// 오버레이가 붙기 «전»에 받아 둔 점들을 그린다. 서버 왕복과 무관하게 돌아야
  /// 하므로 [_restoreJourney] 의 `try` 밖이다 — 복원이 실패해도 이번 세션에 걸은
  /// 자리는 보여야 한다.
  void _drawBufferedJourney() {
    if (_journeyBuffer.isEmpty) return;
    _fogOverlay?.clearTrails(
      _journeyBuffer.map((p) => NLatLng(p.lat, p.lng)),
    );
  }

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('발자취를 남겼어요.')));
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
  Future<void> _onSpotTapped(Spot spot) => _openSpotDetail(spot);

  /// 스팟 상세를 연다. 내가 그 스팟의 인증 거리(100m) 안에 있으면 상세에 카메라 버튼이
  /// 뜨고, 그걸 누르면 상세가 닫히면서 여기서 인증 화면을 이어 연다(시진, 09-15).
  /// 거리는 우하단 근접 상태가 아니라 내 좌표로 직접 잰다 — 100m 안에 스팟이 둘이면
  /// 근접 상태는 하나만 가리키지만, 다른 하나를 눌러도 인증할 수 있어야 한다.
  Future<void> _openSpotDetail(Spot spot) async {
    final action = await Navigator.of(context).push<SpotDetailAction>(
      MaterialPageRoute(
        builder: (_) => SpotDetailScreen(spot: spot, verifyAvailable: _canVerify(spot)),
      ),
    );
    if (action == SpotDetailAction.verify && mounted) {
      await _openVisitVerify(spot);
    }
  }

  bool _canVerify(Spot spot) {
    final lat = _myLat;
    final lng = _myLng;
    if (lat == null || lng == null || spot.unlocked) return false;
    return Geolocator.distanceBetween(lat, lng, spot.lat, spot.lng) <= SpotProximity.verifyEnterMeters;
  }

  /// 우하단 «인증 가능» 아이콘에서 실제 인증 화면(#47)으로 곧바로 들어간다.
  Future<void> _openVisitVerify(Spot spot) async {
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
      // 방금 인증한 스팟의 아이콘을 내린다 — 다음 위치 갱신(15m 이동)까지 기다리면 인증한
      // 자리에 선 채로 «지금 인증하기»가 계속 떠 있다.
      _recomputeProximity();
      unawaited(_refreshConquest());
      // 마커도 바로 «밝힌» 색으로 — 마커는 서버가 준 unlocked 로 그리므로 같은 자리를 다시
      // 불러온다(300m 움직여야 다시 부르던 것을 기다리면 인증하고도 한참 잠긴 색이다, 시진 09-15).
      if (_lastLoadCenter case final center?) _loadSpotsAt(center);
      // 그 스팟의 구역이 통째로 걷힌다 — 「한 칸 채웠다」.
      _applyRegionHoles();
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
      // 인증한 스팟의 구역을 걷는다(#49 재진입 시 유지). 구역이 아직 없으면 만들어질 때 센다.
      _applyRegionHoles();
    } catch (_) {
      // no-op
    }
  }

  void _onMapReady(NaverMapController controller) async {
    _controller = controller;
    final locationTracker = FogLocationTracker();
    controller.setMyLocationTracker(locationTracker);
    _fogOverlay = await FogOverlayController.attach(controller);
    // 시/도 경계선 — 탐험 현황의 배지·단계구분도와 같은 경계를 지도에도 보인다.
    unawaited(_attachProvinceBoundary(controller));
    // 걸어온 자리를 서버에서 되살린다(#131). 인증 안개를 GET /api/visits 로 복원하는
    // 것(_loadVisitedSpots)과 같은 자리다 — 오버레이가 붙은 «뒤»라야 구멍을 낼 수 있다.
    unawaited(_restoreJourney());
    // 구역은 전국 좌표를 받아야 해서 늦게 온다 — 그동안의 방문·궤적은 만들어질 때 반영된다.
    unawaited(_buildFogRegions());
    _spotMarkers = SpotMarkerController(
      controller,
      ref.read(spotServiceProvider),
      onSpotsLoaded: (spots) {
        _proximityCandidates = spots;
        _recomputeProximity();
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
    // 찜한 스팟은 조회와 무관하게 항상 지도에 둔다 — 컨트롤러가 생기자마자 넘기고,
    // 이후 변경은 build 의 ref.listen 이 넘긴다.
    unawaited(_spotMarkers!.setFavorites(ref.read(favoriteSpotsProvider)));
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
    // 주변 여행자(#133) 아이콘도 같은 원칙 — 실패해도 지도 자체는 그대로 쓸 수 있다.
    if (!mounted) return;
    try {
      final travelerIcon = await TravelerMarkerController.createIcon(context);
      _travelerMarkers = TravelerMarkerController(
        controller,
        icon: travelerIcon,
        onTapped: _onTravelerTapped,
      );
    } catch (e) {
      debugPrint('[MapScreen] 여행자 아이콘 생성 실패: $e');
    }
    _cameraSubscription = controller.nowCameraPositionStream.listen(_onCameraChanged);
    if (mounted) setState(() => _mapReady = true);
    // flutter_naver_map 이 experimental 로 표시한 API 지만, 초기 카메라 위치를 얻을
    // 다른 경로가 없다. SDK 가 정식 API 를 제공하면 교체할 것.
    // ignore: experimental_member_use
    final initialPosition = controller.nowCameraPosition;
    final initialTarget = initialPosition.target;
    _footprintMarkers?.setZoom(initialPosition.zoom);
    _spotMarkers?.setZoom(initialPosition.zoom);
    unawaited(_lookupRegion(initialTarget));
    // 첫 측위 전의 임시 조회 — 내 위치가 오면 [_reloadSpotsIfMoved] 가 그쪽으로 바꾼다.
    _lastLoadCenter = initialTarget;
    unawaited(_spotMarkers?.loadAround(initialTarget));
    unawaited(_refreshNearbyTravelers(initialTarget));
    unawaited(_refreshConquest());
    unawaited(_refreshVisitedSpots());
    await _requestLocationPermission();
  }

  /// 정복률(#51) 목록을 새로 불러온다. 지도 진입 시, 그리고 방문 인증(#47) 성공 직후 호출한다.
  Future<void> _refreshConquest() async {
    try {
      final regions = await ref.read(conquestServiceProvider).myConquest();
      if (mounted) {
        // 시/군/구 목록은 여기선 안 쓴다 — 상단 바는 시/도 합산만 본다.
        setState(() => _conquestBySido = aggregateBySido(regions));
      }
    } catch (_) {
      // 정복률은 보조 정보라 실패해도 지도 사용을 막지 않는다 — 플레이스홀더로 남겨둔다.
    }
  }

  /// 상단 바에 보여줄 정복률 — **시/도 단위**다. 바에 뜨는 지역명([_regionName])이
  /// 시/도라서 퍼센트도 같은 단위여야 한다. 시/군/구로 보여주면 「경기도 · 15%」가
  /// 실은 부천시 비율이라, 옆 시로 넘어갈 때 이름은 그대로인데 숫자만 널뛴다.
  ///
  /// 이름으로 먼저 찾고, 안 맞으면 가장 가까운 스팟의 areaCode 로 찾는다([findSidoConquest]).
  ConquestSido? get _currentConquest {
    return findSidoConquest(
      _conquestBySido,
      regionName: _regionName,
      areaCode: _nearestLoadedSpot?.areaCode,
    );
  }

  /// 정복률(#51)을 시/도로 합산한 것. 새로 받을 때만 다시 만든다 —
  /// build 마다 합산하면 매 프레임 목록을 훑는다.
  List<ConquestSido> _conquestBySido = const [];

  Future<void> _attachProvinceBoundary(NaverMapController controller) async {
    try {
      final overlay = await ProvinceBoundaryOverlay.attach(controller);
      if (!mounted) {
        overlay.dispose();
        return;
      }
      _provinceBoundary = overlay;
    } catch (e) {
      // 경계선은 장식이다 — 못 그려도 지도는 그대로 쓴다.
      debugPrint('[MapScreen] 시/도 경계선 실패: $e');
    }
  }

  void _onCameraChanged(OnCameraChangedParams params) {
    // 줌 임계값에 따른 발자취 표시/숨김(#117)은 카메라가 멈추기 전에도 즉시
    // 반영한다 — 핀치 줌 도중에도 "확대하면 보인다"가 바로 느껴져야 한다.
    _footprintMarkers?.setZoom(params.position.zoom);
    // 스팟 마커도 줌에 맞춰 줄인다 — 줌을 빼면 밀집 지역에서 마커가 서로 덮는다.
    _spotMarkers?.setZoom(params.position.zoom);
    // 📍 모드의 범위 원은 손가락을 따라 «즉시» 움직인다 — 멈춘 뒤에 옮기면 원이 끌려오는
    // 것처럼 보인다.
    _searchRangeCircle?.setCenter(params.position.target);
    if (!params.isIdle) return;
    unawaited(_lookupRegion(params.position.target));
    // 스팟은 평소 내 위치 기준([_reloadSpotsIfMoved])이라 여기서 안 부른다 — 지도를 밀
    // 때마다 요청이 나가고 내 주변 스팟이 사라지던 것을 없앴다. 📍 모드일 때만 화면
    // 중심으로 다시 부른다.
    if (_searchHereMode) _loadSpotsAt(params.position.target);
    unawaited(_refreshNearbyTravelers(params.position.target));
  }

  /// "가장 가까운 스팟"을 찾을 때 서버가 뒤지는 반경과 같은 값이다
  /// ([TravelerService], 서버 `TravelerService.NEAREST_SPOT_SEARCH_RADIUS_METERS`) —
  /// 내가 볼 수 있는 범위와 남이 나를 찾을 수 있는 범위를 맞춘다.
  static const _travelerNearbyRadiusMeters = 3000.0;

  /// 주변 익명 여행자(#133)를 다시 불러와 지도에 그린다. **내 공유 여부와 무관하게
  /// 항상 조회한다** — "보기"와 "내 위치 공유"는 서로 다른 opt-in이다.
  Future<void> _refreshNearbyTravelers(NLatLng center) async {
    final markers = _travelerMarkers;
    if (markers == null) return;
    try {
      final travelers = await ref.read(travelerServiceProvider).fetchNearby(
            lat: center.latitude,
            lng: center.longitude,
            radiusMeters: _travelerNearbyRadiusMeters,
          );
      if (mounted) await markers.refresh(travelers);
    } catch (e) {
      // 보조 정보라 실패해도 지도 사용을 막지 않는다 — SpotMarkerController와 같은 원칙.
      debugPrint('[MapScreen] 주변 여행자 조회 실패: $e');
    }
  }

  /// 여행자 마커 탭(#133). 신원은 애초에 서버가 안 주므로 보여줄 수 있는 것은
  /// "언제"뿐이다 — "30분 전 위치"라는 것을 분명히 한다(실시간으로 오해하면
  /// 약속을 잘못 잡는다, 이슈 To-do).
  void _onTravelerTapped(NearbyTraveler traveler) {
    final minutesAgo = DateTime.now().difference(traveler.seenAt).inMinutes;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('저 여행자는 약 $minutesAgo분 전 이 근처에 있었어요')),
    );
  }

  /// 프로필의 「내 위치 공유」 스위치가 바뀌면 여기로 온다([travelerSharingProvider]).
  /// 켜지면 바로 한 번 올리고 타이머를 돌린다 — 아직 위치를 모르면 [_shareMyPosition] 이
  /// 조용히 건너뛰고 다음 주기에 올린다. 꺼지면 타이머를 멈추고 서버 행을 지운다.
  Future<void> _onTravelerSharingChanged(bool enabled) async {
    if (enabled) {
      unawaited(_shareMyPosition());
      _startTravelerShareTimer();
      return;
    }
    _travelerShareTimer?.cancel();
    _travelerShareTimer = null;
    try {
      await ref.read(travelerServiceProvider).stopSharing();
    } catch (e) {
      // 스위치는 이미 꺼졌다 — 서버 쪽이 실패해도 사용자에게는 꺼진 것으로 보이는 게
      // 맞다(다시 켤 때 UPSERT가 갱신하므로 오래 남을 걱정은 없다).
      debugPrint('[MapScreen] 위치 공유 끄기 실패: $e');
    }
  }

  /// 게시 주기 — **서버 컷오프(30분, `TravelerService.DELAY_MINUTES`)보다 반드시
  /// 길어야 한다.** 같거나 짧으면 "보이기 시작하는 순간"과 "갱신되는 순간"이
  /// 겹쳐 노출 구간이 0이 된다(songkh1201, PR #201 리뷰). 60분이면 게시 주기의
  /// 절반(30~60분 구간)은 항상 노출된다.
  static const Duration _travelerSharePeriod = Duration(minutes: 60);

  void _startTravelerShareTimer() {
    _travelerShareTimer?.cancel();
    _travelerShareTimer = Timer.periodic(
      _travelerSharePeriod,
      (_) => unawaited(_shareMyPosition()),
    );
  }

  Future<void> _shareMyPosition() async {
    final lat = _myLat;
    final lng = _myLng;
    final accuracy = _myAccuracy;
    if (lat == null || lng == null) return;
    // 정확도가 나쁜 fix로 게시하면 3km 반경에서 엉뚱한 스팟이 최근접으로 잡힌다.
    // 잃는 것은 없다 — 거르면 그냥 다음 틱에 다시 시도된다(share와 같은 원칙).
    if (accuracy == null || !isTrailWorthyAccuracy(accuracy)) return;
    try {
      await ref.read(travelerServiceProvider).share(lat: lat, lng: lng);
    } catch (e) {
      // 주변에 스팟이 없으면 서버가 404를 준다 — 조용히 넘어간다. 그 외 실패도
      // _travelerSharePeriod 뒤 다음 틱에서 다시 시도되므로 여기서 사용자에게 알리지 않는다.
      debugPrint('[MapScreen] 위치 공유 실패: $e');
    }
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
    // 스팟 상세에서 찜을 켜고 돌아오면 마커 색이 바로 바뀌어야 한다 — 조회 없이 합친다.
    ref.listen(favoriteSpotsProvider, (_, favorites) {
      unawaited(_spotMarkers?.setFavorites(favorites));
    });
    // 프로필의 「내 위치 공유」 스위치 — 게시는 내 위치를 아는 여기서 한다.
    ref.listen(travelerSharingProvider, (_, enabled) => unawaited(_onTravelerSharingChanged(enabled)));
    final safeAreaPadding = MediaQuery.paddingOf(context);
    final locationIssue = _locationIssue;

    // SDK 콘텐츠 패딩에 우리 오버레이가 차지하는 대략적인 높이를 더한다 — 안 그러면
    // "내 위치로 이동" 시 마커가 상단 정보 바 뒤에 숨을 수 있다(#64).
    //
    // ⚠️ **bottom 에는 더하지 않는다.** 로고·스케일 바가 그만큼 딸려 올라온다.
    //
    // SDK 문서에는 «카메라가 콘텐츠 패딩을 제외한 영역의 중심에 위치한다» 까지만
    // 적혀 있고 로고 배치는 언급이 없는데, 실기기 화면에서 재보니 로고가 화면
    // 아래에서 **약 154dp** 위에 있었다 — `bottom(안전영역 48 + 96) + logoMargin 12`
    // 과 맞아떨어진다. 즉 로고도 콘텐츠 영역을 기준으로 놓인다.
    //
    // 그 결과 예전 값(+96)에서는 로고가 좌하단 버튼 열 중간(「내 동행 요청」과
    // 「발자취 남기기」 사이)에 끼어 보였다.
    //
    // 로고를 가리는 것은 네이버 지도 이용 약관 위반이기도 해서, 로고 자리는
    // 화면 맨 아래로 두고 **우리 버튼이 그 위에 서도록** 한다 — 좌하단 열의 아래
    // 여백 64 가 그 간격이다(로고는 12~34 구간을 쓴다).
    final contentPadding = EdgeInsets.only(
      left: safeAreaPadding.left,
      right: safeAreaPadding.right,
      top: safeAreaPadding.top + 64,
      bottom: safeAreaPadding.bottom,
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
              // 기울기(3D 뷰)는 끈다 — 두 손가락을 위로 밀면 지도가 눕는데, 안개 구역·마커가
              // 원근으로 찌그러져 «어디까지 밝혔나»가 읽기 어렵고 되돌리는 법도 눈에 안 띈다(시진, 09-15).
              // maxTilt 0 으로 제스처뿐 아니라 카메라 이동으로도 눕지 않게 못 박는다.
              tiltGesturesEnable: false,
              // 네이버 클라우드 콘솔 「스타일 편집기」로 만든 지도 스타일(시진, 09-15). 도로 번호·IC 마크·
              // 상업 POI 를 끄고 지명·역·자연 지명·도로선만 남겨, 기본 지도가 스팟·발자취 핀과 경쟁하지
              // 않는 «배경»이 되게 한다. 심볼은 SDK 옵션으로 못 끈다(symbolScale 0 도 방패가 남는다).
              // 스타일을 콘솔에서 고치면 앱 재배포 없이 바뀐다.
              customStyleId: _mapStyleId,
              maxTilt: 0,
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
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ConquestScreen()),
                    ),
                  ),
                  if (locationIssue != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _LocationBanner(issue: locationIssue),
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
                  // 지도 컨트롤은 이 Column 안에 둔다 — 배너가 뜨고 지는 만큼
                  // 자동으로 아래위로 밀려 서로 겹치지 않는다. 별도 Align 으로
                  // 빼면 배너 높이를 상수로 짐작해야 하고, 배너가 늘어날 때마다
                  // 그 값이 낡는다.
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: MapControls(
                        onZoomIn: () => _zoomBy(1),
                        onZoomOut: () => _zoomBy(-1),
                        onRecenter: _myLat != null ? _recenterToMe : null,
                        onSearchHere: _mapReady ? _toggleSearchHere : null,
                        searchHereActive: _searchHereMode,
                      ),
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
              child: FilledButtonTheme(
                // 지도 위 액션 버튼(tonal)은 흰 알약이라 밝은 지도 타일에 묻힌다 — 경계선 한 줄과
                // 옅은 그림자로 종이에서 살짝 뜨게 한다(Notion button-secondary). 전역 테마를
                // «대체»하지 않고 병합해야 알약 모양·글자 크기가 유지된다.
                data: FilledButtonThemeData(style: mapActionButtonStyle(Theme.of(context))),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 64),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 펼쳤을 때만 나온다. 접힘이 기본이라 지도가 그만큼 열린다.
                      AnimatedSize(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        alignment: Alignment.bottomLeft,
                        child: _actionsExpanded
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 성향 테스트(#31) 진입점은 프로필 화면에 있다 — 지도 메뉴에 또 두면
                                  // 같은 화면으로 가는 버튼이 둘이라 뺐다(시진, 09-14).
                                  FilledButton.tonalIcon(
                                    // 제대로 된 네비게이션(하단 바 등)이 붙기 전까지의 최소 진입점(#73).
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                                    ),
                                    icon: const Icon(Icons.person_outline),
                                    label: const Text('내 프로필'),
                                  ),
                                  const SizedBox(height: 8),
                                  FilledButton.tonalIcon(
                                    // 친구 — 「추천 친구」(5-1)·「동행 요청」(5-2) 두 탭. 예전엔 버튼이
                                    // 각각 따로 있었다.
                                    onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const FriendsScreen()),
                                    ),
                                    icon: const Icon(Icons.people_outline),
                                    label: const Text('친구'),
                                  ),
                                  const SizedBox(height: 8),
                                  FilledButton.tonalIcon(
                                    // 발자취 남기기(#118). 위 임시 진입점들과 달리 계속 남을 기능이지만,
                                    // 지도를 가리지 않는 쪽을 택해 같이 접는다.
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
                                        '스팟을 탐험하면 다시 채워집니다',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  // 내 위치 공유(#133) 스위치는 프로필 화면으로 옮겼다(시진, 09-14) —
                                  // 지도 메뉴는 «지금 할 행동»만 남긴다.
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                      // 토글은 접든 펼치든 **같은 자리**에 있는다 — 목록이 위로만 자라므로
                      // 연달아 누를 때 손가락을 옮기지 않아도 된다.
                      FloatingActionButton.small(
                        // Scaffold 의 FAB 이 아니라 Stack 안에 직접 놓은 것이라 Hero 태그가
                        // 필요 없다. 두면 화면 전환 때 태그 충돌로 예외가 날 수 있다.
                        heroTag: null,
                        onPressed: () => setState(() {
                          _actionsExpanded = !_actionsExpanded;
                          // 우하단 근접 카드와 겹치지 않게 — 하나만 펼친다([_expandProximity]).
                          if (_actionsExpanded) _proximityExpanded = false;
                        }),
                        tooltip: _actionsExpanded ? '메뉴 닫기' : '메뉴 열기',
                        child: Icon(_actionsExpanded ? Icons.close : Icons.menu),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 우하단 근접 아이콘. 왼쪽 여백 68 = 좌하단 메뉴 토글(16 + 40) + 간격 12 — 카드로
          // 펼쳐져 왼쪽으로 자라도 토글 버튼을 덮지 않는다. 아래 여백은 토글과 같은 줄에 서도록.
          if (_proximity != null)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(68, 16, 16, 58),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: ProximityPrompt(
                    proximity: _proximity!,
                    expanded: _proximityExpanded,
                    onExpand: _expandProximity,
                    onCollapse: _collapseProximity,
                    onOpenSpot: () => _openSpotDetail(_proximity!.spot),
                    showVerifyLabel: !_actionsExpanded,
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
///
/// 누르면 전국 정복 현황([ConquestScreen])으로 들어간다 — 여기 보이는 숫자 하나
/// (지금 보고 있는 지역의 정복률)를 전체·지역별로 펼친 화면이다.
class _TopInfoBar extends StatelessWidget {
  const _TopInfoBar({
    required this.regionName,
    required this.regionLookupFailed,
    required this.conquestRate,
    required this.onTap,
  });

  final String? regionName;
  final bool regionLookupFailed;

  /// 0.0~1.0. 아직 못 구했으면(스팟 미로드·API 실패 등) null — 플레이스홀더로 표시한다.
  final double? conquestRate;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = regionName ?? (regionLookupFailed ? '지역 정보를 가져올 수 없어요' : '지역 확인 중…');
    final rate = conquestRate;
    final rateLabel = rate == null ? '탐험률 --%' : '탐험률 ${(rate * 100).round()}%';

    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.92),
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
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
              ),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.inkFaint),
            ],
          ),
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
                    '이 근처에는 탐험할 곳이 없어요',
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
            // 설명 문단은 뺐다(시진, 09-14) — 「서울·부산·제주만 준비」는 전국 수집 뒤 낡은
            // 정보였고, 한 줄 제목으로 충분하다.
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
