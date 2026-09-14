import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

/// 궤적 구멍의 키 — 좌표를 [cellMeters] 격자에 스냅한다. 같은 칸을 다시 밟으면
/// 같은 키가 나오므로 «구멍이 늘지 않는다».
///
/// 격자로 묶지 않으면 같은 길을 왕복할 때마다 거의 겹치는 원이 쌓이고,
/// `setHoles` 가 호출마다 전체 목록을 다시 보내므로 비용이 제곱으로 는다.
///
/// 🔴 **접두어 `trail:` 이 핵심이다.** 구멍은 하나의 `Map<String, …>` 에 스팟과 함께
/// 담기는데, 키가 스팟 id 문자열(`"12"` 같은)과 겹치면 **궤적이 인증 구멍을 덮어써
/// 걷힌 스팟이 다시 안개에 잠긴다.**
///
/// 경도 간격은 위도에 따라 달라진다(고위도일수록 같은 각도가 짧은 거리다) — 그래서
/// `cos(lat)` 로 보정한다. 안 하면 북쪽에서 격자가 촘촘해져 같은 칸인데 다른 키가 난다.
///
/// [FogOverlayController] 밖에 두는 것은 **지도 컨트롤러 없이 검증하기 위해서다** —
/// `mapNoticeFor`·`classifyFootprintLocation` 과 같은 이유다.
String fogTrailKey(NLatLng center, double cellMeters) {
  const metersPerDegreeLat = 111320.0;
  final latStep = cellMeters / metersPerDegreeLat;
  final lngStep = cellMeters / (metersPerDegreeLat * cos(center.latitude * pi / 180));
  return 'trail:${(center.latitude / latStep).round()}:${(center.longitude / lngStep).round()}';
}

/// 궤적으로 칠 수 있는 위치 정확도의 상한(미터).
///
/// 🔴 **궤적은 지우는 길이 없다.** 인증·발자취 구멍은 이용자가 «그 자리에 있었다»는
/// 판정을 거친 좌표지만, 궤적은 그 판정이 없는 유일한 구멍이고 삭제 API 도 없다 —
/// 한 번 튄 점은 그 사용자의 지도에 영영 남는다.
///
/// `distanceFilter: 15` 는 「15m 이상 움직였을 때만 준다」일 뿐 **그 15m 가 실제
/// 이동인지 오차인지는 가리지 않는다.** 콜드 스타트 첫 fix(네트워크 측위, 오차
/// 수백 m)·실내·지하철 터널이 전부 그 15m 를 만든다.
///
/// 50 인 이유 — 도심 실외 GPS 가 보통 5~20m 라 걷는 동안엔 거의 안 걸리고,
/// 콜드 스타트와 실내 튐은 걸린다. 30 이면 건물 사이에서 길이 자주 끊기고,
/// 100 이면 「걸어온 자리」라 부르기 어려운 점이 들어온다.
///
/// 📌 발자취의 [maxConfirmableAccuracyMeters](footprint_location_gate.dart) 와 같은
/// 축이되 값이 다르다 — 거기는 오차를 «보여주고 사용자에게 맡기는» 자리가 있지만,
/// 궤적은 15m 마다 자동으로 찍혀 물어볼 수 없으므로 **그냥 버린다.**
const double trailMaxAccuracyMeters = 50.0;

/// 이 측정치를 궤적으로 쳐도 되는가 — 구멍을 내고 서버에 올릴지의 판정.
///
/// ⚠️ `accuracy <= 0` 은 **거른다.** Android 는 정확도를 모를 때 0 을 준다
/// (`Location.hasAccuracy()` 가 false). 모르는 것을 「완벽하다」로 읽으면
/// 가장 못 믿을 측정치가 가장 먼저 통과한다.
///
/// 화면 표시(지오펜스·발자취 마커·내 시야)는 이 판정 «밖»이다 — 그건 튀어도 다음
/// 갱신에 되돌아오지만, 저장되는 것은 안 되돌아온다.
bool isTrailWorthyAccuracy(double accuracyMeters) =>
    accuracyMeters > 0 && accuracyMeters <= trailMaxAccuracyMeters;

const double _metersPerDegreeLat = 111320.0;

