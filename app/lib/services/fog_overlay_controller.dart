import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_naver_map/flutter_naver_map.dart';

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

  /// [spotId] 위치의 반경 [radiusMeters] 안 안개를 걷어낸다(방문 인증 시 호출 예정).
  ///
  /// [center]를 포함하는 landmass 폴리곤을 찾아 그 폴리곤에만 구멍을 낸다.
  /// 어떤 landmass에도 속하지 않으면(예: 좌표 오차로 해안선 바로 바깥) 아무 일도 하지 않는다.
  void clearCircle(String spotId, NLatLng center, {double radiusMeters = 150, int segments = 48}) {
    final landmass = _landmasses.firstWhere(
      (l) => l._containsPoint(center),
      orElse: () => _nearestLandmass(center),
    );
    landmass.clearCircle(spotId, center, radiusMeters: radiusMeters, segments: segments);
  }

  /// 다시 안개로 덮는다(주로 테스트/디버그용).
  void reFog(String spotId) {
    for (final landmass in _landmasses) {
      landmass.reFog(spotId);
    }
  }

  void dispose() {
    for (final landmass in _landmasses) {
      _mapController.deleteOverlay(landmass.overlay.info);
    }
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

  void clearCircle(String spotId, NLatLng center, {required double radiusMeters, required int segments}) {
    _clearedHoles[spotId] = _circleRing(center, radiusMeters, segments);
    overlay.setHoles(_clearedHoles.values);
  }

  void reFog(String spotId) {
    if (_clearedHoles.remove(spotId) != null) {
      overlay.setHoles(_clearedHoles.values);
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
