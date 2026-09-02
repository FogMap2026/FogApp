import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/match.dart';
import '../services/match_service.dart';

/// 내 매칭 목록 화면(5-2). 보낸 요청·받은 요청을 함께 보여주고, 받은 요청은
/// 수락·거절을, 대기 중인 요청은 취소를 할 수 있다.
class MatchListScreen extends ConsumerStatefulWidget {
  const MatchListScreen({super.key});

  @override
  ConsumerState<MatchListScreen> createState() => _MatchListScreenState();
}

class _MatchListScreenState extends ConsumerState<MatchListScreen> {
  late Future<List<Match>> _matchesFuture;

  /// 처리 중인 매칭 id — 연타로 같은 요청을 중복으로 보내는 걸 막는다.
  final Set<int> _pendingActionIds = {};

  @override
  void initState() {
    super.initState();
    _matchesFuture = _load();
  }

  Future<List<Match>> _load() {
    return ref.read(matchServiceProvider).listForUser();
  }

  void _refresh() {
    setState(() => _matchesFuture = _load());
  }

  Future<void> _respond(Match match, String status) async {
    if (_pendingActionIds.contains(match.id)) return;
    setState(() => _pendingActionIds.add(match.id));
    try {
      await ref.read(matchServiceProvider).updateStatus(matchId: match.id, status: status);
      if (mounted) _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('처리하지 못했어요.')));
      }
    } finally {
      if (mounted) setState(() => _pendingActionIds.remove(match.id));
    }
  }

  Future<void> _cancel(Match match) async {
    if (_pendingActionIds.contains(match.id)) return;
    setState(() => _pendingActionIds.add(match.id));
    try {
      await ref.read(matchServiceProvider).cancel(match.id);
      if (mounted) _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('취소하지 못했어요.')));
      }
    } finally {
      if (mounted) setState(() => _pendingActionIds.remove(match.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 동행 요청')),
      body: SafeArea(
        child: FutureBuilder<List<Match>>(
          future: _matchesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('매칭 목록을 불러오지 못했어요.'),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _refresh, child: const Text('다시 시도')),
                  ],
                ),
              );
            }
            final matches = snapshot.data!;
            if (matches.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('아직 동행 요청이 없어요.', textAlign: TextAlign.center),
                ),
              );
            }

            final received = matches.where((m) => !m.isSent).toList();
            final sent = matches.where((m) => m.isSent).toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (received.isNotEmpty) ...[
                  Text('받은 요청', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final match in received)
                    _MatchCard(
                      match: match,
                      busy: _pendingActionIds.contains(match.id),
                      onAccept: () => _respond(match, 'accepted'),
                      onReject: () => _respond(match, 'rejected'),
                    ),
                  const SizedBox(height: 24),
                ],
                if (sent.isNotEmpty) ...[
                  Text('보낸 요청', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final match in sent)
                    _MatchCard(
                      match: match,
                      busy: _pendingActionIds.contains(match.id),
                      onCancel: () => _cancel(match),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match, required this.busy, this.onAccept, this.onReject, this.onCancel});

  final Match match;
  final bool busy;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.person_outline, color: Colors.black45),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(match.counterpartLabel, style: theme.textTheme.titleSmall),
                  Text(
                    _statusLabel(match.status),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (busy)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            else if (!match.isPending)
              const SizedBox.shrink()
            else if (onAccept != null && onReject != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(onPressed: onReject, icon: const Icon(Icons.close), tooltip: '거절'),
                  IconButton(onPressed: onAccept, icon: const Icon(Icons.check), tooltip: '수락'),
                ],
              )
            else if (onCancel != null)
              TextButton(onPressed: onCancel, child: const Text('취소')),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return '수락됨';
      case 'rejected':
        return '거절됨';
      default:
        return '대기 중';
    }
  }
}