/// [center] 중심 반경 [radiusMeters] 원을 [segments]각형으로 근사한 닫힌 고리.
///
/// **시계 방향**(북 → 동 → 남 → 서)으로 만든다 — 바깥 고리 방향이다. 구멍으로 쓸 때는
/// [fogHoleRing]으로 뒤집는다.
List<NLatLng> fogCircleRing(NLatLng center, double radiusMeters, int segments) {
  final latRadius = radiusMeters / _metersPerDegreeLat;
  final lngRadius = radiusMeters / (_metersPerDegreeLat * cos(center.latitude * pi / 180));
  final clockwise = List<NLatLng>.generate(segments, (i) {
    final angle = 2 * pi * i / segments;
    return NLatLng(
      center.latitude + latRadius * cos(angle),
      center.longitude + lngRadius * sin(angle),
    );
  });
  return [...clockwise, clockwise.first];
}

/// 구멍용 원 — 구멍은 바깥 고리와 **반대 방향**(반시계)으로 나열되어야 한다.
List<NLatLng> fogHoleRing(NLatLng center, double radiusMeters, int segments) =>
    fogCircleRing(center, radiusMeters, segments).reversed.toList();

/// 구멍 고리 [ring]을 [center] 중심 반경 [radiusMeters] 원 안쪽으로 잘라낸다
/// (Sutherland–Hodgman). 겹치는 부분이 없으면 `null`.
///
/// «내 시야»(반투명 원) 폴리곤에 궤적·스팟 구멍을 옮겨 뚫을 때 쓴다 — 구멍이 바깥
/// 고리를 삐져나가면 네이티브 삼각분할이 깨질 수 있어서, 반드시 안쪽으로 잘라서 넣는다.
/// 원도 구멍도 볼록다각형이라 교집합도 볼록이고, 이 알고리즘으로 정확히 나온다.
///
/// 잘라낼 원은 바깥 고리보다 **살짝 작게**([_visionClipShrink]) 잡는다 — 경계에 딱
/// 붙은 구멍도 삼각분할에서 퇴화 케이스라 피한다. 폭 1m 남짓이라 화면에선 안 보인다.
///
/// 결과는 **반시계**(구멍 방향)로 맞춰 돌려준다.
List<NLatLng>? clipFogHoleToCircle(
  List<NLatLng> ring,
  NLatLng center,
  double radiusMeters, {
  int segments = FogOverlayController.visionSegments,
}) {
  final metersPerDegreeLng = _metersPerDegreeLat * cos(center.latitude * pi / 180);
  Point<double> toLocal(NLatLng p) => Point(
        (p.longitude - center.longitude) * metersPerDegreeLng,
        (p.latitude - center.latitude) * _metersPerDegreeLat,
      );
  NLatLng toGeo(Point<double> p) => NLatLng(
        center.latitude + p.y / _metersPerDegreeLat,
        center.longitude + p.x / metersPerDegreeLng,
      );

  var output = [
    for (final p in ring) toLocal(p),
  ];
  if (output.length > 1 && output.first == output.last) output.removeLast();

  // 잘라낼 원 — (x=동, y=북) 평면에서 반시계. 반시계 볼록다각형의 «안»은 각 변의 왼쪽이다.
  final clipRadius = radiusMeters * _visionClipShrink;
  final clip = List<Point<double>>.generate(segments, (i) {
    final angle = 2 * pi * i / segments;
    return Point(clipRadius * cos(angle), clipRadius * sin(angle));
  });

  double side(Point<double> a, Point<double> b, Point<double> p) =>
      (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x);

  for (var i = 0; i < clip.length && output.isNotEmpty; i++) {
    final a = clip[i];
    final b = clip[(i + 1) % clip.length];
    final input = output;
    output = [];
    for (var j = 0; j < input.length; j++) {
      final current = input[j];
      final previous = input[(j + input.length - 1) % input.length];
      final currentSide = side(a, b, current);
      final previousSide = side(a, b, previous);
      if (currentSide >= 0) {
        if (previousSide < 0) output.add(_intersect(previous, current, previousSide, currentSide));
        output.add(current);
      } else if (previousSide >= 0) {
        output.add(_intersect(previous, current, previousSide, currentSide));
      }
    }
  }
  if (output.length < 3) return null;

  // 반시계로 맞춘다(신발끈 공식 — 양수면 반시계).
  var area = 0.0;
  for (var i = 0; i < output.length; i++) {
    final p = output[i];
    final q = output[(i + 1) % output.length];
    area += p.x * q.y - q.x * p.y;
  }
  if (area.abs() < 1e-6) return null;
  if (area < 0) output = output.reversed.toList();

  final geo = [for (final p in output) toGeo(p)];
  return [...geo, geo.first];
}

Point<double> _intersect(Point<double> p, Point<double> q, double pSide, double qSide) {
  final t = pSide / (pSide - qSide);
  return Point(p.x + (q.x - p.x) * t, p.y + (q.y - p.y) * t);
}

