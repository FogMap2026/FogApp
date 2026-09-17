import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'conquest_pill_mode.dart';

/// 지도 우상단 한 줄 — 정복률 배터리 + 프로필(피그마 메인화면, oorony 09-15).
///
/// 예전 상단 정보 바(`_TopInfoBar`)는 화면 폭을 통째로 먹는 흰 카드였다. 지도가 주인공인
/// 화면에서 **맨 위를 가로지르는 띠**는 가장 비싼 자리를 쓰는 것이라, 오른쪽 끝에 붙는
/// 알약 둘로 줄였다.
///
/// 지역 이름은 뺐다 — 지도 위에 이미 지명이 찍혀 있고, 정복률이 어느 지역 것인지는
/// 배터리를 눌러 들어간 [전국 정복 현황] 화면이 말한다.
///
/// 배치(시진, 09-15): 위 줄 = [근접 알림 배너 … 프로필], 아래 줄 = 정복률 배터리(프로필 아래).
/// 처음엔 배터리가 알림으로 «변신»했는데(피그마 안), 정복률과 알림은 서로 다른 말이라 따로
/// 둔다 — 배터리는 늘 정복률만, 알림은 왼쪽 빈 자리에 따로 뜬다. 알림이 없으면 그 자리는 비어
/// 지도가 보인다.
class MapTopBar extends StatelessWidget {
  const MapTopBar({
    required this.pillMode,
    required this.conquestRate,
    required this.pillMessage,
    required this.onAlarmTap,
    required this.profileImageUrl,
    required this.onProfileTap,
    super.key,
  });

  /// 근접 단계. [ConquestPillMode.progress] 면 알림 배너가 없다.
  final ConquestPillMode pillMode;
  final double? conquestRate;

  /// 알림 배너 문구(「○○ 근처 · 약 200m」). 없으면 null.
  final String? pillMessage;

  /// 알림 배너 탭 — 그 스팟 상세.
  final VoidCallback onAlarmTap;

  /// 없으면 사람 실루엣을 그린다.
  final String? profileImageUrl;
  final VoidCallback onProfileTap;

  static const double _profileSize = 44;

  @override
  Widget build(BuildContext context) {
    // 프로필이 위, 배터리가 그 아래 — 오른쪽 끝에 세로로 선다(시진, 09-15). 한 줄에 나란히 두면
    // 알림으로 자랄 때 프로필 왼쪽 폭만큼밖에 못 자라 긴 스팟 이름이 잘렸다. 아래 줄에 두면
    // 화면 폭 전체를 쓸 수 있고 프로필 버튼과 서로 밀지 않는다.
    final message = pillMessage;
    final alarm = pillMode != ConquestPillMode.progress && message != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          children: [
            // 알림 배너 — 프로필 왼쪽의 남는 폭 전체를 쓸 수 있다. 없으면 빈 자리.
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: alarm
                    ? Align(
                        key: ValueKey(message),
                        alignment: Alignment.centerRight,
                        child: ProximityBanner(mode: pillMode, message: message, onTap: onAlarmTap),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            _ProfileButton(
              size: _profileSize,
              imageUrl: profileImageUrl,
              onTap: onProfileTap,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        // 탐험률 — 알약 없이 숫자만, 프로필 바로 아래(시진, 09-15). 배터리는 자리를 먹고 알림과
        // 헷갈렸다. 누르는 것이 아니다 — 탐험 현황은 프로필 안에 있다.
        _ConquestRateText(rate: conquestRate, width: _profileSize),
      ],
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({
    required this.size,
    required this.imageUrl,
    required this.onTap,
  });

  final double size;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return Semantics(
      button: true,
      label: '내 프로필',
      child: Material(
        color: AppColors.buttonSecondary,
        shape: const CircleBorder(side: BorderSide(color: AppColors.hairline)),
        elevation: 2,
        shadowColor: const Color(0x1F000000),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: url == null || url.isEmpty
                ? const Icon(Icons.person, size: 26, color: AppColors.inkSecondary)
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    // 프로필 사진을 못 받아와도 버튼은 그대로 눌려야 한다 — 실루엣으로 되돌린다.
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.person,
                      size: 26,
                      color: AppColors.inkSecondary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// 근접 알림 배너 — 「○○ 근처 · 약 200m」/「○○ 인증 가능」. 배터리 알약과 같은 높이·같은 옷
/// (연파랑 바탕·파란 테두리)이라 한 식구로 읽히되, 정복률과는 별개의 상자다.
class ProximityBanner extends StatelessWidget {
  const ProximityBanner({required this.mode, required this.message, required this.onTap, super.key});

  final ConquestPillMode mode;
  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final verifiable = mode == ConquestPillMode.verifiable;
    return Semantics(
      button: true,
      label: '$message. 눌러서 스팟 보기',
      child: Material(
        color: AppColors.infoContainer,
        shape: StadiumBorder(side: BorderSide(color: AppColors.primary, width: verifiable ? 1.5 : 1.2)),
        elevation: 2,
        shadowColor: const Color(0x1F000000),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: SizedBox(
            // 프로필 버튼과 같은 높이 — 한 줄에 나란히 서는 둘의 키가 같아야 한 식구로 읽힌다.
            height: MapTopBar._profileSize,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    verifiable ? Icons.camera_alt_outlined : Icons.near_me_outlined,
                    size: 15,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  // 상자보다 길면 잘라 「…」로 내지 않고 글자를 줄인다 — 어느 스팟인지는 읽혀야 한다.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        message,
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 탐험률 숫자 — 「12%」. 누르는 것이 아니라 보는 것이다(탐험 현황은 프로필 안에서 들어간다).
/// 지도 위라 흰 테두리(획)로 글자를 띄운다 — 그림자만으로는 안개 위에서 흐렸다(시진, 09-15).
class _ConquestRateText extends StatelessWidget {
  const _ConquestRateText({required this.rate, required this.width});

  final double? rate;
  final double width;

  static const _style = TextStyle(fontSize: 15, fontWeight: FontWeight.w800, height: 1.2);

  @override
  Widget build(BuildContext context) {
    final value = rate;
    final label = value == null ? '--%' : '${(value * 100).round()}%';
    return Semantics(
      label: '이 지역 탐험률 ${value == null ? '알 수 없음' : label}',
      child: SizedBox(
        width: width,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 흰 획 — 글자 뒤에 굵게 한 번 그리고 그 위에 본 글자를 얹는다.
            Text(
              label,
              textAlign: TextAlign.center,
              style: _style.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 4
                  ..strokeJoin = StrokeJoin.round
                  ..color = Colors.white,
              ),
            ),
            Text(label, textAlign: TextAlign.center, style: _style.copyWith(color: AppColors.ink)),
          ],
        ),
      ),
    );
  }
}
