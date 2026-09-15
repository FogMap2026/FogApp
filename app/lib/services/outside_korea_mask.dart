import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import 'fog_overlay_controller.dart';

/// 대한민국 밖을 바다색으로 덮는다 — 북한·일본·중국 땅이 지도에 안 보이게(시진, 09-15).
///
/// FogApp 은 국내 탐험 앱이라 이웃 나라 땅은 «갈 수 없는 곳»인데 기본 지도엔 그대로 그려져
/// 안개 밖의 땅처럼 보인다. 지도 범위([_mapExtent]) 전체를 덮는 폴리곤에 시/도 고리(안개·경계선과
/// 같은 `kr_provinces.json`)를 구멍으로 내면, 짝홀 채움으로 **우리 땅만 뚫리고 나머지는 바다색**이
/// 된다 — 섬 하나하나가 구멍이라 그대로 보인다.
///
/// 바다색은 커스텀 스타일의 바다와 같은 값이다(실기기 캡처에서 뽑음). 스타일에서 바다색을 바꾸면
/// 여기도 맞춰야 한다 — 어긋나면 해안선 바깥으로 색 경계가 보인다.
class OutsideKoreaMask {
  OutsideKoreaMask._(this._mapController, this._overlay);

  final NaverMapController _mapController;
  final NPolygonOverlay _overlay;

  /// 커스텀 스타일(`650c32b2-…`)의 바다색.
  static const seaColor = Color(0xFF67BEFF);

  /// 안개(구역 구멍)·시/도 경계선보다 아래, 지도 타일보다 위.
  static const _globalZIndex = -200000;

  /// 지도 범위보다 넉넉하게 — 카메라 extent 가장자리에서 덮개가 끝나 보이지 않게.
  /// 폴리곤 고리는 닫혀 있어야 한다(SDK 단언: 첫 점 == 끝 점).
  static const _cover = [
    NLatLng(29.0, 120.0),
    NLatLng(29.0, 136.0),
    NLatLng(42.0, 136.0),
    NLatLng(42.0, 120.0),
    NLatLng(29.0, 120.0),
  ];

  static Future<OutsideKoreaMask> attach(NaverMapController mapController) async {
    final rings = await FogOverlayController.loadProvinceRings();
    final overlay = NPolygonOverlay(
      id: 'outside-korea-mask',
      coords: _cover,
      holes: [
        for (final ring in outermostRings(rings)) ring.first == ring.last ? ring : [...ring, ring.first],
      ],
      color: seaColor,
    )..setGlobalZIndex(_globalZIndex);
    await mapController.addOverlay(overlay);
    return OutsideKoreaMask._(mapController, overlay);
  }

  /// 다른 고리 «안»에 든 고리(광주 ⊂ 전남, 대구 ⊂ 경북 같은 내륙 시)는 뺀다. 구멍은 짝홀이라
  /// 구멍 안의 구멍은 도로 채워져 **광주에 바다색 구멍**이 났다(실기기, 09-15). 바깥 고리의
  /// 구멍이 그 땅을 이미 덮으니 안쪽 고리는 필요 없다.
  static List<List<NLatLng>> outermostRings(List<List<NLatLng>> rings) {
    final out = <List<NLatLng>>[];
    for (var i = 0; i < rings.length; i++) {
      final ring = rings[i];
      if (ring.length < 3) continue;
      var nested = false;
      for (var j = 0; j < rings.length && !nested; j++) {
        if (i == j || rings[j].length < 3) continue;
        // 첫 점 하나로 판정한다 — 시/도 고리는 서로 겹치지 않아 한 점이 안이면 전부 안이다.
        nested = FogGrid.pointInRing(ring.first, rings[j]);
      }
      if (!nested) out.add(ring);
    }
    return out;
  }

  void dispose() {
    _mapController.deleteOverlay(_overlay.info);
  }
}
