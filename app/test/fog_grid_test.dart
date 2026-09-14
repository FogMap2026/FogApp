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
}
