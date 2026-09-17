import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/match.dart';
import '../services/match_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';

/// 친구 화면의 「친구」 탭 — 친구 요청이 수락된 상대 목록. 누르면 메시지 화면([ChatScreen])이 열린다.
///
/// 친구는 따로 저장하지 않는다. 수락된 매칭이 곧 친구라 `GET /api/matches` 를 걸러 쓴다
/// ([Match.friendsOf]).
class FriendsListTab extends ConsumerStatefulWidget {
  const FriendsListTab({super.key});

  @override
  ConsumerState<FriendsListTab> createState() => _FriendsListTabState();
}

class _FriendsListTabState extends ConsumerState<FriendsListTab> {
  late Future<List<Match>> _friendsFuture;

  @override
  void initState() {
    super.initState();
    _friendsFuture = _load();
  }

  Future<List<Match>> _load() async => Match.friendsOf(await ref.read(matchServiceProvider).listForUser());

  void _refresh() => setState(() => _friendsFuture = _load());

  Future<void> _unfriend(Match friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('친구 끊기'),
        content: Text('${friend.counterpartLabel}님과 친구를 끊을까요?\n주고받은 메시지도 모두 지워지고 되돌릴 수 없어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('끊기')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      // 🔴 그 상대와의 매칭을 «전부» 지운다. 서버는 같은 방향 중복만 막아서(#52 `request`)
      // 둘이 서로 요청해 각자 수락하면 수락된 매칭이 둘이 된다. 보이는 한 건만 지우면 목록을
      // 새로 고쳤을 때 같은 친구가 빈 대화방으로 다시 떠서 «끊기가 안 된다»로 보인다(#235 리뷰,
      // PGH0621). 대화는 매칭에 달려 있으니 지워진 매칭의 메시지도 함께 파기된다.
      final matches = await ref.read(matchServiceProvider).listForUser();
      final service = ref.read(matchServiceProvider);
      for (final match in matches.where((m) => m.counterpartId == friend.counterpartId)) {
        await service.cancel(match.id);
      }
      if (mounted) _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('친구를 끊지 못했어요.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Match>>(
      future: _friendsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('친구 목록을 불러오지 못했어요.'),
                const SizedBox(height: 8),
                TextButton(onPressed: _refresh, child: const Text('다시 시도')),
              ],
            ),
          );
        }
        final friends = snapshot.data!;
        if (friends.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                '아직 친구가 없어요.\n「추천 친구」에서 친구 요청을 보내보세요.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            _refresh();
            await _friendsFuture;
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: friends.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final friend = friends[index];
              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.person_outline, color: AppColors.inkMuted),
                  ),
                  title: Text(friend.counterpartLabel),
                  subtitle: const Text('눌러서 메시지 보내기'),
                  trailing: const Icon(Icons.chat_bubble_outline),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ChatScreen(friend: friend)),
                  ),
                  onLongPress: () => _unfriend(friend),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
