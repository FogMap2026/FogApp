import 'package:flutter/material.dart';

import '../services/spot_proximity.dart';
import '../theme/app_theme.dart';

/// [ConquestPill] 이 지금 무엇을 말하고 있는가.
///
/// 한 상자가 세 가지 일을 한다 — 평소엔 **이 지역 정복률**, 스팟에 다가서면 **알림**,
/// 인증할 수 있게 되면 **인증 버튼**. 아이폰 다이나믹 아일랜드와 같은 방식이다
/// (피그마 메인화면, oorony 09-15): 새 창이 뜨는 게 아니라 **있던 상자가 옆으로 자란다.**
enum ConquestPillMode {
  /// 평소 — 배터리 모양 안에 정복률 숫자만.
  progress,

  /// 스팟 300m 안. 프로필 왼쪽으로 길게 자라며 «○○ 근처예요»를 띄운다. 누르면 접힌다.
  near,

  /// 인증 반경 100m 안. 근처보다 **더 길게** 자라고, 누르면 인증 화면으로 간다.
  verifiable,
}

/// 지금 알약이 무엇을 말해야 하는가.
///
/// 반환값이 하나뿐인 것이 핵심이다 — 「알림이 떴다」와 「정복률을 보여준다」를 불리언 둘로
/// 두면 **둘 다 참인** 상태를 만들 수 있는데, 여기서는 타입이 그걸 막는다(`mapNoticeFor`
/// 와 같은 판단, #146).
///
/// [dismissedSpotId] 는 사용자가 «근처» 알림을 눌러 닫은 스팟이다. **«인증 가능»은 이 값을
/// 보지 않는다** — 닫힌 채로 인증 기회를 놓치게 두지 않는다. 그래서 닫아 둔 스팟에
/// 100m 까지 더 다가가면 알림이 **다시** 뜬다.
///
/// 지도·위치 스트림과 무관한 순수 함수라 따로 검증한다(`conquest_pill_test.dart`).
ConquestPillMode conquestPillModeFor({
  required SpotProximity? proximity,
  required int? dismissedSpotId,
}) {
  if (proximity == null) return ConquestPillMode.progress;
  if (proximity.level == ProximityLevel.verifiable) return ConquestPillMode.verifiable;
  if (proximity.spot.id == dismissedSpotId) return ConquestPillMode.progress;
  return ConquestPillMode.near;
}

/// 지도 우상단 — 프로필 버튼 왼쪽에 서는 «정복률 배터리».
///
/// ## 왜 배터리 모양인가
///
/// 정복률은 «얼마나 찼나»라서 숫자만으로는 감이 안 온다. 갤럭시 배터리 아이콘처럼
/// 테두리 안이 왼쪽부터 차오르면 숫자를 읽기 전에 눈으로 먼저 안다(oorony, 09-15).
///
/// ## 왜 알림을 여기에 띄우는가
///
/// 예전에는 우하단에 따로 «!» 원을 띄웠는데(`ProximityPrompt`), 지도 위에 상시로 떠 있는
/// 것이 하나 더 늘어나는 셈이었다. 이미 자리를 차지하고 있는 이 상자가 **모양만 바꾸면**
/// 지도를 새로 가리지 않는다.
///
/// 알림 중에는 정복률을 감춘다 — 한 상자가 두 가지를 동시에 말하면 둘 다 안 읽힌다.
class ConquestPill extends StatelessWidget {
  const ConquestPill({
    required this.mode,
    required this.rate,
    required this.message,
    required this.onTap,
    super.key,
  });

  final ConquestPillMode mode;

  /// 0.0~1.0. 아직 못 구했으면 null — 배터리는 비어 있고 숫자 자리에 «--» 가 뜬다.
  final double? rate;

  /// [ConquestPillMode.near]·[ConquestPillMode.verifiable] 일 때 띄울 한 줄.
  /// 두 줄로 늘리지 않는다 — 높이가 바뀌면 «자란다»가 아니라 «다른 게 떴다»로 보인다.
  final String? message;

  final VoidCallback onTap;

  /// 배터리 몸통. 숫자 세 자리(100)가 들어가는 최소 폭이다.
  static const double bodyWidth = 58;

  /// 접혀 있든 펼쳐지든 **높이는 그대로다.** 다이나믹 아일랜드가 그렇듯, 자라는 것은 폭뿐이다.
  static const double height = 32;

  /// 배터리 꼭지. 알림으로 자랄 때는 폭 0 으로 줄여 없앤다 — 알림 막대에 꼭지가 달려 있으면
  /// 배터리가 늘어난 것처럼 보인다.
  static const double _nubWidth = 4;

