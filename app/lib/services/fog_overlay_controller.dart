import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
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
/// 화면 표시(지오펜스·발자취 마커)는 이 판정 «밖»이다 — 그건 튀어도 다음 갱신에
/// 되돌아오지만, 저장되는 것은 안 되돌아온다.
bool isTrailWorthyAccuracy(double accuracyMeters) =>
    accuracyMeters > 0 && accuracyMeters <= trailMaxAccuracyMeters;

/// 대한민국 해안선 모양을 따라가는 안개 오버레이를 관리한다.
///
/// 사각형 대신 실제 국토 외곽선(본토+도서 각각의 폴리곤, [_boundaryAssetPath])으로
/// 안개를 그리므로 바다나 이웃 나라 위에는 안개가 덮이지 않는다. 네이버 지도의
/// [NPolygonOverlay]는 좌표 기준(geo-anchored)이라 줌/이동해도 지도와 함께 자연스럽게
/// 움직인다. 스팟 인증으로 걷어낼 영역은 해당 landmass 폴리곤의 구멍(holes)으로
/// 표현한다 — Phase 3(#28 스팟 마커 · 안개 걷힘)에서 [clearCircle]을 호출해 채워나가면 된다.
class FogOverlayController {
  FogOverlayController._(this._mapController, this._landmasses);

  final NaverMapController _mapController;
  final List<_Landmass> _landmasses;
  bool _disposed = false;

  /// 안개 색상/투명도. 앱 테마(ColorScheme seed `0xFF5B7A99`)와 어울리는 톤의
  /// 짙은 청회색 + 85% 불투명도로, 아래 지도가 은은히 비치되 스팟은 가려지도록 한다.
  static const fogColor = Color(0xD948566B);

  static const _boundaryAssetPath = 'assets/geo/kr_boundary.json';

