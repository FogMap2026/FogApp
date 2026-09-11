import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../models/nearby_traveler.dart';

/// 지도 위에 익명 여행자를 표시한다(#133).
///
/// **스팟(핀)·발자취(마름모)·내 캐릭터(파란 원+삼각형)와 겹치지 않는 형태**로
/// 옅은 보라색 원을 쓴다 — "저 여행자"라는 존재감만 전달하고 방향·신원 같은
/// 정보는 담지 않는다(애초에 서버가 안 준다).
///
/// [refresh]가 매번 마커 전체를 새로 그린다 — 30분 텀인 정보라 자주 갱신되지
/// 않고, 개수도 스팟 근처로 제한돼 있어([TravelerService.fetchNearby]의
/// `radiusMeters`) [FootprintMarkerController]처럼 증분 갱신을 할 만큼 잦지 않다.
class TravelerMarkerController {
  TravelerMarkerController(
    this._mapController, {
    required NOverlayImage icon,
    this.onTapped,
  }) : _icon = icon;

  final NaverMapController _mapController;
  final NOverlayImage _icon;

  /// 마커를 탭했을 때 호출된다 — "N분 전" 같은 안내를 보여주는 진입점.
  final void Function(NearbyTraveler traveler)? onTapped;

  /// 아이콘 크기(dp) — 내 캐릭터([CharacterOverlay])보다 한 단계 작게 두어
  /// "나"와 "저 여행자"가 한눈에 구분되게 한다.
  static const iconSize = Size(32, 32);

  static Future<NOverlayImage> createIcon(BuildContext context) {
    return NOverlayImage.fromWidget(
      context: context,
      size: iconSize,
      widget: const _AnonymousTravelerDot(),
    );
  }

  final List<NMarker> _markers = [];

  /// 지금 떠 있는 마커를 전부 지우고 [travelers]로 다시 그린다.
  Future<void> refresh(List<NearbyTraveler> travelers) async {
    for (final marker in _markers) {
      await _mapController.deleteOverlay(marker.info);
    }
    _markers.clear();

    for (final traveler in travelers) {
      final marker = NMarker(
        id: 'traveler-spot-${traveler.spotId}',
        position: NLatLng(traveler.lat, traveler.lng),
        icon: _icon,
        size: iconSize,
        // 핀이 아니라 원형 도형이라 좌표에 정중앙을 맞춘다(기본값은 핀 끝 기준) —
        // FootprintMarkerController와 같은 이유.
        anchor: const NPoint(0.5, 0.5),
      );
      final callback = onTapped;
      if (callback != null) {
        marker.setOnTapListener((_) => callback(traveler));
      }
      _markers.add(marker);
    }
    if (_markers.isNotEmpty) {
      await _mapController.addOverlayAll(_markers.toSet());
    }
  }

  /// 지도를 벗어날 때 다 치운다.
  Future<void> clear() async {
    for (final marker in _markers) {
      await _mapController.deleteOverlay(marker.info);
    }
    _markers.clear();
  }
}

class _AnonymousTravelerDot extends StatelessWidget {
  const _AnonymousTravelerDot();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      size: TravelerMarkerController.iconSize,
      painter: _DotPainter(),
    );
  }
}

/// 옅은 보라색 원 + 흰 테두리. 안개(짙은 청회색) 위에서도 윤곽이 보이도록
/// 발자취·내 캐릭터와 같은 원칙(흰 테두리 먼저)을 쓴다.
class _DotPainter extends CustomPainter {
  const _DotPainter();

  static const _fillColor = Color(0xFF9575CD);
  static const _outlineColor = Colors.white;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.32;

    final outline = Paint()
      ..color = _outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, outline);

    final fill = Paint()..color = _fillColor;
    canvas.drawCircle(center, radius, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
