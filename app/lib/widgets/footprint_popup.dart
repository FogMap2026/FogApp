import 'package:flutter/material.dart';

import '../models/footprint.dart';
import 'footprint_card.dart';

/// 지도에서 발자취 도형을 탭했을 때 띄우는 글귀 팝업(#117).
///
/// **화면 전환이 아니라 팝업이다.** 지도를 벗어나면 걸으며 읽는 흐름이 끊기므로,
/// 지도가 뒤에 그대로 보이는 바텀시트로 띄운다.
///
/// 카드는 [FootprintCard]를 그대로 쓴다 — 작성자·시각·좋아요가 이미 다 들어 있고,
/// 목록 응답에 작성자 정보와 `likedByMe`가 함께 실려 오므로(#71, #72) 팝업을 띄우려고
/// 추가로 조회할 것이 없다.
Future<void> showFootprintPopup(BuildContext context, Footprint footprint) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    // 글귀는 짧지만 사진이 붙을 수 있어, 길면 시트 안에서 스크롤되게 둔다.
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FootprintCard(footprint: footprint),
            ],
          ),
        ),
      ),
    ),
  );
}