/// 시야 폴리곤에 옮겨 뚫는 구멍을 바깥 고리보다 얼마나 안쪽에서 자를지(비율).
///
/// 48각형 고리의 변 중점은 반경의 cos(π/48) ≈ 99.8% 지점이라, 97% 로 자르면
/// 잘린 구멍이 바깥 고리 «안»에 확실히 들어간다. 40m 기준 1.2m 차이다.
const double _visionClipShrink = 0.97;

/// 안개 오버레이를 관리한다 — **세 겹**이다.
///
/// 1. **짙은 안개**([_fog]) — 지도 이동 범위 전체를 덮는 사각형 한 장, 완전 불투명.
///    대한민국 땅만이 아니라 바다·이웃 나라까지 전부 가린다.
/// 2. **내 시야**([_vision]) — 현재 위치 반경 [visionRadiusMeters](40m) 원. 짙은 안개에
///    이 원만큼 구멍을 내고, 그 자리에 [visionFogColor](예전 반투명 안개)를 덮는다 —
///    «바로 곁은 흐릿하게 보인다».
/// 3. **걷힌 자리** — 걸어온 자리([trailRadiusMeters], 15m)와 인증한 스팟
///    ([spotClearRadiusMeters], 50m). 짙은 안개와 시야 양쪽에 구멍을 뚫어 완전히 맑다.
///
/// 네이버 지도의 [NPolygonOverlay]는 좌표 기준(geo-anchored)이라 줌/이동해도 지도와 함께
/// 움직인다.
class FogOverlayController {
  FogOverlayController._(this._mapController, this._fog);

  final NaverMapController _mapController;
  final NPolygonOverlay _fog;

  /// 내 시야 폴리곤. 첫 위치가 오기 전에는 없다 — 위치를 모르면 시야도 없다.
  NPolygonOverlay? _vision;
  NLatLng? _visionCenter;

  /// 걷힌 자리(궤적·스팟) 구멍. 키는 스팟 id 또는 [fogTrailKey].
  final Map<String, _Hole> _clearedHoles = {};
  bool _disposed = false;

  /// 짙은 안개 — 완전 불투명. 청회색 결은 예전 안개([visionFogColor])와 같다.
  static const fogColor = Color(0xFF48566B);

  /// 내 시야의 반투명 안개 — 예전 전역 안개와 같은 값(85%)이다. 아래 지도가 은은히 비친다.
  static const visionFogColor = Color(0xD948566B);

  /// 짙은 안개의 전역 z-index. 🔴 **0 이상이어야 한다.** 폴리곤 기본값(-200000)처럼
  /// 음수면 네이버 지도의 **심벌(지명·POI 라벨) 아래**에 그려져, 불투명 안개 위로 지명이
  /// 그대로 떠 «아예 가린» 게 아니게 된다. 마커(200000)·내 위치(300000)보다는 아래라
  /// 스팟·발자취 마커와 내 위치 점은 안개 위에 보인다 — 안 보이면 갈 곳을 못 찾는다.
  static const fogGlobalZIndex = 150000;

  /// 짙은 안개가 덮는 범위. 지도 이동 범위(`map_screen.dart`의 `_mapExtent`, 위도 32.5~39 ·
  /// 경도 124~132.5)보다 훨씬 넓게 잡는다 — 최소 줌(6)에서 범위 끝으로 밀어도 화면
  /// 가장자리가 안개 밖으로 나오지 않게.
  static const _fogBounds = NLatLngBounds(
    southWest: NLatLng(10.0, 100.0),
    northEast: NLatLng(60.0, 160.0),
  );

  /// 지도가 준비된 뒤 호출한다. 짙은 안개 한 장을 지도에 붙인다.
  static Future<FogOverlayController> attach(NaverMapController mapController) async {
    final sw = _fogBounds.southWest;
    final ne = _fogBounds.northEast;
    // 바깥 고리는 시계 방향(북서 → 북동 → 남동 → 남서) — 구멍(반시계)과 반대.
    final fog = NPolygonOverlay(
      id: 'fog',
      coords: [
        NLatLng(ne.latitude, sw.longitude),
        NLatLng(ne.latitude, ne.longitude),
        NLatLng(sw.latitude, ne.longitude),
        NLatLng(sw.latitude, sw.longitude),
        NLatLng(ne.latitude, sw.longitude),
      ],
      color: fogColor,
    )..setGlobalZIndex(fogGlobalZIndex);
    await mapController.addOverlay(fog);
    return FogOverlayController._(mapController, fog);
  }

