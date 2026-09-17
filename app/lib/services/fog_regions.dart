import 'dart:math';

import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../models/spot_coord.dart';

/// 안개의 «구역» — 지도를 스팟 하나당 구역 하나로 나눈다.
///
/// 원(궤적 100m·스팟 150m)으로 걷던 안개는 «어디까지 밝혔나»가 흐릿했다. 탐험 현황이 시/도
/// 17개로 나뉘듯 지도도 구역으로 나눠, 구역 하나가 통째로 걷히는 편이 «한 칸 채웠다»로 읽힌다
/// (시진, 09-15). 구역은 스팟을 씨앗으로 한 **보로노이 셀**이다 — 어느 점이든 가장 가까운
/// 스팟의 구역에 속한다. 스팟이 없는 빈 땅에는 [fillSpacingMeters] 간격으로 가상 씨앗을 깔아
/// 비슷한 크기의 구역을 만든다(안 그러면 시골 한 구역이 군 하나만 하다).
///
/// 걷히는 규칙(지도 화면이 정한다):
/// - 스팟 구역: 걸어 들어가도 100m 궤적만 걷히고, **그 스팟을 인증해야** 구역 전체가 걷힌다.
/// - 빈 땅 구역: **들어가기만 하면** 구역 전체가 걷힌다.
///
/// 전국 스팟 12,600개 + 가상 씨앗 ≈ 10만 개. 셀은 미리 만들지 않고 필요할 때 이웃만 보고
/// 자른다([cell]) — 전체 보로노이 다이어그램은 필요 없다. 지도 없이 검증한다(`fog_regions_test.dart`).
class FogRegions {
  FogRegions._(this.seeds, this._buckets);

  /// 빈 땅 가상 씨앗 간격(육각 격자). 구역 하나의 크기 — 시골에서 «한 동네» 정도.
  static const fillSpacingMeters = 1500.0;

  /// 이 거리 안에 스팟이 하나도 없어야 가상 씨앗을 둔다. 간격보다 작아야 스팟 바로 옆에 가상
  /// 씨앗이 안 생기면서도 빈 땅이 안 남는다.
  static const emptyThresholdMeters = 1000.0;

  /// 셀 상한 — 이웃이 전혀 없어도 이보다 크지 않다(±cap 상자에서 자르기 시작한다).
  static const cellCapMeters = 2500.0;

  /// 셀을 자를 때 볼 이웃 범위. 상자 반폭의 두 배면 상자를 벗어나는 이웃은 셀에 영향이 없다.
  static const neighborRangeMeters = cellCapMeters * 2;

  static const _bucketDeg = 0.02; // ≈ 2.2km
  static const _mPerLat = 111320.0;

  final List<FogRegionSeed> seeds;
  final Map<int, List<int>> _buckets;

  static int _bucketKey(double lat, double lng) => (lat / _bucketDeg).floor() * 100000 + (lng / _bucketDeg).floor();

  static double _mPerLng(double lat) => _mPerLat * cos(lat * pi / 180);

