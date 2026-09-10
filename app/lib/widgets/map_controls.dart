import 'package:flutter/material.dart';

/// 지도 우하단 컨트롤(확대·축소·내 위치). 세로로 쌓인 아이콘 버튼 한 줄이다.
///
/// **폭을 [_width] 로 고정한다.** 안 그러면 화면 전체를 덮는다 —
/// [Divider] 는 고유 폭이 없어 주어진 최대 폭까지 늘어나고, `Column` 의
/// `mainAxisSize: min` 은 **세로**만 줄이므로 가로를 막지 못한다. 부모가
/// `Align` 이라 최대 폭이 화면 폭이 되고, 결과적으로 이 반투명 패널이
/// 좌하단 버튼들(「내 동행 요청」·「발자취 남기기」) 위를 덮어 **탭을
/// 가로챈다**(#64 와 같은 종류의 겹침이지만 원인이 다르다).
class MapControls extends StatelessWidget {
  const MapControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRecenter,
  });

  /// `IconButton` 의 최소 터치 영역과 같은 값. 버튼이 잘리지 않는 최소 폭이다.
  static const double _width = 48;

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  /// 아직 내 위치를 모르면 null — 버튼이 비활성화된다.
  final VoidCallback? onRecenter;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: _width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(onPressed: onZoomIn, icon: const Icon(Icons.add)),
            const Divider(height: 1),
            IconButton(onPressed: onZoomOut, icon: const Icon(Icons.remove)),
            const Divider(height: 1),
            IconButton(onPressed: onRecenter, icon: const Icon(Icons.my_location)),
          ],
        ),
      ),
    );
  }
}
