import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

/// 내 위치를 기본 점 대신 **캐릭터**로 그린다(#131 6-1).
///
/// SDK 의 위치 오버레이([NLocationOverlay])는 지도마다 하나뿐이고 직접 만들지 않는다 —
/// `controller.getLocationOverlay()` 로 가져와 아이콘만 갈아끼운다. 별도 마커를 띄우면
/// 내 위치가 둘로 보이고, SDK 가 이미 하고 있는 위치·방향 갱신을 다시 구현하게 된다.
///
/// **방향은 SDK 가 돌려준다.** [NMyLocationTracker.onHeadingChanged] 의 기본 구현이
/// `locationOverlay.setBearing(heading)` 을 호출하고, heading 은 [FogLocationTracker] 가
/// 나침반(`flutter_compass`)에서 흘려보낸다. 그래서 아이콘은 **항상 북쪽(위)을 향해**
/// 그리면 되고, 회전은 신경 쓰지 않는다.
///
/// 지도에 이미 핀(스팟)·마름모(발자취 #117)·폴리곤(안개)이 있어, 캐릭터는 **원 + 방향
/// 삼각형**으로 그려 형태가 겹치지 않게 한다.
class CharacterOverlay {
  const CharacterOverlay._();

  /// 아이콘 크기(dp). 미터가 아니라 화면 기준이라 줌과 무관하게 일정하다 —
  /// 발자취 도형에서 겪은 문제(PR #130 리뷰)를 처음부터 피한다.
  static const iconSize = Size(44, 44);

  /// 캐릭터 아이콘을 굽는다. 위치 오버레이는 하나뿐이라 한 번만 만들면 된다.
  static Future<NOverlayImage> createIcon(BuildContext context) {
    return NOverlayImage.fromWidget(
      context: context,
      size: iconSize,
      widget: const _CharacterMarker(),
    );
  }

  /// 지도의 위치 오버레이 아이콘을 캐릭터로 바꾼다.
  static void attach(NaverMapController controller, NOverlayImage icon) {
    controller.getLocationOverlay()
      ..setIcon(icon)
      ..setIconSize(iconSize);
  }
}

class _CharacterMarker extends StatelessWidget {
  const _CharacterMarker();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      size: CharacterOverlay.iconSize,
      painter: _CharacterPainter(),
    );
  }
}

/// 원(몸통) 위에 방향 삼각형을 얹은 캐릭터.
///
/// 안개(`FogOverlayController.fogColor`, 짙은 청회색) 위에 올라가므로 **흰 테두리를
/// 도형 뒤에 두껍게 깔아** 윤곽이 묻히지 않게 한다.
class _CharacterPainter extends CustomPainter {
  const _CharacterPainter();

  /// 스팟의 숨김 톤(짙은 청회색)·발자취의 금색과 뚜렷이 구분되는 파랑.
  static const _fillColor = Color(0xFF3D8BFD);
  static const _outlineColor = Colors.white;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final center = Offset(width / 2, height * 0.62);
    final radius = width * 0.2;

    // 위(북쪽)를 향한 삼각형 — 회전은 SDK 가 bearing 으로 처리한다.
    final arrow = Path()
      ..moveTo(width / 2, height * 0.1)
      ..lineTo(width * 0.72, height * 0.46)
      ..lineTo(width * 0.28, height * 0.46)
      ..close();

    final outline = Paint()
      ..color = _outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(arrow, outline);
    canvas.drawCircle(center, radius, outline);

    final fill = Paint()..color = _fillColor;
    canvas.drawPath(arrow, fill);
    canvas.drawCircle(center, radius, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