  /// 차오른 부분의 색.
  ///
  /// 안내 배너 바탕([AppColors.infoContainer])을 그대로 쓰다가 **보이지 않아서** 진하게
  /// 했다 — 흰 알약 위 옅은 파랑은 차이가 4% 남짓이라 72%든 10%든 그냥 흰 알약으로 보였다.
  /// 강조색을 «칠하지 않는다»는 규칙의 예외에 해당한다: 이건 장식이 아니라 **선택·진행
  /// 상태**이고, 테마가 [AppColors.primary] 에 허락한 용도가 그것이다.
  static const _fill = Color(0x380075DE);

  static const Duration _duration = Duration(milliseconds: 420);
  static const Curve _curve = Curves.easeOutCubic;

  bool get _alarm => mode != ConquestPillMode.progress;

  /// 알림일 때 쓸 수 있는 폭 중 얼마나 차지할지.
  ///
  /// «인증 가능»이 «근처»보다 길다 — 같은 자리에서 한 번 더 자라는 것이 «한 단계 올라섰다»는
  /// 신호가 된다. 둘이 같은 폭이면 문구를 읽기 전에는 구분이 안 된다.
  double get _expandedFactor => mode == ConquestPillMode.verifiable ? 1.0 : 0.74;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 몸통 옆 간격(1.5)과 꼭지(_nubWidth)까지 한 Row 라, 몸통이 차지할 수 있는 폭은 그만큼 뺀
        // 값이다 — 안 빼면 «인증 가능»(꽉 채움)에서 1.5px 넘친다(CI, 09-15).
        final trailing = 1.5 + (_alarm ? 0 : _nubWidth);
        final maxWidth = constraints.maxWidth.isFinite ? constraints.maxWidth - trailing : bodyWidth;
        final targetWidth = _alarm
            ? (maxWidth * _expandedFactor).clamp(bodyWidth, maxWidth)
            : bodyWidth.clamp(0.0, maxWidth);

        return Semantics(
          button: true,
          label: _semanticsLabel,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: _duration,
                curve: _curve,
                width: targetWidth.toDouble(),
                height: height,
                decoration: BoxDecoration(
                  color: _alarm ? AppColors.infoContainer : AppColors.surface,
                  borderRadius: BorderRadius.circular(height / 2),
                  border: Border.all(
                    color: _alarm ? AppColors.primary : AppColors.inkFaint,
                    width: _alarm ? 1.5 : 1.2,
                  ),
                  boxShadow: AppShadows.soft,
                ),
                clipBehavior: Clip.antiAlias,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: onTap,
                    child: Stack(
                      children: [
                        // 배터리가 차오르는 부분. 알림 중에는 폭 0 으로 빠져나간다.
                        Positioned.fill(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: AnimatedFractionallySizedBox(
                              duration: _duration,
                              curve: _curve,
                              widthFactor: _alarm ? 0 : (rate ?? 0).clamp(0.0, 1.0),
                              heightFactor: 1,
                              child: const ColoredBox(color: _fill),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 240),
                            child: _alarm ? _message(context) : _rate(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 1.5),
              AnimatedContainer(
                duration: _duration,
                curve: _curve,
                width: _alarm ? 0 : _nubWidth,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.inkFaint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _rate(BuildContext context) {
    final value = rate;
    return Center(
      key: const ValueKey('rate'),
      child: Text(
        value == null ? '--' : '${(value * 100).round()}',
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
          height: 1,
        ),
      ),
    );
  }

  Widget _message(BuildContext context) {
    return Padding(
      key: const ValueKey('message'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          Icon(
            mode == ConquestPillMode.verifiable ? Icons.camera_alt_outlined : Icons.near_me_outlined,
            size: 15,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          // 자라는 도중에는 상자가 문구보다 좁다. 줄바꿈하면 높이가 튀므로 한 줄로 눌러 담는다.
          Expanded(
            child: Text(
              message ?? '',
              maxLines: 1,
              overflow: TextOverflow.clip,
              softWrap: false,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _semanticsLabel {
    switch (mode) {
      case ConquestPillMode.progress:
        final value = rate;
        final percent = value == null ? '알 수 없음' : '${(value * 100).round()}퍼센트';
        return '이 지역 정복률 $percent. 눌러서 전국 정복 현황 보기';
      case ConquestPillMode.near:
        return '${message ?? ''}. 눌러서 알림 닫기';
      case ConquestPillMode.verifiable:
        return '${message ?? ''}. 눌러서 인증하기';
    }
  }
}
