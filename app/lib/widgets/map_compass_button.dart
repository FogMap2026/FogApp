import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 하단 가운데 원이 지금 무엇인가.
///
/// 평소에는 나침반이고, 스팟에 다가서면 **그 자리에서 «!» 로 바뀐다**(피그마 메인화면,
/// oorony 09-15). 알림을 위한 원을 따로 띄우지 않는 것이 핵심이다 — 지도 위에 상시로
/// 서 있는 것은 세 개뿐이고, 알림은 그중 하나가 «표정을 바꾸는» 방식으로 온다.
enum MapCompassMode {
  /// 나침반. 바늘이 지도 방위를 따라 돌고, 누르면 내 위치로 간다.
  compass,

  /// 근처에 스팟이 있다 — 조용한 «!». 누르면 알림을 접는다.
  near,

  /// 인증할 수 있다 — 맥박치는 «!». 누르면 인증 화면으로 간다.
  verifiable,
}

/// 지도 하단 가운데의 나침반 겸 알림 원.
///
/// [bearing] 은 `setState` 로 받지 않고 [ValueListenable] 로 받는다 — 지도를 돌리는 동안
/// 카메라 이벤트가 프레임마다 쏟아지는데, 그때마다 지도 화면 전체를 다시 그리면
/// 오버레이·마커까지 같이 재빌드된다. 바늘만 듣게 한다.
class MapCompassButton extends StatefulWidget {
  const MapCompassButton({
    required this.bearing,
    required this.mode,
    required this.onTap,
    this.size = 52,
    super.key,
  });

  /// 지도 방위(도). 0이 북쪽이고, 시계 방향으로 커진다 — 바늘은 반대로 돌아야 북을 가리킨다.
  final ValueListenable<double> bearing;

  final MapCompassMode mode;

  /// 아직 내 위치를 모르면 null — 나침반 상태에서만 비활성이 될 수 있다.
  final VoidCallback? onTap;

  final double size;

  @override
  State<MapCompassButton> createState() => _MapCompassButtonState();
}

class _MapCompassButtonState extends State<MapCompassButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant MapCompassButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) _syncPulse();
  }

  /// 맥박은 «인증 가능» 에서만 돈다. 나침반 상태에서도 계속 돌면 배터리를 먹으면서
  /// 아무 뜻도 전하지 않는다.
  void _syncPulse() {
    if (widget.mode == MapCompassMode.verifiable) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final verifiable = widget.mode == MapCompassMode.verifiable;
    return Semantics(
      button: true,
      label: switch (widget.mode) {
        MapCompassMode.compass => '내 위치로 이동',
        MapCompassMode.near => '근처에 스팟이 있어요. 눌러서 알림 닫기',
        MapCompassMode.verifiable => '인증할 수 있어요. 눌러서 인증하기',
      },
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (verifiable) ...[
                _ring(_pulse.value),
                _ring((_pulse.value + 0.5) % 1),
              ],
              child!,
            ],
          );
        },
        child: Material(
          color: verifiable ? AppColors.primary : AppColors.surface,
          shape: CircleBorder(
            side: BorderSide(
              color: widget.mode == MapCompassMode.near ? AppColors.primary : AppColors.hairline,
              width: widget.mode == MapCompassMode.near ? 1.5 : 1,
            ),
          ),
          elevation: 2,
          shadowColor: const Color(0x1F000000),
          child: InkWell(
            onTap: widget.onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Center(child: _face()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _face() {
    switch (widget.mode) {
      case MapCompassMode.compass:
        return ValueListenableBuilder<double>(
          valueListenable: widget.bearing,
          builder: (context, bearing, _) => Transform.rotate(
            // 테스트가 이 바늘의 회전만 집어 재려고 쓴다(`map_compass_button_test.dart`).
            key: const ValueKey('compass-needle'),
            angle: -bearing * math.pi / 180,
            child: CustomPaint(
              size: Size.square(widget.size * 0.46),
              painter: const _NeedlePainter(),
            ),
          ),
        );
      case MapCompassMode.near:
        return Text(
          '!',
          style: TextStyle(
            fontSize: widget.size * 0.46,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
            height: 1,
          ),
        );
      case MapCompassMode.verifiable:
        // «근처» 와 색을 뒤집는다 — 같은 «!» 라도 흰 바탕의 파란 글자와 파란 바탕의 흰 글자는
        // 멀리서 봐도 다른 것으로 읽힌다(oorony: «조금 다른 !»).
        return Text(
          '!',
          style: TextStyle(
            fontSize: widget.size * 0.52,
            fontWeight: FontWeight.w800,
            color: AppColors.surface,
            height: 1,
          ),
        );
    }
  }

  /// 원 테두리에서 퍼져 나가며 옅어지는 고리. [t] 는 0→1.
  ///
  /// 🔴 **[Positioned.fill] 이어야 한다.** 그냥 Stack 의 자식으로 두면 고리가 커질 때마다
  /// Stack 자체가 커지고, 이 버튼은 하단 세 원의 `spaceBetween` Row 안에 있어서 **양옆
  /// 버튼이 맥박에 맞춰 흔들린다.** 위치 지정 자식은 Stack 크기에 영향을 주지 않는다.
  Widget _ring(double t) {
    final spread = 12.0 * t;
    return Positioned.fill(
      left: -spread,
      top: -spread,
      right: -spread,
      bottom: -spread,
      child: IgnorePointer(
        child: Opacity(
          opacity: (1 - t) * 0.5,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}

/// 나침반 바늘 — 북쪽 반은 강조색, 남쪽 반은 흐린 잉크. 두 삼각형이 가운데서 만난다.
class _NeedlePainter extends CustomPainter {
  const _NeedlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final halfWidth = size.width * 0.22;
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    final north = Path()
      ..moveTo(centerX, 0)
      ..lineTo(centerX - halfWidth, centerY)
      ..lineTo(centerX + halfWidth, centerY)
      ..close();
    final south = Path()
      ..moveTo(centerX, size.height)
      ..lineTo(centerX - halfWidth, centerY)
      ..lineTo(centerX + halfWidth, centerY)
      ..close();

    canvas.drawPath(north, Paint()..color = AppColors.primary);
    canvas.drawPath(south, Paint()..color = AppColors.inkFaint);
  }

  @override
  bool shouldRepaint(covariant _NeedlePainter oldDelegate) => false;
}