  /// 스팟 좌표로 구역을 만든다. [land] 를 주면 바다 위에는 가상 씨앗을 깔지 않는다 — 안 거르면
  /// 상자 안의 절반이 바다라 씨앗 21만 개 중 10만 개가 쓸모없이 메모리를 먹는다.
  ///
  /// 한반도 밖 좌표(0,0·위경도 뒤바뀜)는 뺀다 — 하나만 있어도 상자가 수천 km 로 늘어나 가상
  /// 씨앗이 수천만 개가 된다(실기기: 3천만 개, 37초).
  static FogRegions build(Iterable<SpotCoord> spots, {LandMask? land}) {
    final seeds = <FogRegionSeed>[];
    final buckets = <int, List<int>>{};
    void add(double lat, double lng, int? spotId) {
      final seed = FogRegionSeed(index: seeds.length, lat: lat, lng: lng, spotId: spotId);
      seeds.add(seed);
      buckets.putIfAbsent(_bucketKey(lat, lng), () => []).add(seed.index);
    }

    for (final s in spots) {
      if (s.lat < 33 || s.lat > 39 || s.lng < 124 || s.lng > 132) continue;
      add(s.lat, s.lng, s.id);
    }
    if (seeds.isEmpty) return FogRegions._(seeds, buckets);

    // 빈 땅 판정은 «스팟만» 보고 한다 — 가상 씨앗을 더해 가는 buckets 와 리스트를 공유하면
    // 방금 깐 가상 씨앗이 다음 판정에 끼어든다.
    final spotsOnly = FogRegions._(List.of(seeds), {for (final e in buckets.entries) e.key: List.of(e.value)});

    var minLat = seeds.first.lat, maxLat = minLat, minLng = seeds.first.lng, maxLng = minLng;
    for (final s in seeds) {
      minLat = min(minLat, s.lat);
      maxLat = max(maxLat, s.lat);
      minLng = min(minLng, s.lng);
      maxLng = max(maxLng, s.lng);
    }
    const margin = 3000 / _mPerLat;
    const rowStep = fillSpacingMeters * 0.866 / _mPerLat;
    var row = 0;
    for (var lat = minLat - margin; lat <= maxLat + margin; lat += rowStep, row++) {
      final colStep = fillSpacingMeters / _mPerLng(lat);
      final offset = row.isOdd ? colStep / 2 : 0.0;
      for (var lng = minLng - margin + offset; lng <= maxLng + margin; lng += colStep) {
        if (land != null && !land.contains(lat, lng)) continue;
        if (spotsOnly._within(lat, lng, emptyThresholdMeters).isEmpty) add(lat, lng, null);
      }
    }
    return FogRegions._(seeds, buckets);
  }

  List<int> _within(double lat, double lng, double meters) {
    final span = (meters / (_bucketDeg * _mPerLat)).ceil() + 1;
    final baseLat = (lat / _bucketDeg).floor();
    final baseLng = (lng / _bucketDeg).floor();
    final mLng = _mPerLng(lat);
    final out = <int>[];
    for (var i = -span; i <= span; i++) {
      for (var j = -span; j <= span; j++) {
        final list = _buckets[(baseLat + i) * 100000 + (baseLng + j)];
        if (list == null) continue;
        for (final idx in list) {
          final s = seeds[idx];
          final dx = (s.lng - lng) * mLng;
          final dy = (s.lat - lat) * _mPerLat;
          if (dx * dx + dy * dy <= meters * meters) out.add(idx);
        }
      }
    }
    return out;
  }

  /// [lat],[lng] 가 속한 구역의 씨앗. [neighborRangeMeters] 안에 씨앗이 없으면(먼 바다) null.
  FogRegionSeed? nearest(double lat, double lng) {
    final mLng = _mPerLng(lat);
    FogRegionSeed? best;
    var bestD = double.infinity;
    for (final idx in _within(lat, lng, neighborRangeMeters)) {
      final s = seeds[idx];
      final dx = (s.lng - lng) * mLng;
      final dy = (s.lat - lat) * _mPerLat;
      final d = dx * dx + dy * dy;
      if (d < bestD) {
        bestD = d;
        best = s;
      }
    }
    return best;
  }

  /// 스팟 [spotId] 의 씨앗. 좌표가 없어 뺀 스팟이면 null.
  FogRegionSeed? seedOfSpot(int spotId) => _spotIndex[spotId];

  late final Map<int, FogRegionSeed> _spotIndex = {
    for (final s in seeds)
      if (s.spotId != null) s.spotId!: s,
  };

