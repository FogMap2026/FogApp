// 걷힌 자리의 «격자 합집합» — 겹치는 원이 구멍의 구멍이 되지 않는지.
//
// 지도 컨트롤러 없이 `FogGrid` 만 검증한다 — `fogTrailKey` 와 같은 이유다.
import 'dart:math';

import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogapp/services/fog_overlay_controller.dart';

const _metersPerDegreeLat = 111320.0;

NLatLng _moved(NLatLng from, {double north = 0, double east = 0}) => NLatLng(
      from.latitude + north / _metersPerDegreeLat,
      from.longitude + east / (_metersPerDegreeLat * 0.7934), // cos(37.5°)
    );

Map<int, int> _union(Iterable<List<int>> circles) {
  final cells = <int, int>{};
  for (final circle in circles) {
    for (final cell in circle) {
      cells.update(cell, (n) => n + 1, ifAbsent: () => 1);
    }
  }
  return cells;
}

/// 신발끈 공식(도 단위) — 양수면 반시계.
double _signedArea(List<NLatLng> ring) {
  var area = 0.0;
  for (var i = 0; i < ring.length - 1; i++) {
    area += ring[i].longitude * ring[i + 1].latitude - ring[i + 1].longitude * ring[i].latitude;
  }
  return area;
}

void main() {
  const seoul = NLatLng(37.5665, 126.9780);

  test('원 하나는 반경만큼 셀을 덮는다 — 넓이 오차 5% 안', () {
    final cells = FogGrid.cellsInCircle(seoul, 50);
    const expected = pi * 50 * 50 / (FogGrid.cellMeters * FogGrid.cellMeters);
    expect(cells.length, closeTo(expected, expected * 0.05));
  });

  test('겹치는 두 원은 «구멍 하나»다 — 겹친 자리가 도로 안개가 되지 않는다', () {
    // 15m 떨어진 50m 원 둘 — 걷는 동안 늘 생기는 모양이다.
    final a = FogGrid.cellsInCircle(seoul, 50);
    final b = FogGrid.cellsInCircle(_moved(seoul, north: 15), 50);
    final outlines = FogGrid.outlines(_union([a, b]));

    expect(outlines.holes, hasLength(1));
    expect(outlines.islands, isEmpty);
    // 합집합이니 두 원의 셀 수보다 적고, 한 원보다는 많다.
    final union = {...a, ...b};
    expect(union.length, lessThan(a.length + b.length));
    expect(union.length, greaterThan(a.length));
  });

  test('떨어진 두 원은 구멍 둘이다', () {
    final a = FogGrid.cellsInCircle(seoul, 50);
    final b = FogGrid.cellsInCircle(_moved(seoul, north: 300), 50);
    final outlines = FogGrid.outlines(_union([a, b]));
    expect(outlines.holes, hasLength(2));
    expect(outlines.islands, isEmpty);
  });

  test('구멍은 반시계 — 바깥 고리(시계)와 반대여야 구멍이다', () {
    final outlines = FogGrid.outlines(_union([FogGrid.cellsInCircle(seoul, 50)]));
    final ring = outlines.holes.single;
    expect(ring.first.latitude, ring.last.latitude, reason: '닫힌 고리');
    expect(ring.first.longitude, ring.last.longitude);
    expect(_signedArea(ring), greaterThan(0));
  });

  test('고리를 이루면 안쪽은 «섬»으로 남는다 — 블록을 한 바퀴 돌아도 블록 안은 안개', () {
    // 반경 200m 원 둘레를 30m 간격으로 도는 50m 원들 — 폭 100m 띠, 안쪽 지름 300m 는 안개.
    final circles = <List<int>>[];
    for (var deg = 0; deg < 360; deg += 8) {
      final rad = deg * pi / 180;
      // 200m 원 위의 점. 이웃 점 간격 ≈ 28m < 반경 50m 이라 띠가 끊기지 않는다.
      final center = _moved(seoul, north: 200 * cos(rad), east: 200 * sin(rad));
      circles.add(FogGrid.cellsInCircle(center, 50));
    }
    final outlines = FogGrid.outlines(_union(circles));
    expect(outlines.holes, hasLength(1), reason: '띠의 바깥 둘레');
    expect(outlines.islands, hasLength(1), reason: '띠 안쪽에 남은 안개');
    expect(_signedArea(outlines.islands.single), lessThan(0), reason: '섬은 시계 방향');
  });

  test('직선 구간의 꼭짓점은 지워진다 — 한 변에 점이 둘뿐이다', () {
    // 원 하나의 둘레: 계단이라도 같은 방향으로 이어지는 변은 하나로 합쳐진다.
    final ring = FogGrid.outlines(_union([FogGrid.cellsInCircle(seoul, 50)])).holes.single;
    for (var i = 1; i < ring.length - 1; i++) {
      final dLat1 = ring[i].latitude - ring[i - 1].latitude;
      final dLng1 = ring[i].longitude - ring[i - 1].longitude;
      final dLat2 = ring[i + 1].latitude - ring[i].latitude;
      final dLng2 = ring[i + 1].longitude - ring[i].longitude;
      final sameDirection = (dLat1 - dLat2).abs() < 1e-12 && (dLng1 - dLng2).abs() < 1e-12;
      expect(sameDirection, isFalse, reason: '꼭짓점 $i 가 직선 위에 있다');
    }
  });

  _smoothTests();
  _clipTests();
}

