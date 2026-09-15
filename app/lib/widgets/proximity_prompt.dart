import 'dart:math';

import 'package:flutter/material.dart';

import '../services/spot_proximity.dart';
import '../theme/app_theme.dart';

/// 지도 우하단의 근접 아이콘 — 예전 상단 배너(#46)를 대신한다.
///
/// - **근처**([ProximityLevel.near]): 조용한 «!» 원. 누르면 원이 옆으로 늘어나며 알림 카드로
///   **모양이 바뀐다**(같은 상자가 커지는 것이라 새 창이 뜨는 느낌이 아니다). 닫으면 다시 원으로.
/// - **인증 가능**([ProximityLevel.verifiable]): 「○○ 인증 가능」 카드가 맥박처럼 숨 쉰다.
///   누르면 스팟 상세로 가고, 인증 버튼은 거기 있다. 진동은 화면([MapScreen])이 단계가 바뀌는 순간 한 번 낸다
///   — 이 위젯은 다시 그려질 때마다 불리므로 여기서 울리면 반복된다.
///
/// 상단 배너를 없앤 이유: 지도 위 상단은 정보 바·위치 안내·서버 오류가 이미 쓰고 있고,
/// 근처에 들어설 때마다 카드가 지도를 덮으면 걷는 내내 지도가 가려진다. 아이콘은 알리되
/// 가리지 않는다 — 궁금하면 누른다.
class ProximityPrompt extends StatelessWidget {
  const ProximityPrompt({
    required this.proximity,
    required this.expanded,
    required this.onExpand,
    required this.onCollapse,
    required this.onOpenSpot,
    this.showVerifyLabel = true,
    super.key,
  });

  final SpotProximity proximity;

  /// «근처» 단계에서 카드로 펼쳤는지. 인증 단계에서는 쓰지 않는다.
  final bool expanded;
  final VoidCallback onExpand;
  final VoidCallback onCollapse;

  /// 인증 단계의 «○○ 인증 가능» 카드를 누르면 — 스팟 상세로 간다(시진, 09-15). 인증
  /// (카메라)은 상세 화면에 있다; 지도 위에는 따로 두지 않는다.
  final VoidCallback onOpenSpot;

  /// 카드의 문구. 좌하단 메뉴를 펼쳤을 때는 겹치지 않게 「인증 가능」만 남긴다.
  final bool showVerifyLabel;

  @override
  Widget build(BuildContext context) {
    final verifiable = proximity.level == ProximityLevel.verifiable;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: animation, alignment: Alignment.bottomRight, child: child),
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.bottomRight,
        children: [...previous, if (current != null) current],
      ),
      // 스팟이나 단계가 바뀌면 새 아이콘이 «튀어나오게» 키를 바꾼다.
      child: verifiable
          ? _VerifyBeacon(
              key: ValueKey('verify-${proximity.spot.id}'),
              spotTitle: proximity.spot.title,
              distanceMeters: proximity.distanceMeters,
              onTap: onOpenSpot,
              showLabel: showVerifyLabel,
            )
          : _NearMorph(
              key: ValueKey('near-${proximity.spot.id}'),
              proximity: proximity,
              expanded: expanded,
              onExpand: onExpand,
              onCollapse: onCollapse,
            ),
    );
  }
}

/// «!» 원 ↔ 알림 카드. 한 상자의 크기·모서리·색이 함께 바뀌어 원이 카드로 «변형»된다.
class _NearMorph extends StatelessWidget {
  const _NearMorph({
    required this.proximity,
    required this.expanded,
    required this.onExpand,
    required this.onCollapse,
    super.key,
  });

  final SpotProximity proximity;
  final bool expanded;
  final VoidCallback onExpand;
  final VoidCallback onCollapse;

  static const _circle = 52.0;