  /// 지도가 준비된 뒤 호출한다. 국경 데이터를 읽어 landmass별 폴리곤 오버레이를
  /// 만들고 한 번에 지도에 추가한다.
  static Future<FogOverlayController> attach(NaverMapController mapController) async {
    final raw = await rootBundle.loadString(_boundaryAssetPath);
    final rings = (jsonDecode(raw) as List).cast<List>().map((ring) {
      return ring
          .cast<List>()
          .map((p) => NLatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
          .toList();
    }).toList();

    final landmasses = [
      for (var i = 0; i < rings.length; i++) _Landmass(index: i, outerRing: rings[i]),
    ];

    await mapController.addOverlayAll(landmasses.map((l) => l.overlay).toSet());
    return FogOverlayController._(mapController, landmasses);
  }

  /// 걸어온 자리를 걷어낼 반경. 위치 스트림의 `distanceFilter`(15m)와 «같은 값»이다 —
  /// 갱신마다 15m 원을 뚫으면 원들이 서로 맞닿아 끊기지 않는 길이 된다. 더 작으면
  /// 점선이 되고, 더 크면 걷지 않은 골목까지 걷힌다.
  static const trailRadiusMeters = 15.0;

  /// 궤적 원의 분할 수. 인증 원(48)보다 성기게 잡는다 — 반경 15m 에서 12분할이면
  /// 실제 원과의 오차가 **0.5m** 라 화면에서 구분되지 않는데, 좌표 수는 1/4 이다.
  /// 궤적은 개수가 계속 늘어나므로 하나당 비용이 그대로 총량이 된다.
  static const _trailSegments = 12;

  /// 걸어온 자리의 안개를 걷어낸다.
  ///
  /// **인증(150m)과 다른 축이다.** 이건 「지나간 자리」 표시일 뿐이고 **정복률에는
  /// 영향이 없다** — 정복률은 서버가 `visits` 로 계산한다(`GET /api/conquest`).
  /// 걸어서 걷힌 안개가 정복으로 세어지면 사진 인증을 할 이유가 없어진다.
  ///
  /// 같은 자리를 다시 지나가도 «구멍이 늘지 않는다» — 좌표를 [trailRadiusMeters]
  /// 격자에 스냅해 키로 쓰기 때문이다. 안 그러면 같은 길을 왕복할 때마다 거의
  /// 겹치는 원이 쌓이고, `setHoles` 가 매번 전체 목록을 보내므로 비용이 제곱으로 는다.
  ///
  /// 🔑 **앱을 다시 켜도 남는다.** 호출부가 같은 점을 `journey_points` 에 올리고
  /// (`JourneyService.upload`), 지도가 뜰 때 `GET /api/journeys` 로 되돌린다
  /// ([#131](../../issues/131)). 인증으로 걷힌 안개가 `GET /api/visits` 로 복원되는
  /// 것과 같은 모양이다.
  ///
  /// ⚠️ 다만 **이 메서드 자체는 화면만 만진다** — 서버에 보내는 것은 호출부의 몫이다.
  /// 여기서 업로드까지 하면 복원 경로(`clearTrails`)가 방금 받은 점을 도로 올린다.
  void clearTrail(NLatLng center, {double radiusMeters = trailRadiusMeters}) {
    final landmass = _landmassFor(center);
    final key = fogTrailKey(center, radiusMeters);
    if (landmass._hasHole(key)) return;
    landmass._addHole(key, center, radiusMeters: radiusMeters, segments: _trailSegments);
    landmass._applyHoles();
  }

  /// 걸어온 자리 **여럿**을 한 번에 걷어낸다(#131) — 지도 진입 시 서버에서 받은
  /// 궤적으로 안개를 복원할 때 쓴다.
  ///
  /// [clearTrail] 을 점 수만큼 반복하면 호출마다 landmass 의 구멍 «전체»를 다시
  /// 지도에 보내므로(`setHoles`) 총 비용이 O(n²) 가 된다 — [clearCircles] 가 스팟에
  /// 대해 푼 것과 같은 문제다. 여기서는 모아둔 뒤 landmass 하나당 한 번만 반영한다.
  void clearTrails(Iterable<NLatLng> centers, {double radiusMeters = trailRadiusMeters}) {
    final touched = <_Landmass>{};
    for (final center in centers) {
      final landmass = _landmassFor(center);
      final key = fogTrailKey(center, radiusMeters);
      if (landmass._hasHole(key)) continue;
      landmass._addHole(key, center, radiusMeters: radiusMeters, segments: _trailSegments);
      touched.add(landmass);
    }
    for (final landmass in touched) {
      landmass._applyHoles();
    }
  }

  /// [spotId] 위치의 반경 [radiusMeters] 안 안개를 걷어낸다(방문 인증 시 호출 예정).
  ///
  /// [center]를 포함하는 landmass 폴리곤을 찾아 그 폴리곤에만 구멍을 낸다.
  /// 어떤 landmass에도 속하지 않으면(예: 좌표 오차로 해안선 바로 바깥) 아무 일도 하지 않는다.
  void clearCircle(String spotId, NLatLng center, {double radiusMeters = 150, int segments = 48}) {
    final landmass = _landmassFor(center);
    landmass._addHole(spotId, center, radiusMeters: radiusMeters, segments: segments);
    landmass._applyHoles();
  }

  /// [spots]({스팟 id: 좌표}) 전체를 **한 번에** 걷어낸다(#49) — 지도 진입 시 이미
  /// 인증한 스팟 목록으로 안개 상태를 복원할 때 쓴다.
  ///
  /// [clearCircle]을 스팟 수만큼 반복 호출하면 호출마다 해당 landmass의 구멍 전체
  /// 목록을 다시 지도에 보내므로(`setHoles`), 스팟이 많아질수록(수백 개) 총 비용이
  /// O(n²)로 늘어난다. 여기서는 구멍을 모두 계산해 landmass별로 모아둔 뒤,
  /// landmass 하나당 `setHoles`를 **한 번만** 호출해 O(n)으로 끝낸다.
  void clearCircles(Map<String, NLatLng> spots, {double radiusMeters = 150, int segments = 48}) {
    final touched = <_Landmass>{};
    for (final entry in spots.entries) {
      final landmass = _landmassFor(entry.value);
      landmass._addHole(entry.key, entry.value, radiusMeters: radiusMeters, segments: segments);
      touched.add(landmass);
    }
    for (final landmass in touched) {
      landmass._applyHoles();
    }
  }

  /// 방문 인증 성공 직후 호출한다(#49). 반경을 0에서 [radiusMeters]까지 [steps]단계로
  /// 넓혀가며 "즉시 사라지지 않고 퍼지듯" 걷히는 연출을 만든다.
  ///
  /// 지도를 벗어나는 등 도중에 [dispose]되면 남은 단계를 건너뛴다 — 이미 없어진
  /// 오버레이에 계속 `setHoles`를 보내지 않기 위함.
  Future<void> clearCircleAnimated(
    String spotId,
    NLatLng center, {
    double radiusMeters = 150,
    int segments = 48,
    Duration duration = const Duration(milliseconds: 600),
    int steps = 12,
  }) async {
    final landmass = _landmassFor(center);
    final stepDelay = duration ~/ steps;
    for (var i = 1; i <= steps; i++) {
      if (_disposed) return;
      landmass._addHole(spotId, center, radiusMeters: radiusMeters * i / steps, segments: segments);
      landmass._applyHoles();
      if (i < steps) await Future.delayed(stepDelay);
    }
  }

  /// 다시 안개로 덮는다(주로 테스트/디버그용).
  void reFog(String spotId) {
    for (final landmass in _landmasses) {
      landmass.reFog(spotId);
    }
  }

  void dispose() {
    _disposed = true;
    for (final landmass in _landmasses) {
      _mapController.deleteOverlay(landmass.overlay.info);
    }
  }

  /// [center]를 포함하는 landmass. 어떤 landmass에도 속하지 않으면(해안선 바로
  /// 바깥 등) 가장 가까운 landmass로 대체한다.
  _Landmass _landmassFor(NLatLng center) {
    return _landmasses.firstWhere(
      (l) => l._containsPoint(center),
      orElse: () => _nearestLandmass(center),
    );
  }

  _Landmass _nearestLandmass(NLatLng point) {
    return _landmasses.reduce((a, b) => a._distanceTo(point) <= b._distanceTo(point) ? a : b);
  }
}

class _Landmass {
  _Landmass({required this.index, required this.outerRing});