void _smoothTests() {
  const seoul = NLatLng(37.5665, 126.9780);

  test('다듬어도 닫힌 고리이고 방향(반시계)이 그대로다', () {
    final ring = FogGrid.outlines(_union([FogGrid.cellsInCircle(seoul, 50)])).holes.single;
    expect(ring.first.latitude, ring.last.latitude);
    expect(ring.first.longitude, ring.last.longitude);
    expect(_signedArea(ring), greaterThan(0));
  });

  test('다듬으면 계단이 사라진다 — 축 방향(가로·세로)만 있던 변이 대각선이 된다', () {
    final ring = FogGrid.outlines(_union([FogGrid.cellsInCircle(seoul, 50)])).holes.single;
    var diagonal = 0;
    for (var i = 0; i < ring.length - 1; i++) {
      final dLat = (ring[i + 1].latitude - ring[i].latitude).abs();
      final dLng = (ring[i + 1].longitude - ring[i].longitude).abs();
      if (dLat > 1e-9 && dLng > 1e-9) diagonal++;
    }
    // 격자 그대로면 대각선 변이 0 이다.
    expect(diagonal, greaterThan((ring.length - 1) ~/ 2));
  });
}

void _clipTests() {
  group('clipByConvex — 구역 셀을 땅에 맞춰 자른다', () {
    // 땅: 위도 0~1, 경도 0~1 정사각형(오목하게 오른쪽 위 모서리를 파낸 L 자).
    const land = [
      NLatLng(0, 0),
      NLatLng(0, 1),
      NLatLng(0.5, 1),
      NLatLng(0.5, 0.5),
      NLatLng(1, 0.5),
      NLatLng(1, 0),
    ];

    test('땅 안에 온전히 든 셀은 그대로다', () {
      const cell = [NLatLng(0.1, 0.1), NLatLng(0.1, 0.4), NLatLng(0.4, 0.4), NLatLng(0.4, 0.1)];
      final out = FogGrid.clipByConvex(land, cell);
      expect(out.length, 4);
      for (final p in out) {
        expect(p.latitude, closeTo(0.25, 0.15 + 1e-9));
        expect(p.longitude, closeTo(0.25, 0.15 + 1e-9));
      }
    });

    test('바다로 삐져나온 셀은 해안선에서 잘린다 — 바다 쪽 꼭짓점이 남지 않는다', () {
      // 위도 0.8~1.2 × 경도 0.2~0.4: 절반이 땅 밖(위도 > 1).
      const cell = [NLatLng(0.8, 0.2), NLatLng(0.8, 0.4), NLatLng(1.2, 0.4), NLatLng(1.2, 0.2)];
      final out = FogGrid.clipByConvex(land, cell);
      expect(out.length, greaterThanOrEqualTo(3));
      for (final p in out) {
        expect(p.latitude, lessThanOrEqualTo(1.0 + 1e-9));
        expect(p.latitude, greaterThanOrEqualTo(0.8 - 1e-9));
      }
    });

    test('파인 자리(오목한 곳)에 걸친 셀은 파인 부분이 빠진다', () {
      // 위도 0.4~0.9 × 경도 0.4~0.9: 오른쪽 위(위도>0.5, 경도>0.5)는 바다.
      const cell = [NLatLng(0.4, 0.4), NLatLng(0.4, 0.9), NLatLng(0.9, 0.9), NLatLng(0.9, 0.4)];
      final out = FogGrid.clipByConvex(land, cell);
      expect(FogGrid.pointInRing(const NLatLng(0.45, 0.45), out), isTrue);
      expect(FogGrid.pointInRing(const NLatLng(0.8, 0.8), out), isFalse); // 바다
      expect(FogGrid.pointInRing(const NLatLng(0.45, 0.8), out), isTrue); // 땅(아래 팔)
    });

    test('완전히 바다인 셀은 비어 있다', () {
      const cell = [NLatLng(2, 2), NLatLng(2, 3), NLatLng(3, 3), NLatLng(3, 2)];
      expect(FogGrid.clipByConvex(land, cell), isEmpty);
    });

    test('시계 방향 셀도 같은 결과다', () {
      const ccw = [NLatLng(0.1, 0.1), NLatLng(0.1, 0.4), NLatLng(0.4, 0.4), NLatLng(0.4, 0.1)];
      final cw = ccw.reversed.toList();
      expect(FogGrid.clipByConvex(land, cw).length, FogGrid.clipByConvex(land, ccw).length);
    });
  });
}
