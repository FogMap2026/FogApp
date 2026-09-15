import 'package:flutter/material.dart';

import '../models/footprint.dart';

/// 「이 구역에는 이미 발자취를 남겼어요」 안내(시진, 09-15). 발자취는 구역당 하나다 —
/// 남긴 글을 짧게 보여줘 «어느 글을 말하는지» 바로 알게 한다.
Future<void> showFootprintRegionTakenDialog(BuildContext context, Footprint existing) {
  final content = existing.content;
  final preview = content.length > 40 ? '${content.substring(0, 40)}…' : content;
  return showDialog<void>(
    context: context,
    // 제목·안내 문장이 한 줄에 들어오게 짧게 쓰고 여백도 줄인다 — 갤럭시 S25(360dp)에서 「…있어
    // 요.」처럼 끝 글자 하나가 다음 줄로 넘어갔다(시진, 09-15).
    builder: (context) => AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      title: const Text('이미 발자취를 남긴 구역이에요'),
      content: Text('구역당 하나만 남길 수 있어요.\n\n남긴 글: “$preview”\n\n내 프로필에서 고치거나 지울 수 있어요.'),
      actions: [FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('확인'))],
    ),
  );
}
