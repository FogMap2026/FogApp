import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'conquest_pill.dart';

/// 지도 우상단 한 줄 — 정복률 배터리 + 프로필(피그마 메인화면, oorony 09-15).
///
/// 예전 상단 정보 바(`_TopInfoBar`)는 화면 폭을 통째로 먹는 흰 카드였다. 지도가 주인공인
/// 화면에서 **맨 위를 가로지르는 띠**는 가장 비싼 자리를 쓰는 것이라, 오른쪽 끝에 붙는
/// 알약 둘로 줄였다.
///
/// 지역 이름은 뺐다 — 지도 위에 이미 지명이 찍혀 있고, 정복률이 어느 지역 것인지는
/// 배터리를 눌러 들어간 [전국 정복 현황] 화면이 말한다.
///
/// 알림([ConquestPillMode.near]·[ConquestPillMode.verifiable])이 오면 배터리가 **프로필
/// 왼쪽으로 길게 자란다.** 프로필은 제자리에 있고 배터리만 늘어난다 — 오른쪽 끝이
/// 고정돼 있어야 «같은 상자가 자랐다»로 읽힌다.
class MapTopBar extends StatelessWidget {
  const MapTopBar({
    required this.pillMode,
    required this.conquestRate,
    required this.pillMessage,
    required this.onPillTap,
    required this.profileImageUrl,
    required this.onProfileTap,
    super.key,
  });

  final ConquestPillMode pillMode;
  final double? conquestRate;
  final String? pillMessage;
  final VoidCallback onPillTap;

  /// 없으면 사람 실루엣을 그린다.
  final String? profileImageUrl;
  final VoidCallback onProfileTap;

  static const double _profileSize = 44;

  @override
  Widget build(BuildContext context) {
    // 프로필이 위, 배터리가 그 아래 — 오른쪽 끝에 세로로 선다(시진, 09-15). 한 줄에 나란히 두면
    // 알림으로 자랄 때 프로필 왼쪽 폭만큼밖에 못 자라 긴 스팟 이름이 잘렸다. 아래 줄에 두면
    // 화면 폭 전체를 쓸 수 있고 프로필 버튼과 서로 밀지 않는다.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _ProfileButton(
          size: _profileSize,
          imageUrl: profileImageUrl,
          onTap: onProfileTap,
        ),
        const SizedBox(height: AppSpacing.xs),
        // 배터리는 «폭 전체»를 받아 두고 그 안에서 오른쪽에서 왼쪽으로 자란다 — 자랄 수 있는
        // 최대치를 상수로 짐작하면 좁은 폰에서 넘치고 넓은 폰에서 모자란다.
        SizedBox(
          width: double.infinity,
          child: Align(
            alignment: Alignment.centerRight,
            child: ConquestPill(
              mode: pillMode,
              rate: conquestRate,
              message: pillMessage,
              onTap: onPillTap,
            ),
          ),
        ),
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
