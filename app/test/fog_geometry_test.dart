// 안개 세 겹의 기하 — 짙은 안개 · 내 시야(40m 반투명) · 걷힌 자리(궤적 15m, 스팟 50m).
//
// 지도 컨트롤러가 필요한 `FogOverlayController` 대신 고리 계산만 떼어 검증한다 —
// `fog_trail_key_test.dart` 와 같은 이유다.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogapp/services/fog_overlay_controller.dart';

const _metersPerDegreeLat = 111320.0;

NLatLng _moved(NLatLng from, {double northMeters = 0, double eastMeters = 0}) => NLatLng(
      from.latitude + northMeters / _metersPerDegreeLat,
      from.longitude + eastMeters / (_metersPerDegreeLat * cos(from.latitude * pi / 180)),
    );

double _distance(NLatLng a, NLatLng b) {
  final dy = (a.latitude - b.latitude) * _metersPerDegreeLat;
  final dx = (a.longitude - b.longitude) * _metersPerDegreeLat * cos(a.latitude * pi / 180);
  return sqrt(dx * dx + dy * dy);
}

/// (x=경도, y=위도) 평면의 부호 있는 넓이 — 양수면 반시계.
double _signedArea(List<NLatLng> ring) {
  var area = 0.0;
  for (var i = 0; i < ring.length - 1; i++) {
    area += ring[i].longitude * ring[i + 1].latitude - ring[i + 1].longitude * ring[i].latitude;
  }
  return area / 2;
}

void main() {
  const seoul = NLatLng(37.5665, 126.9780);
  const vision = FogOverlayController.visionRadiusMeters;

  group('반경 — 요청한 값 그대로', () {
    test('내 시야 40m · 걸어온 자리 15m · 스팟 인증 50m', () {
      expect(FogOverlayController.visionRadiusMeters, 40);
      expect(FogOverlayController.trailRadiusMeters, 15);
      expect(FogOverlayController.spotClearRadiusMeters, 50);
    });
  });

  group('안개 색', () {
    test('짙은 안개는 예전 전역 안개와 같은 85% 반투명이다 — 아래 지도가 은은히 비친다', () {
      expect(FogOverlayController.fogColor, const Color(0xD948566B));
    });

    test('내 시야는 짙은 안개보다 옅다 — «곁은 확실히 더 잘 보인다»', () {
      expect(FogOverlayController.visionFogColor.alpha, lessThan(FogOverlayController.fogColor.alpha));
    });

    test('짙은 안개는 지명 라벨 위, 마커(200000)·내 위치(300000) 아래에 그린다', () {
      // 음수면 네이버 지도 심벌 아래라 불투명 안개 위로 지명이 뜬다.
      expect(FogOverlayController.fogGlobalZIndex, greaterThanOrEqualTo(0));
      expect(FogOverlayController.fogGlobalZIndex, lessThan(200000));
    });
  });

  group('원 고리', () {
    test('바깥 고리는 시계, 구멍은 반시계 — 방향이 같으면 구멍이 안 뚫린다', () {
      final outer = fogCircleRing(seoul, vision, 48);
      final hole = fogHoleRing(seoul, vision, 48);
      expect(_signedArea(outer), lessThan(0));
      expect(_signedArea(hole), greaterThan(0));
      expect(outer.first, outer.last);
      expect(hole.first, hole.last);
    });

    test('꼭짓점이 전부 반경 위에 있다 — 위도에 따른 경도 보정', () {
      for (final p in fogCircleRing(seoul, 50, 48)) {
        expect(_distance(seoul, p), closeTo(50, 0.05));
      }
    });
  });

  group('시야에 걷힌 자리 옮겨 뚫기', () {
    test('시야 한가운데 궤적은 모양 그대로 들어간다', () {
      final trail = fogHoleRing(_moved(seoul, eastMeters: 5), 15, 12);
      final clipped = clipFogHoleToCircle(trail, seoul, vision)!;
      expect(clipped.length, trail.length);
      expect(_signedArea(clipped), closeTo(_signedArea(trail), _signedArea(trail).abs() * 1e-6));
    });

    test('시야에 걸친 궤적은 시야 안쪽으로 잘린다 — 바깥 고리를 삐져나가지 않는다', () {
      final trail = fogHoleRing(_moved(seoul, northMeters: 38), 15, 12);
      final clipped = clipFogHoleToCircle(trail, seoul, vision)!;
      for (final p in clipped) {
        // 48각형 바깥 고리의 가장 안쪽(변 중점)은 반경의 cos(π/48) 지점이다.
        expect(_distance(seoul, p), lessThan(vision * cos(pi / 48)));
      }
      expect(_signedArea(clipped), greaterThan(0), reason: '잘려도 구멍 방향(반시계)이어야 한다');
    });

    test('시야 밖 궤적은 없다', () {
      final trail = fogHoleRing(_moved(seoul, eastMeters: 80), 15, 12);
      expect(clipFogHoleToCircle(trail, seoul, vision), isNull);
    });

    test('인증한 스팟 한가운데 서 있으면 시야 전체가 걷힌다(50m > 40m)', () {
      final spot = fogHoleRing(seoul, FogOverlayController.spotClearRadiusMeters, 48);
      final clipped = clipFogHoleToCircle(spot, seoul, vision)!;
      final visionArea = _signedArea(fogHoleRing(seoul, vision, 48));
      expect(_signedArea(clipped), closeTo(visionArea * 0.97 * 0.97, visionArea * 0.01));
    });

    test('방향이 거꾸로 들어와도 구멍 방향으로 돌려준다', () {
      final wrongWay = fogCircleRing(_moved(seoul, eastMeters: 10), 15, 12);
      final clipped = clipFogHoleToCircle(wrongWay, seoul, vision)!;
      expect(_signedArea(clipped), greaterThan(0));
    });
  });
}