  /// 내 시야 반경 — 이 안은 짙은 안개 대신 반투명 안개로 흐릿하게 보인다.
  static const visionRadiusMeters = 40.0;

  /// 시야 원의 분할 수. 인증 원과 같다 — 화면 한가운데 늘 떠 있어 각이 보이면 안 된다.
  static const visionSegments = 48;

  /// 인증한 스팟 주변을 걷어낼 반경.
  ///
  /// ⚠️ **인증 반경(서버 100m, `VisitProperties.radiusMeters`)과 다른 축이다.** 인증은
  /// «충분히 가까웠는가»를 보고, 이건 걷힌 자리를 얼마나 보여줄지다.
  static const spotClearRadiusMeters = 50.0;

  /// 걸어온 자리를 걷어낼 반경. 위치 스트림의 `distanceFilter`(15m)와 «같은 값»이다 —
  /// 갱신마다 15m 원을 뚫으면 원들이 서로 맞닿아 끊기지 않는 길이 된다. 더 작으면
  /// 점선이 되고, 더 크면 걷지 않은 골목까지 걷힌다.
  static const trailRadiusMeters = 15.0;

  /// 궤적 원의 분할 수. 인증 원(48)보다 성기게 잡는다 — 반경 15m 에서 12분할이면
  /// 실제 원과의 오차가 **0.5m** 라 화면에서 구분되지 않는데, 좌표 수는 1/4 이다.
  /// 궤적은 개수가 계속 늘어나므로 하나당 비용이 그대로 총량이 된다.
  static const _trailSegments = 12;

  static const _spotSegments = 48;

  /// 위치 갱신마다 호출한다 — 내 시야를 옮기고, [recordTrail]이면 걸어온 자리도 걷는다.
  ///
  /// 둘을 한 번에 받는 이유: 시야도 궤적도 짙은 안개의 구멍 목록을 바꾸는데, `setHoles`
  /// 는 호출마다 **전체 목록**을 보낸다. 따로 부르면 갱신마다 두 번 보낸다.
  ///
  /// [recordTrail]은 호출부가 [isTrailWorthyAccuracy]로 정한다 — 시야는 화면 표시라
  /// 정확도가 나빠도 옮기지만(다음 갱신에 되돌아온다), 궤적은 남으므로 거른다.
  ///
  /// **걸어온 자리는 인증과 다른 축이다.** 「지나간 자리」 표시일 뿐 **정복률에는 영향이
  /// 없다** — 정복률은 서버가 `visits` 로 계산한다(`GET /api/conquest`).
  ///
  /// ⚠️ **이 메서드는 화면만 만진다** — 궤적을 서버(`JourneyService.upload`)에 보내는
  /// 것은 호출부의 몫이다. 여기서 업로드까지 하면 복원 경로([clearTrails])가 방금 받은
  /// 점을 도로 올린다.
  void updatePosition(NLatLng center, {required bool recordTrail}) {
    if (_disposed) return;
    if (recordTrail) _addTrailHole(center);
    _visionCenter = center;
    _applyHoles();
  }

  /// 걸어온 자리 **여럿**을 한 번에 걷어낸다(#131) — 지도 진입 시 서버에서 받은
  /// 궤적으로 안개를 복원할 때 쓴다. 구멍을 다 모은 뒤 `setHoles` 는 한 번만 보낸다.
  ///
  /// 같은 자리를 다시 지나가도 «구멍이 늘지 않는다» — 좌표를 [trailRadiusMeters]
  /// 격자에 스냅해 키로 쓰기 때문이다([fogTrailKey]).
  void clearTrails(Iterable<NLatLng> centers) {
    var added = false;
    for (final center in centers) {
      added = _addTrailHole(center) || added;
    }
    if (added) _applyHoles();
  }

  /// [spots]({스팟 id: 좌표}) 전체를 **한 번에** 걷어낸다(#49) — 지도 진입 시 이미
  /// 인증한 스팟 목록으로 안개 상태를 복원할 때 쓴다.
  ///
  /// 스팟마다 따로 `setHoles` 를 보내면 호출마다 구멍 전체 목록이 가므로 총 비용이
  /// O(n²)로 는다 — 모아서 한 번만 반영한다.
  void clearCircles(Map<String, NLatLng> spots) {
    if (spots.isEmpty) return;
    for (final entry in spots.entries) {
      _clearedHoles[entry.key] = _Hole(entry.value, spotClearRadiusMeters, _spotSegments);
    }
    _applyHoles();
  }