  final int index;
  final List<NLatLng> outerRing;
  final Map<String, List<NLatLng>> _clearedHoles = {};

  late final NPolygonOverlay overlay = NPolygonOverlay(
    id: 'fog-landmass-$index',
    coords: outerRing,
    color: FogOverlayController.fogColor,
  );

  bool _hasHole(String key) => _clearedHoles.containsKey(key);

  /// 구멍을 계산해 저장만 한다 — 지도에는 반영하지 않는다. 여러 스팟을 모아 한 번에
  /// [_applyHoles]하려는 호출자([FogOverlayController.clearCircles])를 위한 분리.
  void _addHole(String spotId, NLatLng center, {required double radiusMeters, required int segments}) {
    _clearedHoles[spotId] = _circleRing(center, radiusMeters, segments);
  }

  /// [_addHole]로 쌓인 구멍 전체를 지도에 한 번에 반영한다.
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
    overlay.setHoles(_clearedHoles.values.toList());
  }

  void reFog(String spotId) {
    if (_clearedHoles.remove(spotId) != null) {
      // 위와 같은 이유로 .toList()가 필요하다.
      overlay.setHoles(_clearedHoles.values.toList());
    }
  }

  /// 좌표가 이 landmass 폴리곤 내부에 있는지 레이 캐스팅(ray casting)으로 판정한다.
  bool _containsPoint(NLatLng point) {
    var inside = false;
    for (var i = 0, j = outerRing.length - 1; i < outerRing.length; j = i++) {
      final pi = outerRing[i];
      final pj = outerRing[j];
      final intersects = (pi.longitude > point.longitude) != (pj.longitude > point.longitude) &&
          point.latitude <
              (pj.latitude - pi.latitude) *
                      (point.longitude - pi.longitude) /
                      (pj.longitude - pi.longitude) +
                  pi.latitude;
      if (intersects) inside = !inside;
    }
    return inside;
  }

  double _distanceTo(NLatLng point) {
    final dLat = outerRing.first.latitude - point.latitude;
    final dLng = outerRing.first.longitude - point.longitude;
    return dLat * dLat + dLng * dLng;
  }

  /// [center] 중심의 원을 반경 [radiusMeters]로 근사하는 다각형 좌표 목록을 만든다.
  ///
  /// 구멍(holes)은 바깥 다각형([outerRing])과 **반대 방향**으로 나열되어야 하므로,
  /// 시계 방향으로 생성한 뒤 뒤집는다.
  List<NLatLng> _circleRing(NLatLng center, double radiusMeters, int segments) {
    const metersPerDegreeLat = 111320.0;
    final latRadius = radiusMeters / metersPerDegreeLat;
    final lngRadius = radiusMeters / (metersPerDegreeLat * cos(center.latitude * pi / 180));

    final clockwise = List<NLatLng>.generate(segments, (i) {
      final angle = 2 * pi * i / segments;
      return NLatLng(
        center.latitude + latRadius * cos(angle),
        center.longitude + lngRadius * sin(angle),
      );
    });
    final ring = [...clockwise, clockwise.first];
    return ring.reversed.toList();
  }
}
