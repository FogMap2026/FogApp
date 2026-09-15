import 'package:flutter/material.dart';

import '../models/footprint.dart';

/// 「이 구역에는 이미 발자취를 남겼어요」 안내(시진, 09-15). 발자취는 구역당 하나다 —
/// 남긴 글을 짧게 보여줘 «어느 글을 말하는지» 바로 알게 한다.
Future<void> showFootprintRegionTakenDialog(BuildContext context, Footprint existing) {
  final content = existing.content;
  final preview = content.length > 40 ? '${content.substring(0, 40)}…' : content;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('이 구역에는 이미 발자취를 남겼어요'),
      content: Text('발자취는 구역당 하나만 남길 수 있어요.\n\n남긴 글: “$preview”\n\n내 프로필에서 고치거나 지울 수 있어요.'),
      actions: [FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('확인'))],
    ),
  );
}
