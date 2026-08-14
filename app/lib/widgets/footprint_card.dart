import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/footprint.dart';
import '../services/api_client.dart';
import '../services/footprint_service.dart';

/// 발자취 카드(#71). 스팟 상세(#50)와 내 발자취 모아보기(#73)가 함께 쓴다 —
/// 같은 카드를 두 화면에서 따로 만들지 않기 위해 여기 하나로 둔다.
///
/// 좋아요(#72)는 카드가 직접 낙관적으로 처리한다 — 탭 즉시 하트·개수를 반영하고,
/// 요청이 실패하면 되돌린다. 서버가 멱등 처리라(이미 누른 상태에서 좋아요를 또 보내도
/// 조용히 무시) 로컬 상태가 서버와 어긋나도 다음 성공 요청에서 항상 올바르게 수렴한다.
class FootprintCard extends ConsumerStatefulWidget {
  const FootprintCard({required this.footprint, super.key});

  final Footprint footprint;

  @override
  ConsumerState<FootprintCard> createState() => _FootprintCardState();
}

class _FootprintCardState extends ConsumerState<FootprintCard> {
  bool _expanded = false;
  late bool _likedByMe;
  late int _likeCount;
  bool _likeInFlight = false;

  @override
  void initState() {
    super.initState();
    _likedByMe = widget.footprint.likedByMe;
    _likeCount = widget.footprint.likeCount;
  }

  Future<void> _toggleLike() async {
    if (_likeInFlight) return;
    final wasLiked = _likedByMe;
    final previousCount = _likeCount;
    setState(() {
      _likedByMe = !wasLiked;
      _likeCount = previousCount + (wasLiked ? -1 : 1);
      _likeInFlight = true;
    });

    final service = ref.read(footprintServiceProvider);
    try {
      if (wasLiked) {
        await service.unlike(widget.footprint.id);
      } else {
        await service.like(widget.footprint.id);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _likedByMe = wasLiked;
        _likeCount = previousCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('좋아요 처리에 실패했어요.')));
    } finally {
      if (mounted) setState(() => _likeInFlight = false);
    }
  }

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
            InkWell(
              onTap: _toggleLike,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _likedByMe ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: _likedByMe ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text('$_likeCount', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
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
