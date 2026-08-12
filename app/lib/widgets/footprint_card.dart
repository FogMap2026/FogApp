import 'package:flutter/material.dart';

import '../models/footprint.dart';
import '../services/api_client.dart';

/// 발자취 카드(#71). 스팟 상세(#50)와 내 발자취 모아보기(#73)가 함께 쓴다 —
/// 같은 카드를 두 화면에서 따로 만들지 않기 위해 여기 하나로 둔다.
///
/// 좋아요는 이 카드에서는 표시만 한다(개수·눌렀는지). 탭해서 토글하는 상호작용은
/// #72에서 이 위젯을 감싸는 쪽에 붙인다 — 카드 자체는 그 상태를 모른다.
class FootprintCard extends StatefulWidget {
  const FootprintCard({required this.footprint, super.key});

  final Footprint footprint;

  @override
  State<FootprintCard> createState() => _FootprintCardState();
}

class _FootprintCardState extends State<FootprintCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final footprint = widget.footprint;
    final content = footprint.content;
    final needsToggle = content.length > 120;
    final photoUrl = footprint.photoUrl;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _AuthorAvatar(url: footprint.authorProfileImageUrl),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(footprint.authorLabel, style: theme.textTheme.titleSmall),
                      Text(
                        _relativeTime(footprint.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              content,
              maxLines: _expanded ? null : 4,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            if (needsToggle)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(_expanded ? '접기' : '더 보기'),
                ),
              ),
            if (photoUrl != null && photoUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(_resolveUrl(photoUrl), fit: BoxFit.cover),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  footprint.likedByMe ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: footprint.likedByMe ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text('${footprint.likeCount}', style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 서버가 내려주는 사진 경로는 `/api/...` 상대 경로일 수 있다(인증 사진과 같은 구조) —
/// 절대 URL(관광공사 이미지 등)이 아니면 API 베이스 URL을 붙인다.
String _resolveUrl(String url) => url.startsWith('http') ? url : '$apiBaseUrl$url';

/// "방금" / "N분 전" / "N시간 전" / "N일 전" / 그 이상은 날짜로. `intl` 없이 충분한 정도만.
String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return '방금';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  return '${time.year}.${time.month.toString().padLeft(2, '0')}.${time.day.toString().padLeft(2, '0')}';
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url;
    if (imageUrl == null || imageUrl.isEmpty) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.person_outline, size: 18, color: Colors.black45),
      );
    }
    return CircleAvatar(
      radius: 16,
      backgroundImage: NetworkImage(_resolveUrl(imageUrl)),
      onBackgroundImageError: (_, __) {},
    );
  }
}
