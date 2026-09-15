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

/// 사람 발자국 — 발바닥(길쭉한 타원, 발꿈치 쪽이 좁다) + 발가락 다섯 개. 흰색.
class HumanFootprint extends StatelessWidget {
  const HumanFootprint({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _HumanFootprintPainter());
  }
}

class _HumanFootprintPainter extends CustomPainter {
  const _HumanFootprintPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final cx = size.width / 2;
    final h = size.height;
    // 발바닥: 앞볼이 넓고 발꿈치가 좁은 모양 — 위쪽 타원(앞볼)과 아래쪽 작은 타원(발꿈치)을
    // 잇는 둥근 사다리꼴로 그린다.
    final sole = Path()
      ..moveTo(cx - h * 0.17, h * 0.36)
      ..quadraticBezierTo(cx - h * 0.20, h * 0.60, cx - h * 0.10, h * 0.82)
      ..quadraticBezierTo(cx, h * 0.92, cx + h * 0.10, h * 0.82)
      ..quadraticBezierTo(cx + h * 0.20, h * 0.60, cx + h * 0.17, h * 0.36)
      ..quadraticBezierTo(cx, h * 0.28, cx - h * 0.17, h * 0.36)
      ..close();
    canvas.drawPath(sole, paint);
    // 발가락: 엄지가 크고 새끼로 갈수록 작아지며 살짝 아래로 내려간다.
    const toes = <(double dx, double dy, double r)>[
      (-0.13, 0.20, 0.060), // 엄지
      (-0.04, 0.16, 0.045),
      (0.04, 0.16, 0.040),
      (0.11, 0.19, 0.036),
      (0.17, 0.24, 0.032), // 새끼
    ];
    for (final (dx, dy, r) in toes) {
      canvas.drawCircle(Offset(cx + h * dx, h * dy), h * r, paint);
    }
  }

  @override
  bool shouldRepaint(_HumanFootprintPainter old) => false;
}
