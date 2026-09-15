import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'map_compass_button.dart';
import 'map_pin.dart';

/// ☰ 를 눌렀을 때 위로 펼쳐지는 항목 하나.
///
/// [active] 가 null 이면 «화면을 여는 버튼», null 이 아니면 **토글**이다 — 토글은 켜졌을
/// 때 테두리와 아이콘이 강조색으로 바뀌어 «지금 켜져 있다»가 보인다. 토글을 평범한 버튼과
/// 같은 모양으로 두면 눌러 본 뒤에도 켠 건지 끈 건지 모른다.
class MapMenuEntry {
  const MapMenuEntry({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active,
  });

  final IconData icon;
  final String label;

  /// null 이면 비활성(아직 준비 안 됨).
  final VoidCallback? onTap;

  /// 토글이면 켜짐 여부, 아니면 null.
  final bool? active;
}

/// 지도 하단에 상시로 서는 원 셋 — 발자취 · 나침반 · 메뉴(피그마 메인화면, oorony 09-15).
///
/// ## 왜 셋만 있는가
///
/// 예전에는 좌하단에 「내 프로필」·「친구」·「발자취 남기기」가 세로로 쌓이고, 우측 상단에
/// 확대·축소·내 위치·📍 패널이 따로 있었다. 화면에 버튼이 일곱 개였고, 늘어날 때마다
/// 네이버 로고와 지도 컨트롤을 밀어냈다(#64·#187·#190·#194).
///
/// 이제 **상시 노출은 셋으로 고정**하고 나머지는 ☰ 안으로 들어간다. 자주 쓰는 순서대로
/// 손이 닿는 자리다 — 왼쪽 엄지에 발자취, 가운데에 나침반, 오른쪽 엄지에 메뉴.
///
/// 확대·축소 버튼은 없앴다. 핀치 줌이 있고, 버튼 넷짜리 패널이 지도의 우측 상단을
/// 상시로 덮을 만큼 자주 쓰이지 않았다.
class MapActionDock extends StatelessWidget {
  const MapActionDock({
    required this.onFootprint,
    required this.footprintQuota,
    required this.footprintBusy,
    required this.bearing,
    required this.compassMode,
    required this.onCompass,
    required this.menuOpen,
    required this.onToggleMenu,
    required this.menuEntries,
    super.key,
  });

  /// 발자취 남기기(#118). 남은 횟수가 0이거나 위치를 재는 중이면 null.
  final VoidCallback? onFootprint;

  /// 남은 발자취 작성 횟수. null 이면 아직 못 받아온 것 — 뱃지를 띄우지 않는다.
  final int? footprintQuota;

  /// GPS 정확도를 재는 중. 원 안이 스피너로 바뀐다.
  final bool footprintBusy;

  final ValueListenable<double> bearing;
  final MapCompassMode compassMode;
  final VoidCallback? onCompass;

  final bool menuOpen;
  final VoidCallback onToggleMenu;

  /// 위에서부터 차례로 쌓인다.
  final List<MapMenuEntry> menuEntries;

  /// 발자취·메뉴 원의 지름. 가운데 나침반은 한 치수 작게 둔다 — 셋이 같은 크기면
  /// 「어느 것이 주된 행동인지」가 안 보인다.
  static const double _actionSize = 56;
  static const double _compassSize = 50;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 메뉴는 ☰ 위로만 자란다 — 접든 펼치든 ☰ 는 **같은 자리**에 있어서 연달아 누를 때
        // 손가락을 옮기지 않아도 된다.
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomRight,
          child: menuOpen
              ? Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final entry in menuEntries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: _MenuChip(entry: entry),
                        ),
                    ],
                  ),
                )
              : const SizedBox(width: 0, height: 0),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _FootprintButton(
              size: _actionSize,
              onTap: onFootprint,
              quota: footprintQuota,
              busy: footprintBusy,
            ),
            MapCompassButton(
              bearing: bearing,
              mode: compassMode,
              onTap: onCompass,
              size: _compassSize,
            ),
            _CircleButton(
              size: _actionSize,
              onTap: onToggleMenu,
              semanticsLabel: menuOpen ? '메뉴 닫기' : '메뉴 열기',
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  menuOpen ? Icons.close : Icons.menu,
                  key: ValueKey(menuOpen),
                  size: 26,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 발자취 남기기 — 셋 중 **유일하게 칠한 원**이다. 이 화면에서 «지금 할 행동»이 하나라면
/// 그것이라서, 색으로 먼저 눈에 띈다.
class _FootprintButton extends StatelessWidget {
  const _FootprintButton({
    required this.size,
    required this.onTap,
    required this.quota,
    required this.busy,
  });

  final double size;
  final VoidCallback? onTap;
  final int? quota;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: quota == null ? '발자취 남기기' : '발자취 남기기, $quota회 남음',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: enabled ? AppColors.primary : AppColors.inkFaint,
            shape: const CircleBorder(),
            elevation: 3,
            shadowColor: const Color(0x33000000),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: size,
                height: size,
                child: Center(
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(AppColors.surface),
                          ),
                        )
                      // 지도 위 발자취 핀([HumanFootprint])과 같은 발 모양 — «남기기» 버튼과
                      // 지도의 발자취 마커가 한 식구로 읽힌다(시진, 09-15).
                      : SizedBox(
                          width: size * 0.48,
                          height: size * 0.48,
                          child: const HumanFootprint(color: AppColors.surface),
                        ),
                ),
              ),
            ),
          ),
          // 남은 횟수는 숫자로만 알린다 — 「발자취 남기기 (3)」처럼 글을 붙일 자리가 없다.
          if (quota != null)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: quota == 0 ? AppColors.errorContainer : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: AppColors.hairline),
                  boxShadow: AppShadows.soft,
                ),
                child: Text(
                  '$quota',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: quota == 0 ? AppColors.onErrorContainer : AppColors.inkSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 흰 원 버튼 한 개(메뉴 토글). 지도 위에 뜨는 것이라 경계선 한 줄 + 옅은 그림자로
/// 종이에서 살짝 뜨게 한다(Notion `button-secondary` — [mapActionButtonStyle] 과 같은 결).
class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.size,
    required this.onTap,
    required this.semanticsLabel,
    required this.child,
  });

  final double size;
  final VoidCallback? onTap;
  final String semanticsLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(side: BorderSide(color: AppColors.hairline)),
        elevation: 2,
        shadowColor: const Color(0x1F000000),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(width: size, height: size, child: Center(child: child)),
        ),
      ),
    );
  }
}

/// 메뉴 항목 알약. 오른쪽 끝을 ☰ 에 맞춰 세우고 글자만큼만 왼쪽으로 자란다.
class _MenuChip extends StatelessWidget {
  const _MenuChip({required this.entry});

  final MapMenuEntry entry;

  @override
  Widget build(BuildContext context) {
    final enabled = entry.onTap != null;
    final on = entry.active ?? false;
    final foreground = !enabled
        ? AppColors.inkFaint
        : on
            ? AppColors.primary
            : AppColors.inkSecondary;

    return Semantics(
      button: true,
      enabled: enabled,
      toggled: entry.active,
      child: Material(
        color: on ? AppColors.infoContainer : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl + 4),
        elevation: 2,
        shadowColor: const Color(0x1F000000),
        child: InkWell(
          onTap: entry.onTap,
          borderRadius: BorderRadius.circular(AppRadii.xl + 4),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.xl + 4),
              border: Border.all(color: on ? AppColors.primary : AppColors.hairline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(entry.icon, size: 18, color: foreground),
                const SizedBox(width: 6),
                Text(
                  entry.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
