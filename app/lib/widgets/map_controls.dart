import 'package:flutter/material.dart';

/// 지도 우측 상단 컨트롤(확대·축소·내 위치·이 지역 스팟). 세로로 쌓인 아이콘 버튼 한 줄이다.
///
/// **폭을 [_width] 로 고정한다.** 안 그러면 화면 전체를 덮는다 —
/// [Divider] 는 고유 폭이 없어 주어진 최대 폭까지 늘어나고, `Column` 의
/// `mainAxisSize: min` 은 **세로**만 줄이므로 가로를 막지 못한다. 부모가
/// `Align` 이라 최대 폭이 화면 폭이 되고, 결과적으로 이 반투명 패널이
/// 좌하단 버튼들(「내 동행 요청」·「발자취 남기기」) 위를 덮어 **탭을
/// 가로챈다**(#64 와 같은 종류의 겹침이지만 원인이 다르다).
///
/// 지금은 상단 정보 바 아래 우측에 놓여 좌하단 버튼과 아예 만나지 않지만,
/// **폭 고정은 그대로 둔다** — 배치가 다시 바뀌어도 같은 사고가 나지 않게 하는
/// 것이 이 값의 목적이고, `map_controls_test.dart` 가 그걸 지킨다.
class MapControls extends StatelessWidget {
  const MapControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRecenter,
    required this.onSearchHere,
    this.searchHereActive = false,
  });

  /// 패널 폭. 아이콘(20) + 좌우 여백이 들어가는 최소치다.
  ///
  /// Material 권장 터치 영역은 48 이지만, 지도 위에 상시 떠 있는 컨트롤이라
  /// **지도를 가리는 면적을 줄이는 쪽**을 택했다. 40 은 손가락으로 누르는 데
  /// 무리가 없는 선이면서 지도 시야를 덜 먹는다.
  static const double _width = 40;

  /// 버튼 하나의 높이. 정사각형으로 두어 네 개가 40×160 한 덩어리가 된다.
  static const double _buttonSize = 40;

  /// 기본값(24)보다 작게 — 패널이 작아진 만큼 아이콘도 같이 줄여야 답답해 보이지 않는다.
  static const double _iconSize = 20;

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  /// 아직 내 위치를 모르면 null — 버튼이 비활성화된다.
  final VoidCallback? onRecenter;

  /// 「이 지역 스팟 보기」 토글 — 스팟은 평소 내 위치 주변만 불러오는데, 켜면 화면
  /// 중심 주변을 불러오고 지도를 움직일 때마다 따라온다. 지도가 아직 준비 전이면 null.
  final VoidCallback? onSearchHere;

  /// 토글이 켜져 있는지. 켜지면 아이콘을 채우고 강조색으로 그려 «지금 화면 기준»임을
  /// 알린다 — 안 그러면 내 주변 스팟이 왜 안 뜨는지 모른다.
  final bool searchHereActive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
      elevation: 2,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: _width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _button(icon: Icons.add, onPressed: onZoomIn, tooltip: '확대'),
            const Divider(height: 1),
            _button(icon: Icons.remove, onPressed: onZoomOut, tooltip: '축소'),
            const Divider(height: 1),
            _button(icon: Icons.my_location, onPressed: onRecenter, tooltip: '내 위치로'),
            const Divider(height: 1),
            _button(
              icon: searchHereActive ? Icons.location_on : Icons.location_on_outlined,
              onPressed: onSearchHere,
              tooltip: searchHereActive ? '내 위치 기준으로' : '이 지역 스팟 보기',
              color: searchHereActive ? Theme.of(context).colorScheme.primary : null,
            ),
          ],
        ),
      ),
    );
  }

  /// `IconButton` 은 기본 패딩이 8이라 그대로 두면 40×40 을 넘긴다.
  /// 패딩을 지우고 [_buttonSize] 로 제약을 걸어 네 개가 정확히 맞물리게 한다.
  Widget _button({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
    Color? color,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: color),
      iconSize: _iconSize,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: _buttonSize, height: _buttonSize),
      visualDensity: VisualDensity.compact,
    );
  }
}
