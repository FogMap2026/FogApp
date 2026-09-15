import 'dart:math';

import 'package:flutter/material.dart';

/// 지도 핀(마커) 공통 그림 — 스팟·발자취가 같은 실루엣을 쓴다.
///
/// 네이버 기본 마커(초록 핀에 흰 역삼각형)를 쓰다가 직접 그린다(시진, 09-15): 흰 외곽선을 따고
/// 안쪽은 삼각형 대신 **원**을, 발자취는 **사람 발자국**을 넣는다. 둥근 머리 + 아래로 뾰족한
/// 꼬리는 기본 마커와 같은 비율(38×50dp)이라 자리·크기 감각은 그대로다.
class MapPin extends StatelessWidget {
  const MapPin({required this.color, required this.child, super.key});

  /// 기본 핀과 같은 크기.
  static const size = Size(38, 50);

  final Color color;

  /// 머리 원 안에 놓이는 그림(흰 원, 발자국 등).
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: size,
      painter: PinPainter(color),
      child: Padding(
        padding: const EdgeInsets.only(top: PinPainter.headTop),
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox.square(dimension: PinPainter.headDiameter, child: child),
        ),
      ),
    );
  }
}

/// 핀 몸통 — 머리(원)와 꼬리(접점 두 개 + 끝점 삼각형)의 합집합. 흰 테두리·옅은 그림자.
///
/// 호 각도를 손으로 맞추다 반이 잘린 모양이 나온 적이 있어(실기기, 09-15) 합집합으로 그린다 —
/// 각도 계산이 필요 없다.
class PinPainter extends CustomPainter {
  const PinPainter(this.color);

  final Color color;

  /// 머리 원의 지름·윗변 — [MapPin.size] 기준. 자식 그림이 이 원 안에 들어가게.
  static const headDiameter = 38 * 0.84;
  static const headTop = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    const r = headDiameter / 2;
    final cx = size.width / 2;
    const cy = headTop + r;
    final tipY = size.height - 1.5;
    final d = tipY - cy;
    final a = acos(r / d); // 중심에서 본 접점의 벌어진 각(아래 방향 기준)
    final head = Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    final tail = Path()
      ..moveTo(cx, tipY)
      ..lineTo(cx + r * sin(a), cy + r * cos(a))
      ..lineTo(cx, cy)
      ..lineTo(cx - r * sin(a), cy + r * cos(a))
      ..close();
    final path = Path.combine(PathOperation.union, head, tail);
    canvas.drawShadow(path, const Color(0x66000000), 2, false);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(PinPainter old) => old.color != color;
}

/// 스팟 핀 안의 흰 원 — 기본 마커의 역삼각형 자리.
class PinDot extends StatelessWidget {
  const PinDot({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: SizedBox.square(dimension: 12),
      ),
    );
  }
}

/// 사람 발자국 — 발바닥 윤곽선(안쪽 아치가 들어간 오른발) + 발가락 다섯 개. 핀 안(흰색)과
/// 컨트롤 버튼(아이콘색) 양쪽에서 같은 그림을 쓴다(시진, 09-15 참고 이미지).
class HumanFootprint extends StatelessWidget {
  const HumanFootprint({this.color = Colors.white, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _HumanFootprintPainter(color));
  }
}

class _HumanFootprintPainter extends CustomPainter {
  const _HumanFootprintPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final cx = size.width / 2;
    Offset p(double x, double y) => Offset(cx + x * h, y * h);
    // 발바닥 윤곽 — 앞볼 위를 왼쪽에서 오른쪽으로, 안쪽(오른쪽) 아치를 파고, 발꿈치를 돌아 바깥
    // (왼쪽)으로 올라온다. 좌표는 높이 기준 비율.
    final sole = Path()
      ..moveTo(p(-0.22, 0.34).dx, p(-0.22, 0.34).dy)
      ..cubicTo(
        p(-0.20, 0.18).dx,
        p(-0.20, 0.18).dy,
        p(0.26, 0.16).dx,
        p(0.26, 0.16).dy,
        p(0.25, 0.40).dx,
        p(0.25, 0.40).dy,
      )
      ..cubicTo(
        p(0.24, 0.52).dx,
        p(0.24, 0.52).dy,
        p(0.06, 0.56).dx,
        p(0.06, 0.56).dy,
        p(0.08, 0.66).dx,
        p(0.08, 0.66).dy,
      )
      ..cubicTo(
        p(0.10, 0.74).dx,
        p(0.10, 0.74).dy,
        p(0.18, 0.78).dx,
        p(0.18, 0.78).dy,
        p(0.15, 0.88).dx,
        p(0.15, 0.88).dy,
      )
      ..cubicTo(
        p(0.10, 0.98).dx,
        p(0.10, 0.98).dy,
        p(-0.14, 0.98).dx,
        p(-0.14, 0.98).dy,
        p(-0.16, 0.84).dx,
        p(-0.16, 0.84).dy,
      )
      ..cubicTo(
        p(-0.19, 0.70).dx,
        p(-0.19, 0.70).dy,
        p(-0.27, 0.50).dx,
        p(-0.27, 0.50).dy,
        p(-0.22, 0.34).dx,
        p(-0.22, 0.34).dy,
      )
      ..close();
    canvas.drawPath(
      sole,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.08
        ..strokeJoin = StrokeJoin.round,
    );
    // 발가락: 엄지(오른쪽 위)가 크고 새끼로 갈수록 작아지며 아래로 내려간다.
    final fill = Paint()..color = color;
    const toes = <(double x, double y, double rx, double ry)>[
      (0.20, 0.10, 0.055, 0.07),
      (0.06, 0.07, 0.045, 0.055),
      (-0.06, 0.10, 0.040, 0.050),
      (-0.15, 0.16, 0.035, 0.045),
      (-0.23, 0.24, 0.030, 0.040),
    ];
    for (final (x, y, rx, ry) in toes) {
      canvas.drawOval(Rect.fromCenter(center: p(x, y), width: 2 * rx * h, height: 2 * ry * h), fill);
    }
  }

  @override
  bool shouldRepaint(_HumanFootprintPainter old) => old.color != color;
}