  /// 방문 인증 성공 직후 호출한다(#49). 반경을 0에서 [spotClearRadiusMeters]까지 [steps]
  /// 단계로 넓혀가며 "즉시 사라지지 않고 퍼지듯" 걷히는 연출을 만든다.
  ///
  /// 지도를 벗어나는 등 도중에 [dispose]되면 남은 단계를 건너뛴다 — 이미 없어진
  /// 오버레이에 계속 `setHoles`를 보내지 않기 위함.
  Future<void> clearCircleAnimated(
    String spotId,
    NLatLng center, {
    Duration duration = const Duration(milliseconds: 600),
    int steps = 12,
  }) async {
    final stepDelay = duration ~/ steps;
    for (var i = 1; i <= steps; i++) {
      if (_disposed) return;
      _clearedHoles[spotId] = _Hole(center, spotClearRadiusMeters * i / steps, _spotSegments);
      _applyHoles();
      if (i < steps) await Future.delayed(stepDelay);
    }
  }

  void dispose() {
    _disposed = true;
    _mapController.deleteOverlay(_fog.info);
    final vision = _vision;
    if (vision != null) _mapController.deleteOverlay(vision.info);
  }

  /// 궤적 구멍을 저장만 한다. 이미 있던 칸이면 `false`.
  bool _addTrailHole(NLatLng center) {
    final key = fogTrailKey(center, trailRadiusMeters);
    if (_clearedHoles.containsKey(key)) return false;
    _clearedHoles[key] = _Hole(center, trailRadiusMeters, _trailSegments);
    return true;
  }

  /// 쌓인 구멍을 짙은 안개와 내 시야에 반영한다.
  ///
  /// ⚠️ **`.toList()`를 빼지 말 것.** `setHoles`의 시그니처는 `Iterable`을 받지만,
  /// 플러그인 내부 직렬화(`NPayload.convertToMessageable`)는 `List`만 처리하고 그 밖의
  /// `Iterable`은 `ArgumentError`로 던진다. `Map.values`는 지연 뷰
  /// (`_CompactValuesIterable`)라 여기에 걸린다.
  ///
  /// 그런데 `setHoles` → `_set`이 `void ... async`라 **그 예외가 앱을 죽이지도, 화면에
  /// 드러나지도 않는다.** 안개가 그냥 안 걷히기만 한다 — 실기기 로그를 보기 전까지
  /// 원인을 알 수 없었다.
  void _applyHoles() {
    final center = _visionCenter;
    _fog.setHoles([
      for (final hole in _clearedHoles.values) hole.ring,
      if (center != null) fogHoleRing(center, visionRadiusMeters, visionSegments),
    ]);
    if (center != null) _applyVision(center);
  }

  /// 내 시야 폴리곤을 [center]로 옮기고, 걷힌 자리 중 시야에 걸치는 것만 잘라 뚫는다.
  void _applyVision(NLatLng center) {
    final holes = <List<NLatLng>>[];
    for (final hole in _clearedHoles.values) {
      // 멀리 있는 구멍은 자르기 전에 거른다 — 궤적은 수천 개까지 쌓인다.
      if (_distanceMeters(hole.center, center) >= hole.radiusMeters + visionRadiusMeters) continue;
      final clipped = clipFogHoleToCircle(hole.ring, center, visionRadiusMeters);
      if (clipped != null) holes.add(clipped);
    }
    final coords = fogCircleRing(center, visionRadiusMeters, visionSegments);

    final vision = _vision;
    if (vision == null) {
      final created = NPolygonOverlay(
        id: 'fog-vision',
        coords: coords,
        color: visionFogColor,
        holes: holes,
      );
      _vision = created;
      _mapController.addOverlay(created);
      return;
    }
    // 고리를 옮기기 전에 구멍부터 비운다 — 옛 구멍이 새 고리 밖에 한 순간이라도 걸리지 않게.
    vision.setHoles(const <List<NLatLng>>[]);
    vision.setCoords(coords);
    if (holes.isNotEmpty) vision.setHoles(holes);
  }

  static double _distanceMeters(NLatLng a, NLatLng b) {
    final dy = (a.latitude - b.latitude) * _metersPerDegreeLat;
    final dx = (a.longitude - b.longitude) * _metersPerDegreeLat * cos(a.latitude * pi / 180);
    return sqrt(dx * dx + dy * dy);
  }
}

/// 걷힌 자리 하나 — 시야에 걸치는지 거르려고 중심·반경을 고리와 함께 들고 있다.
class _Hole {
  _Hole(this.center, this.radiusMeters, int segments)
      : ring = fogHoleRing(center, radiusMeters, segments);

  final NLatLng center;
  final double radiusMeters;
  final List<NLatLng> ring;
}
