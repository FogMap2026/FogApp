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
bool isTrailWorthyAccuracy(double accuracyMeters) => accuracyMeters > 0 && accuracyMeters <= trailMaxAccuracyMeters;

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

  /// 안개 색상/투명도. 짙은 청회색 + 85% 불투명도로, 아래 지도가 은은히 비치되 스팟은 가려지도록 한다.
  ///
  /// 앱 테마(`theme/app_theme.dart`)는 Notion 체계로 바뀌었지만 이 값은 그대로 둔다 — 안개는
  /// 화면의 유일한 «어두운 섬»이고, 테마의 남색 `AppColors.secondary` 와 같은 결이다. 바꾸면
  /// 스토어 그래픽·스크린샷의 안개색과 어긋난다.
  static const fogColor = Color(0xD948566B);

  static const _boundaryAssetPath = 'assets/geo/kr_boundary.json';

  /// 지도가 준비된 뒤 호출한다. 국경 데이터를 읽어 landmass별 폴리곤 오버레이를
  /// 만들고 한 번에 지도에 추가한다.
  static Future<FogOverlayController> attach(NaverMapController mapController) async {
    final raw = await rootBundle.loadString(_boundaryAssetPath);
    final rings = (jsonDecode(raw) as List).cast<List>().map((ring) {
      return ring.cast<List>().map((p) => NLatLng((p[0] as num).toDouble(), (p[1] as num).toDouble())).toList();
    }).toList();

    final landmasses = [
      for (var i = 0; i < rings.length; i++) _Landmass(index: i, outerRing: rings[i], mapController: mapController),
    ];

    await mapController.addOverlayAll(landmasses.map((l) => l.overlay).toSet());
    return FogOverlayController._(mapController, landmasses);
  }

  /// 궤적 점을 «같은 자리»로 묶는 격자 크기. 위치 스트림의 `distanceFilter`(15m)와
  /// 같은 값이다 — 스트림이 15m 마다 한 점을 주므로, 15m 칸이면 같은 자리를 두 번 밟아도
  /// 점이 하나다([fogTrailKey]). [trailRadiusMeters] 와는 «다른 값»이다: 이건 중복을
  /// 거르는 눈금이고, 저건 얼마나 넓게 걷어낼지다. 둘을 같은 값으로 두면 반경을 키울 때
  /// 눈금도 같이 커져 점 사이가 벌어지고 길이 끊긴다.
  static const trailCellMeters = 15.0;

  /// 걸어온 자리를 걷어낼 반경. 15m 점마다 50m 원을 뚫으면 원들이 크게 겹쳐
  /// 폭 100m 의 띠가 된다 — 걸은 길뿐 아니라 그 양옆 건물 한 줄까지 보인다.
  ///
  /// 겹침은 [_Landmass] 가 격자 합집합으로 풀어 «구멍의 구멍»이 생기지 않는다 —
  /// 원을 구멍으로 그대로 뚫으면 폴리곤이 짝홀(even-odd)로 채워져 겹친 자리가
  /// 도로 안개가 된다.
  static const trailRadiusMeters = 50.0;

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
    final key = fogTrailKey(center, trailCellMeters);
    if (landmass._hasHole(key)) return;
    landmass._addHole(key, center, radiusMeters: radiusMeters);
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
      final key = fogTrailKey(center, trailCellMeters);
      if (landmass._hasHole(key)) continue;
      landmass._addHole(key, center, radiusMeters: radiusMeters);
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
  void clearCircle(String spotId, NLatLng center, {double radiusMeters = 150}) {
    final landmass = _landmassFor(center);
    landmass._addHole(spotId, center, radiusMeters: radiusMeters);
    landmass._applyHoles();
  }

  /// [spots]({스팟 id: 좌표}) 전체를 **한 번에** 걷어낸다(#49) — 지도 진입 시 이미
  /// 인증한 스팟 목록으로 안개 상태를 복원할 때 쓴다.
  ///
  /// [clearCircle]을 스팟 수만큼 반복 호출하면 호출마다 해당 landmass의 구멍 전체
  /// 목록을 다시 지도에 보내므로(`setHoles`), 스팟이 많아질수록(수백 개) 총 비용이
  /// O(n²)로 늘어난다. 여기서는 구멍을 모두 계산해 landmass별로 모아둔 뒤,
  /// landmass 하나당 `setHoles`를 **한 번만** 호출해 O(n)으로 끝낸다.
  void clearCircles(Map<String, NLatLng> spots, {double radiusMeters = 150}) {
    final touched = <_Landmass>{};
    for (final entry in spots.entries) {
      final landmass = _landmassFor(entry.value);
      landmass._addHole(entry.key, entry.value, radiusMeters: radiusMeters);
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
    Duration duration = const Duration(milliseconds: 600),
    int steps = 12,
  }) async {
    final landmass = _landmassFor(center);
    final stepDelay = duration ~/ steps;
    for (var i = 1; i <= steps; i++) {
      if (_disposed) return;
      landmass._addHole(spotId, center, radiusMeters: radiusMeters * i / steps);
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
  _Landmass({required this.index, required this.outerRing, required NaverMapController mapController})
      : _mapController = mapController;

  final int index;
  final List<NLatLng> outerRing;
  final NaverMapController _mapController;

  /// 걷힌 자리 — «격자 셀의 합집합». 셀 키 → 그 셀을 덮는 원의 수(참조 카운트).
  ///
  /// 원마다 구멍을 하나씩 뚫지 않는 이유: 폴리곤은 구멍을 짝홀(even-odd)로 채워서
  /// **구멍 둘이 겹친 자리는 도로 안개가 된다**(구멍의 구멍). 15m 마다 50m 원을
  /// 뚫으면 거의 전부 겹치므로 길이 통째로 안개가 됐다. 합집합으로 들고 외곽선만
  /// 구멍으로 내면 겹침 자체가 없다.
  final Map<int, int> _cellCount = {};

  /// 지웠다 되돌릴 수 있어야 하는 것(스팟 — 인증 연출 중 반경이 자라고 [reFog] 가
  /// 있다)만 어느 셀을 덮었는지 기억한다. 궤적은 되돌릴 일이 없어 키만 남긴다 —
  /// 하루치 궤적 수천 점의 셀 목록을 다 들고 있으면 메모리가 수십 MB 다.
  final Map<String, List<int>> _spotCells = {};
  final Set<String> _trailKeys = {};

  /// 안개 «섬» — 걷힌 띠가 고리를 이루면 그 안쪽은 안개로 남아야 하는데, 폴리곤은
  /// 「구멍 안의 채움」을 표현하지 못한다. 그런 섬은 따로 작은 안개 폴리곤으로 올린다.
  final List<NPolygonOverlay> _islands = [];
  int _islandSerial = 0;

  late final NPolygonOverlay overlay = NPolygonOverlay(
    id: 'fog-landmass-$index',
    coords: outerRing,
    color: FogOverlayController.fogColor,
  );

  bool _hasHole(String key) => _trailKeys.contains(key) || _spotCells.containsKey(key);

  /// 원을 격자에 굽는다(저장만). 같은 [key] 가 있으면 그 원을 먼저 걷어낸다 —
  /// 인증 연출([FogOverlayController.clearCircleAnimated])이 반경을 키우며 다시 부른다.
  void _addHole(String key, NLatLng center, {required double radiusMeters}) {
    if (key.startsWith('trail:')) {
      _trailKeys.add(key);
      for (final cell in FogGrid.cellsInCircle(center, radiusMeters)) {
        _cellCount.update(cell, (n) => n + 1, ifAbsent: () => 1);
      }
      return;
    }
    _releaseSpot(key);
    final cells = FogGrid.cellsInCircle(center, radiusMeters);
    for (final cell in cells) {
      _cellCount.update(cell, (n) => n + 1, ifAbsent: () => 1);
    }
    _spotCells[key] = cells;
  }

  void _releaseSpot(String key) {
    final cells = _spotCells.remove(key);
    if (cells == null) return;
    for (final cell in cells) {
      final n = _cellCount[cell];
      if (n == null) continue;
      if (n <= 1) {
        _cellCount.remove(cell);
      } else {
        _cellCount[cell] = n - 1;
      }
    }
  }

  /// 합집합의 외곽선을 구멍으로 보낸다. 안쪽에 남은 안개 섬은 별도 폴리곤으로.
  ///
  /// ⚠️ `setHoles` 에는 **`List`** 를 넘겨야 한다 — 플러그인 직렬화가 `Iterable` 을
  /// 받지 못하고, 그 예외는 `void async` 안에서 삼켜져 안개가 «그냥 안 걷힌다».
  void _applyHoles() {
    final outlines = FogGrid.outlines(_cellCount);
    overlay.setHoles(outlines.holes);
    _syncIslands(outlines.islands);
  }

  void _syncIslands(List<List<NLatLng>> rings) {
    for (final island in _islands) {
      _mapController.deleteOverlay(island.info);
    }
    _islands.clear();
    for (final ring in rings) {
      final island = NPolygonOverlay(
        id: 'fog-island-$index-${_islandSerial++}',
        coords: ring,
        color: FogOverlayController.fogColor,
      );
      _islands.add(island);
      _mapController.addOverlay(island);
    }
  }

  void reFog(String spotId) {
    if (!_spotCells.containsKey(spotId)) return;
    _releaseSpot(spotId);
    _applyHoles();
  }

  bool _containsPoint(NLatLng point) {
    var inside = false;
    for (var i = 0, j = outerRing.length - 1; i < outerRing.length; j = i++) {
      final pi = outerRing[i];
      final pj = outerRing[j];
      final intersects = (pi.longitude > point.longitude) != (pj.longitude > point.longitude) &&
          point.latitude <
              (pj.latitude - pi.latitude) * (point.longitude - pi.longitude) / (pj.longitude - pi.longitude) +
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
}

/// 걷힌 자리를 굽는 격자와, 그 합집합의 외곽선 추적.
///
/// 격자는 위·경도에 고정된다(셀 = [cellMeters] 남북 × 약 [cellMeters] 동서). 동서
/// 폭은 위도 36° 기준으로 잡아 한반도 안에서 ±4% 차이가 난다 — 이건 «굽는 눈금»일
/// 뿐이라 상관없다. 원이 셀에 들어가는지는 원 중심 위도의 실제 미터로 판정한다.
///
/// [FogOverlayController] 밖에 두는 것은 지도 컨트롤러 없이 검증하기 위해서다
/// (`fog_grid_test.dart`).
class FogGrid {
  /// 굽는 눈금. 작을수록 원이 둥글게 나오지만 셀·꼭짓점 수가 제곱으로 는다.
  /// 3m 면 줌 15(3.8m/px)에서 계단이 1px 이 안 돼 보이지 않고, 최대 줌(≈0.15m/px)에서
  /// 20px 계단이 드러난다. 6m 로 해봤더니 최대 줌에서 40px 계단이 눈에 띄어 반으로 줄였다
  /// (실기기, 09-14). 5km 걸어도 셀은 5만 개 남짓이라 갱신마다 외곽선을 다시 긋는 비용은
  /// 수 ms 다.
  static const cellMeters = 3.0;

  static const _metersPerDegreeLat = 111320.0;
  static const double _latStep = cellMeters / _metersPerDegreeLat;
  static final double _lngStep = cellMeters / (_metersPerDegreeLat * cos(36 * pi / 180));

  /// 셀·꼭짓점 키 = 행 << 26 | 열. 한반도 열 번호는 200만 안쪽이라 26비트(6,700만)면 된다.
  static const _colBits = 26;
  static const _colMask = (1 << _colBits) - 1;

  static int _key(int row, int col) => (row << _colBits) | col;
  static int _row(int key) => key >> _colBits;
  static int _col(int key) => key & _colMask;

  /// [center] 중심 반경 [radiusMeters] 원이 «중심을 덮는» 셀들.
  static List<int> cellsInCircle(NLatLng center, double radiusMeters) {
    final metersPerDegreeLng = _metersPerDegreeLat * cos(center.latitude * pi / 180);
    final r2 = radiusMeters * radiusMeters;
    final rowMin = ((center.latitude - radiusMeters / _metersPerDegreeLat) / _latStep).floor();
    final rowMax = ((center.latitude + radiusMeters / _metersPerDegreeLat) / _latStep).ceil();
    final cells = <int>[];
    for (var row = rowMin; row <= rowMax; row++) {
      final dy = ((row + 0.5) * _latStep - center.latitude) * _metersPerDegreeLat;
      if (dy * dy > r2) continue;
      final dx = sqrt(r2 - dy * dy);
      final colMin = ((center.longitude - dx / metersPerDegreeLng) / _lngStep).floor();
      final colMax = ((center.longitude + dx / metersPerDegreeLng) / _lngStep).ceil();
      for (var col = colMin; col <= colMax; col++) {
        final cx = ((col + 0.5) * _lngStep - center.longitude) * metersPerDegreeLng;
        if (cx * cx + dy * dy <= r2) cells.add(_key(row, col));
      }
    }
    return cells;
  }

  /// 셀 합집합의 경계를 닫힌 고리들로 만든다.
  ///
  /// 셀마다 이웃이 없는 변을 **반시계**(동→북→서→남 순으로 도는 방향)로 나열하고,
  /// 끝점이 맞는 변끼리 이어 고리를 만든다. 그러면 걷힌 영역의 바깥 둘레는
  /// 반시계(= 구멍 방향, 바깥 고리와 반대), 그 안에 남은 안개 섬의 둘레는
  /// 시계가 된다 — 부호 있는 넓이로 둘을 가른다.
  ///
  /// 같은 꼭짓점에서 변이 둘 나갈 수 있다(셀이 대각선으로만 맞닿을 때). 어느 쪽을
  /// 따라가도 닫힌 고리가 나오고 짝홀 채움 결과는 같다.
  static FogOutlines outlines(Map<int, int> cells) {
    final next = <int, List<int>>{};
    void edge(int from, int to) => next.putIfAbsent(from, () => []).add(to);
    // 꼭짓점 (r, c) = 셀 (r, c) 의 남서 모서리.
    for (final cell in cells.keys) {
      final r = _row(cell);
      final c = _col(cell);
      if (!cells.containsKey(_key(r, c + 1))) edge(_key(r, c + 1), _key(r + 1, c + 1)); // 동변 ↑
      if (!cells.containsKey(_key(r + 1, c))) edge(_key(r + 1, c + 1), _key(r + 1, c)); // 북변 ←
      if (!cells.containsKey(_key(r, c - 1))) edge(_key(r + 1, c), _key(r, c)); // 서변 ↓
      if (!cells.containsKey(_key(r - 1, c))) edge(_key(r, c), _key(r, c + 1)); // 남변 →
    }

    final holes = <List<NLatLng>>[];
    final islands = <List<NLatLng>>[];
    while (next.isNotEmpty) {
      final start = next.keys.first;
      final loop = <int>[start];
      var current = start;
      while (true) {
        final outgoing = next[current];
        // 끊긴 고리는 있을 수 없지만, 있더라도 무한루프는 막는다.
        if (outgoing == null || outgoing.isEmpty) break;
        final to = outgoing.removeLast();
        if (outgoing.isEmpty) next.remove(current);
        if (to == start) break;
        loop.add(to);
        current = to;
      }
      if (loop.length < 4) continue;
      final ring = _simplify(loop);
      final area = _signedArea(ring);
      if (area == 0) continue;
      final coords = [for (final v in ring) _vertex(v), _vertex(ring.first)];
      (area > 0 ? holes : islands).add(coords);
    }
    return FogOutlines(holes: holes, islands: islands);
  }

  /// 한 방향으로 이어지는 꼭짓점을 지운다 — 계단이 아닌 직선 구간은 양 끝만 남긴다.
  static List<int> _simplify(List<int> loop) {
    final out = <int>[];
    final n = loop.length;
    for (var i = 0; i < n; i++) {
      final prev = loop[(i + n - 1) % n];
      final cur = loop[i];
      final nxt = loop[(i + 1) % n];
      final d1r = _row(cur) - _row(prev);
      final d1c = _col(cur) - _col(prev);
      final d2r = _row(nxt) - _row(cur);
      final d2c = _col(nxt) - _col(cur);
      if (d1r == d2r && d1c == d2c) continue;
      out.add(cur);
    }
    return out;
  }

  /// 신발끈 공식(격자 단위). 양수면 반시계.
  static int _signedArea(List<int> ring) {
    var area = 0;
    for (var i = 0; i < ring.length; i++) {
      final p = ring[i];
      final q = ring[(i + 1) % ring.length];
      area += _col(p) * _row(q) - _col(q) * _row(p);
    }
    return area;
  }

  static NLatLng _vertex(int key) => NLatLng(_row(key) * _latStep, _col(key) * _lngStep);
}

/// [FogGrid.outlines] 의 결과.
class FogOutlines {
  const FogOutlines({required this.holes, required this.islands});

  /// 걷힌 영역의 바깥 둘레 — 안개 폴리곤의 구멍(반시계).
  final List<List<NLatLng>> holes;

  /// 걷힌 띠에 둘러싸여 남은 안개 — 별도 폴리곤(시계).
  final List<List<NLatLng>> islands;
}