  /// 제목 한 줄 + 부제 두 줄(거리 / 안내)이 들어가는 높이.
  static const _cardHeight = 84.0;
  static const _duration = Duration(milliseconds: 360);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = min(constraints.maxWidth, 420.0);
        return AnimatedContainer(
          duration: _duration,
          curve: Curves.easeOutCubic,
          width: expanded ? cardWidth : _circle,
          height: expanded ? _cardHeight : _circle,
          decoration: BoxDecoration(
            color: expanded ? AppColors.infoContainer : AppColors.surface,
            borderRadius: BorderRadius.circular(expanded ? AppRadii.lg : _circle / 2),
            border: Border.all(color: expanded ? AppColors.primary : AppColors.hairline),
            boxShadow: AppShadows.soft,
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            type: MaterialType.transparency,
            child: Semantics(
              // 접힌 원의 글자 «!» 만으로는 스크린 리더가 뜻을 못 읽는다.
              label: expanded ? null : '근처에 스팟이 있어요. 눌러서 자세히 보기',
              child: InkWell(
                onTap: expanded ? null : onExpand,
                child: Stack(
                  children: [
                    // 카드 내용은 «다 펼친 폭»으로 미리 배치해 두고 상자가 자라며 드러나게 한다 —
                    // 자라는 폭에 맞춰 줄바꿈하면 중간 프레임마다 글자가 넘쳐 오류가 난다.
                    Positioned.fill(
                      child: OverflowBox(
                        alignment: Alignment.centerRight,
                        minWidth: cardWidth,
                        maxWidth: cardWidth,
                        minHeight: _cardHeight,
                        maxHeight: _cardHeight,
                        child: AnimatedOpacity(
                          opacity: expanded ? 1 : 0,
                          // 상자가 어느 정도 자란 뒤에 글자가 나타나야 «늘어난 원이 카드가 된다».
                          duration: expanded ? const Duration(milliseconds: 420) : const Duration(milliseconds: 120),
                          curve: expanded ? const Interval(0.45, 1) : Curves.linear,
                          child: IgnorePointer(
                            ignoring: !expanded,
                            child: _NearCardContent(proximity: proximity, onClose: onCollapse),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: _circle,
                      // 🔴 IgnorePointer 를 빼지 말 것. 펼친 뒤 이 «!» 는 투명해질 뿐 그 자리에 남는데,
                      // 카드의 닫기 버튼이 바로 그 오른쪽 끝에 있어 탭을 가로챈다 — 닫기가 안 먹었다.
                      // 원을 누르는 탭은 바깥 InkWell 이 받으므로 여기서 받을 필요가 없다.
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          opacity: expanded ? 0 : 1,
                          duration: const Duration(milliseconds: 160),
                          child: const Center(
                            child: Text(
                              '!',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NearCardContent extends StatelessWidget {
  const _NearCardContent({required this.proximity, required this.onClose});

  final SpotProximity proximity;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distance = proximity.distanceMeters.round();
    final verifyMeters = SpotProximity.verifyEnterMeters.round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 6, AppSpacing.xxs, 6),
      // 아이콘 없이 글만 — 나침반 원은 자리만 먹었고(시진, 09-14), 그 폭을 제목에 준다.
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 스팟 이름이 길면 줄을 바꾸지 않고 글자를 줄여 한 줄에 맞춘다(시진, 09-14) —
                // «…»로 자르지도, 두 줄로 내리지도 않는다.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('${proximity.spot.title} 근처예요', style: theme.textTheme.titleSmall, maxLines: 1),
                ),
                // 거리 뒤에서 줄을 바꾼다 — 한 줄에 넣으면 좁은 폰에서 「인증할…」로 잘렸다(시진, 09-14).
                Text(
                  '약 ${distance}m\n${verifyMeters}m 안으로 가면 인증할 수 있어요',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.inkMuted, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 18, color: AppColors.inkMuted),
            tooltip: '접기',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// 인증 가능 — 누가 봐도 눈에 띄어야 한다. 「○○ 인증 가능」 카드가 맥박처럼 숨 쉬며 고리를
/// 퍼뜨린다. 누르면 스팟 상세로 가고, 인증(카메라)은 거기 있다(시진, 09-15) — 지도 위 카메라
/// 원은 뺐다. 카드와 원이 나란히 있으면 «둘 중 뭘 누르지»가 되고, 상세에도 같은 버튼이 있어
/// 굳이 지도에 둘 필요가 없었다.
///
/// 라벨에 **스팟 이름**을 넣는다 — 「지금 인증하기」만으로는 무엇을 인증하는지 없어서, 스팟이
/// 붙어 있는 도심에서는 눌러 보고서야 어느 스팟인지 알았다(시진, 실기기 09-14). «근처» 카드의
/// 「100m 안으로 가면 인증할 수 있어요」와 이어지는 말이라 두 단계가 한 문장처럼 읽힌다.
class _VerifyBeacon extends StatefulWidget {
  const _VerifyBeacon({
    required this.spotTitle,
    required this.distanceMeters,
    required this.onTap,
    required this.showLabel,
    super.key,
  });

  final String spotTitle;
  final double distanceMeters;

  /// 카드를 누르면 — 스팟 상세.
  final VoidCallback onTap;

  /// 거짓이면(좌하단 메뉴가 펼쳐졌을 때) 문구를 접고 「인증 가능」 알약만 남긴다 — 메뉴와 겹치지 않게.
  final bool showLabel;

  @override
  State<_VerifyBeacon> createState() => _VerifyBeaconState();
}

class _VerifyBeaconState extends State<_VerifyBeacon> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  /// «근처» 카드와 같은 높이 — 두 단계가 한자리에서 문구만 바뀌는 것으로 보이게.
  static const _cardHeight = _NearMorph._cardHeight;

  /// 고리가 카드 밖으로 퍼지는 최대 폭.
  static const _ringSpread = 14.0;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 카드는 «근처» 카드와 같은 자리·같은 폭·같은 옷(연파랑 바탕·파란 테두리) — 두 단계가
    // 같은 카드의 문구만 바뀐 것으로 읽히게. 폭은 문구만큼만(시진, 09-14).
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = min(constraints.maxWidth, 420.0);
        return Semantics(
          button: true,
          label: '${widget.spotTitle} 인증할 수 있어요. 눌러서 스팟 보기',
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                final t = _pulse.value;
                return Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // 카드 테두리에서 바깥으로 퍼지며 옅어지는 고리 둘 — 반 박자 어긋나게.
                    _ring(t),
                    _ring((t + 0.5) % 1),
                    Transform.scale(
                      // 카드 자체도 살짝 숨 쉬게 한다 — 고리만 퍼지면 멀리서 정지한 카드처럼 보인다.
                      scale: 1 + 0.03 * sin(t * 2 * pi),
                      child: child,
                    ),
                  ],
                );
              },
              child: Container(
                constraints: BoxConstraints(maxWidth: cardWidth),
                height: _cardHeight,
                padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 6, AppSpacing.sm, 6),
                decoration: BoxDecoration(
                  color: AppColors.infoContainer,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: AppColors.primary),
                  boxShadow: AppShadows.soft,
                ),
                child: widget.showLabel ? _label(context) : _compact(context),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _label(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 근처 카드와 같은 규칙 — 길면 글자를 줄여 한 줄.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '${widget.spotTitle} 인증 가능',
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                ),
              ),
              Text(
                '약 ${widget.distanceMeters.round()}m · 눌러서 스팟 보기',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted, height: 1.3),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 메뉴가 펼쳐졌을 때의 접힌 모양 — 스팟 이름 없이 「인증 가능」만.
  Widget _compact(BuildContext context) {
    return Center(
      child: Text('인증 가능', style: Theme.of(context).textTheme.titleSmall, maxLines: 1),
    );
  }

  /// 카드 테두리에서 퍼져 나가며 옅어지는 고리. [t] 는 0→1. 카드 크기를 모르고도(문구만큼만
  /// 자라는 카드라) 그리도록 카드 네 변에서 바깥으로 [_ringSpread]·t 만큼 내민다.
  Widget _ring(double t) {
    final spread = _ringSpread * t;
    return Positioned.fill(
      left: -spread,
      top: -spread,
      right: -spread,
      bottom: -spread,
      child: IgnorePointer(
        child: Opacity(
          opacity: (1 - t) * 0.45,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.lg + spread),
              border: Border.all(color: AppColors.primary, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}