  /// [seed] 의 구역(보로노이 셀) 둘레. 씨앗 중심 ±[cellCapMeters] 상자에서 시작해 이웃마다
  /// 수직이등분선 반평면으로 잘라 낸다(Sutherland–Hodgman). 볼록 다각형이고 씨앗을 품는다.
  ///
  /// 🔴 [refLat] — **맞닿는 두 구역을 같은 자[尺]로 재기 위한 기준 위도**다. 경도 1도의 거리는
  /// 위도에 따라 달라서, 셀마다 «자기 씨앗의 위도»로 환산하면 이웃과 공유하는 변이 서로 다른
  /// 좌표로 계산된다 — 1.5km 떨어진 두 씨앗이면 **20cm 쯤** 어긋나고, 그 틈이 지도에서
  /// **걷힌 구역 사이를 가르는 얇은 안개 선**으로 보인다(사용자 제보, 09-17). 같이 걷는 구역들은
  /// 한 번에 [cellsOf] 로 계산하며, 거기서 공통 기준 위도를 넘긴다.
  List<NLatLng> cell(FogRegionSeed seed, {double? refLat}) {
    final mLng = _mPerLng(refLat ?? seed.lat);
    var poly = <Point<double>>[
      const Point(-cellCapMeters, -cellCapMeters),
      const Point(cellCapMeters, -cellCapMeters),
      const Point(cellCapMeters, cellCapMeters),
      const Point(-cellCapMeters, cellCapMeters),
    ];
    for (final idx in _within(seed.lat, seed.lng, neighborRangeMeters)) {
      if (idx == seed.index) continue;
      final o = seeds[idx];
      final dx = (o.lng - seed.lng) * mLng;
      final dy = (o.lat - seed.lat) * _mPerLat;
      if (dx == 0 && dy == 0) continue; // 같은 좌표의 씨앗 — 반평면이 정의되지 않는다(V11 전 데이터).
      final half = (dx * dx + dy * dy) / 2;
      poly = _clip(poly, dx, dy, half); // p·d <= |d|²/2 인 쪽이 내 구역
      if (poly.length < 3) break;
    }
    return [for (final p in poly) NLatLng(seed.lat + p.y / _mPerLat, seed.lng + p.x / mLng)];
  }

  /// [seeds] 의 구역들 — **좌표가 같은 씨앗은 하나로** 센다. 같은 자리 스팟 둘(인천애뜰·한복사랑,
  /// #222 전 데이터)을 둘 다 인증하면 똑같은 폴리곤이 둘 나오는데, 폴리곤 구멍은 짝홀이라
  /// 같은 구멍 둘은 서로 지워져 **도로 안개가 된다**(실기기, 09-15).
  List<List<NLatLng>> cellsOf(Iterable<FogRegionSeed> seeds) {
    final seen = <String>{};
    final unique = <FogRegionSeed>[];
    for (final seed in seeds) {
      if (!seen.add('${seed.lat},${seed.lng}')) continue;
      unique.add(seed);
    }
    if (unique.isEmpty) return const [];

    // 🔴 한 기준 위도로 다 같이 잰다 — 맞닿는 두 구역의 공유 변이 같은 좌표로 나와야
    // 그 사이에 «얇은 안개 선»이 남지 않는다([cell] 의 refLat 참고). 걷힌 구역들은 대개
    // 한 동네라 평균 위도와의 차이가 작고, 경도 환산 비율이 조금 달라져도 구역 경계가
    // 몇 cm 움직일 뿐이다(구역은 보여주기 위한 경계이고 정복률과 무관하다).
    final refLat = unique.map((s) => s.lat).reduce((a, b) => a + b) / unique.length;

    final rings = <List<NLatLng>>[];
    for (final seed in unique) {
      final ring = cell(seed, refLat: refLat);
      if (ring.length >= 3) rings.add(ring);
    }
    return rings;
  }

  static List<Point<double>> _clip(List<Point<double>> poly, double dx, double dy, double half) {
    final out = <Point<double>>[];
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i];
      final b = poly[(i + 1) % poly.length];
      final fa = a.x * dx + a.y * dy - half;
      final fb = b.x * dx + b.y * dy - half;
      final aIn = fa <= 0;
      final bIn = fb <= 0;
      if (aIn) out.add(a);
      if (aIn != bIn) {
        final t = fa / (fa - fb);
        out.add(Point(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t));
      }
    }
    return out;
  }
}

