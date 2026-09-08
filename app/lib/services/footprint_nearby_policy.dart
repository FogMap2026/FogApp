import 'package:geolocator/geolocator.dart';

/// 지도에 발자취를 언제·얼마나 넓게 그릴지 정하는 판정 로직(#117).
///
/// 지도·네트워크를 건드리지 않는 순수 계산만 담는다 — [FootprintMarkerController]가
/// 이 판정을 받아 실제로 그린다. [SpotGeofenceController]가 [SpotMarkerController]와
/// 나뉘어 있는 것과 같은 구조로, 값 판정만 따로 검증할 수 있게 하기 위함이다.
///
/// 이 클래스가 막는 것은 두 가지다.
///
/// 1. **요청 폭주** — 위치가 바뀔 때마다 부르면 걷는 내내 요청이 쏟아진다.
///    [refetchDistanceMeters] 이상 움직였을 때만 다시 부른다.
/// 2. **스팟이 묻히는 것** — 발자취는 스팟보다 훨씬 많아서, 다 그리면 지도가 점으로
///    덮여 탐험의 주역인 스팟 마커가 안 보인다. [minZoom] 미만에서는 아예 그리지 않는다.
class FootprintNearbyPolicy {
  FootprintNearbyPolicy({
    this.movingRadiusMeters = 50,
    this.unlockedSpotRadiusMeters = 150,
    this.refetchDistanceMeters = 25,
    this.minZoom = 15,
  }) : assert(
          unlockedSpotRadiusMeters <= 1000,
          '서버가 반경 1,000m 상한을 강제한다(FootprintService.MAX_RADIUS_METERS)',
        );

  /// 이동 중 조회 반경. 설계 문서(docs/footprint-redesign.md)가 정한 값.
  final double movingRadiusMeters;

  /// 해금된 스팟 안에서의 조회 반경.
  ///
  /// 150m는 임의값이 아니라 `FogOverlayController`의 안개 걷힘 반경과 같은 값이다 —
  /// **보이는 땅 = 읽히는 글.** 한쪽만 바꾸면 "안개 속인데 글이 보이거나, 걷혔는데
  /// 안 보이는" 상태가 생긴다. 바꿀 거면 양쪽을 함께 바꿀 것.
  final double unlockedSpotRadiusMeters;

  /// 이만큼 움직이기 전에는 다시 조회하지 않는다.
  final double refetchDistanceMeters;

  /// 이 줌 미만에서는 발자취를 그리지 않는다.
  ///
  /// 임계 숫자는 튜닝값이다 — 실제 발자취 밀도를 보고 조정할 것. 규칙은
  /// "확대하면 보인다" 하나다.
  final double minZoom;

  double? _lastFetchLat;
  double? _lastFetchLng;
  double? _lastRadiusMeters;

  /// 마지막으로 조회한 좌표. 아직 한 번도 조회하지 않았으면 null.
  double? get lastFetchLat => _lastFetchLat;
  double? get lastFetchLng => _lastFetchLng;

  /// [zoom]에서 발자취를 그려야 하는지.
  bool visibleAt(double zoom) => zoom >= minZoom;

  /// 지금 써야 할 조회 반경. 해금된 스팟 안이면 넓게 본다.
  double radiusFor({required bool insideUnlockedSpot}) =>
      insideUnlockedSpot ? unlockedSpotRadiusMeters : movingRadiusMeters;

  /// [lat]·[lng]에서 반경 [radiusMeters]로 다시 조회해야 하는지 판정한다.
  ///
  /// 처음이거나, [refetchDistanceMeters] 이상 움직였거나, 반경이 바뀌었으면(해금 스팟에
  /// 들어가고 나가는 순간) true. 반경 변화를 함께 보는 이유는, 제자리에 선 채로 스팟에
  /// 막 진입한 경우 거리 조건만으로는 넓어진 반경이 영영 반영되지 않기 때문이다.
  ///
  /// 판정만 하고 상태는 바꾸지 않는다 — 실제로 조회에 성공했을 때 [markFetched]를
  /// 부를 것. 요청이 실패했는데 기준점이 옮겨가면 그 자리에서 다시 시도할 수 없게 된다.
  bool shouldRefetch({
    required double lat,
    required double lng,
    required double radiusMeters,
  }) {
    final lastLat = _lastFetchLat;
    final lastLng = _lastFetchLng;
    if (lastLat == null || lastLng == null) return true;
    if (_lastRadiusMeters != radiusMeters) return true;
    return Geolocator.distanceBetween(lastLat, lastLng, lat, lng) >= refetchDistanceMeters;
  }

  /// 조회에 성공한 좌표·반경을 기준점으로 기록한다.
  void markFetched({
    required double lat,
    required double lng,
    required double radiusMeters,
  }) {
    _lastFetchLat = lat;
    _lastFetchLng = lng;
    _lastRadiusMeters = radiusMeters;
  }

  /// 기준점을 지운다. 다음 [shouldRefetch]는 무조건 true가 된다 —
  /// 발자취를 새로 남긴 직후처럼 즉시 다시 그려야 할 때 쓴다.
  void reset() {
    _lastFetchLat = null;
    _lastFetchLng = null;
    _lastRadiusMeters = null;
  }
}
