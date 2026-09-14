import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_naver_map/flutter_naver_map.dart';

/// 지도 위 시/도 경계선 — 탐험 현황의 단계구분도([KoreaChoroplethMap])와 **같은 경계**
/// (통계청 2013 시/도, `assets/geo/kr_provinces.json`)를 안개 위에 얇은 선으로 올린다.
/// 배지 단위가 시/도라, 지도에서도 「지금 어느 배지 안에 있나」가 보여야 둘이 이어진다
/// (시진, 09-14).
///
/// 선은 안개 폴리곤(기본 z -200000) 위, 지명·마커 아래(-100000)에 둔다 — 안개에 묻히지도,
/// 글자를 가리지도 않게. 색은 흰 60%: 안개(청회색) 위에서 보이되 걷힌 자리(밝은 지도)
/// 위에서는 옅게 물러난다.
class ProvinceBoundaryOverlay {
  ProvinceBoundaryOverlay._(this._mapController, this._lines);

  static const _assetPath = 'assets/geo/kr_provinces.json';
  static const _lineColor = Color(0x99FFFFFF);
  static const _lineWidth = 1.5;
  static const _globalZIndex = -100000;

  final NaverMapController _mapController;
  final List<NPolylineOverlay> _lines;

  /// 지도가 준비된 뒤 호출한다. 시/도별·고리별 폴리라인을 한 번에 올린다(17개 시/도, 고리
  /// 수십 개, 좌표 3,600개 남짓 — 한 번 올리면 카메라와 무관하게 SDK 가 그린다).
  static Future<ProvinceBoundaryOverlay> attach(NaverMapController mapController) async {
    final raw = await rootBundle.loadString(_assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final lines = <NPolylineOverlay>[];
    var i = 0;
    for (final p in json['provinces'] as List) {
      for (final ring in p['rings'] as List) {
        final coords = [for (final c in ring as List) NLatLng((c[0] as num).toDouble(), (c[1] as num).toDouble())];
        if (coords.length < 2) continue;
        lines.add(
          NPolylineOverlay(id: 'province-boundary-${i++}', coords: coords, color: _lineColor, width: _lineWidth)
            ..setGlobalZIndex(_globalZIndex),
        );
      }
    }
    await mapController.addOverlayAll(lines.toSet());
    return ProvinceBoundaryOverlay._(mapController, lines);
  }

  void dispose() {
    for (final line in _lines) {
      _mapController.deleteOverlay(line.info);
    }
  }
}