/// 구역의 씨앗 — 스팟이거나([spotId] 있음) 빈 땅의 가상 점.
class FogRegionSeed {
  const FogRegionSeed({required this.index, required this.lat, required this.lng, this.spotId});

  final int index;
  final double lat;
  final double lng;
  final int? spotId;

  bool get isSpot => spotId != null;
}

/// 땅/바다 마스크 — 시/도 폴리곤을 [cellDeg] 격자에 주사선(scanline)으로 구운 비트맵.
///
/// 점마다 폴리곤 안팎을 재면(point-in-polygon) 후보 18만 개 × 꼭짓점 수만 개라 폰에서
/// 몇 초가 걸린다. 주사선은 꼭짓점 수 × 행 수라 수십 ms 다. 격자 0.005°(≈ 500m)면
/// 해안선이 거칠어도 «바다 한가운데 씨앗»을 거르는 데는 충분하다.
class LandMask {
  LandMask._(this._minRow, this._minCol, this._rows, this._cols, this._bits);

  static const cellDeg = 0.005;

  final int _minRow;
  final int _minCol;
  final int _rows;
  final int _cols;
  final List<bool> _bits;

  static LandMask fromRings(List<List<NLatLng>> rings) {
    var minLat = double.infinity, maxLat = -double.infinity, minLng = double.infinity, maxLng = -double.infinity;
    for (final ring in rings) {
      for (final p in ring) {
        minLat = min(minLat, p.latitude);
        maxLat = max(maxLat, p.latitude);
        minLng = min(minLng, p.longitude);
        maxLng = max(maxLng, p.longitude);
      }
    }
    if (rings.isEmpty) return LandMask._(0, 0, 0, 0, const []);
    final minRow = (minLat / cellDeg).floor();
    final minCol = (minLng / cellDeg).floor();
    final rows = (maxLat / cellDeg).ceil() - minRow + 1;
    final cols = (maxLng / cellDeg).ceil() - minCol + 1;
    final bits = List<bool>.filled(rows * cols, false);

    for (final ring in rings) {
      if (ring.length < 3) continue;
      var rMin = double.infinity, rMax = -double.infinity;
      for (final p in ring) {
        rMin = min(rMin, p.latitude);
        rMax = max(rMax, p.latitude);
      }
      final rowFrom = (rMin / cellDeg).floor();
      final rowTo = (rMax / cellDeg).ceil();
      final xs = <double>[];
      for (var row = rowFrom; row <= rowTo; row++) {
        final y = (row + 0.5) * cellDeg; // 셀 중심 위도
        xs.clear();
        for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
          final a = ring[i];
          final b = ring[j];
          if ((a.latitude > y) != (b.latitude > y)) {
            xs.add(a.longitude + (y - a.latitude) * (b.longitude - a.longitude) / (b.latitude - a.latitude));
          }
        }
        if (xs.length < 2) continue;
        xs.sort();
        // 짝홀 — 교차점 쌍 사이가 안쪽. 시/도 고리는 서로 겹치지 않아 OR 로 합쳐도 된다.
        for (var k = 0; k + 1 < xs.length; k += 2) {
          final colFrom = max((xs[k] / cellDeg).floor(), minCol);
          final colTo = min((xs[k + 1] / cellDeg).floor(), minCol + cols - 1);
          final base = (row - minRow) * cols - minCol;
          for (var col = colFrom; col <= colTo; col++) {
            bits[base + col] = true;
          }
        }
      }
    }
    return LandMask._(minRow, minCol, rows, cols, bits);
  }

  bool contains(double lat, double lng) {
    final r = (lat / cellDeg).floor() - _minRow;
    final c = (lng / cellDeg).floor() - _minCol;
    if (r < 0 || c < 0 || r >= _rows || c >= _cols) return false;
    return _bits[r * _cols + c];
  }
}
