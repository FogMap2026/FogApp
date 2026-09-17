import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../models/match.dart';
import '../services/message_service.dart';
import '../theme/app_theme.dart';

/// 친구와 주고받는 메시지 화면. 대화방은 수락된 매칭 [friend] 한 건이다.
///
/// 실시간 연결이 없어서 **이 화면이 떠 있는 동안만** [pollInterval]마다 새 메시지를 묻는다
/// (마지막으로 받은 id 이후만). 앱이 백그라운드로 가면 멈추고 돌아오면 다시 켠다 — 화면을 안 보는
/// 동안 요청을 보낼 이유가 없다(#229 리뷰의 발자취 타이머와 같은 원칙). 푸시 알림은 #134(FCM).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.friend, super.key});

  final Match friend;

  /// 대화방이 열려 있을 때 새 메시지를 묻는 주기.
  static const pollInterval = Duration(seconds: 5);

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with WidgetsBindingObserver {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  bool _loading = true;
  bool _loadFailed = false;
  bool _sending = false;
  bool _polling = false;
  Timer? _pollTimer;

  /// 서버 조회(첫 로드·주기 조회)로 받은 가장 큰 id — 다음 조회의 `afterId`.
  ///
  /// ⚠️ **내가 보낸 메시지로는 옮기지 않는다.** 목록 끝(`_messages.last.id`)을 커서로 쓰면, 친구가 보낸
  /// 11 을 아직 조회하기 전에 내가 12 를 보냈을 때 커서가 12 로 건너뛰어 11 이 영영 안 온다(#235 리뷰,
  /// oorony). 보낸 메시지는 표시만 하고, 다음 조회에서 다시 오면 [_append] 의 중복 제거가 걸러 준다.
  int? _cursorId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitial();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      unawaited(_poll()); // 백그라운드에 있던 동안 온 것
    } else if (state == AppLifecycleState.paused) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final messages = await ref.read(messageServiceProvider).list(matchId: widget.friend.id);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
        _cursorId = messages.isEmpty ? null : messages.last.id;
        _loading = false;
      });
      _scrollToBottom();
      _startPolling();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  void _startPolling() {
    if (_loading || _loadFailed) return;
    _pollTimer ??= Timer.periodic(ChatScreen.pollInterval, (_) => _poll());
  }

  Future<void> _poll() async {
    if (_polling || _loading || _loadFailed) return;
    _polling = true;
    try {
      final incoming = await ref.read(messageServiceProvider).list(matchId: widget.friend.id, afterId: _cursorId);
      if (!mounted || incoming.isEmpty) return;
      _cursorId = incoming.last.id; // 서버가 id 오름차순으로 준다
      _append(incoming);
    } catch (e) {
      // 한 번 실패해도 다음 주기에 다시 묻는다 — 화면을 막지 않는다.
      debugPrint('[ChatScreen] 새 메시지 조회 실패: $e');
    } finally {
      _polling = false;
    }
  }

  /// 이미 있는 id 는 건너뛴다 — 내가 보낸 메시지가 전송 응답과 주기 조회로 두 번 온다([_cursorId] 참고).
  void _append(List<ChatMessage> incoming) {
    final known = _messages.map((m) => m.id).toSet();
    final fresh = incoming.where((m) => !known.contains(m.id)).toList();
    if (fresh.isEmpty) return;
    setState(() {
      _messages
        ..addAll(fresh)
        ..sort((a, b) => a.id.compareTo(b.id));
    });
    _scrollToBottom();
  }

  Future<void> _send() async {
    final content = _inputController.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final sent = await ref.read(messageServiceProvider).send(matchId: widget.friend.id, content: content);
      if (!mounted) return;
      _inputController.clear();
      _append([sent]);
    } on DioException catch (e) {
      if (!mounted) return;
      final message = e.response?.statusCode == 403
          ? '친구가 아니어서 메시지를 보낼 수 없어요.'
          : '메시지를 보내지 못했어요. 네트워크를 확인해주세요.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('메시지를 보내지 못했어요.')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.friend.counterpartLabel)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildMessages(context)),
            const Divider(height: 1),
            _buildInput(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadFailed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('메시지를 불러오지 못했어요.'),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadInitial, child: const Text('다시 시도')),
          ],
        ),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '${widget.friend.counterpartLabel}님에게 첫 메시지를 보내보세요.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _Bubble(message: _messages[index]),
    );
  }

  Widget _buildInput(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              minLines: 1,
              maxLines: 4,
              maxLength: ChatMessage.maxLength,
              textInputAction: TextInputAction.newline,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: '메시지 보내기',
                counterText: '',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: (_inputController.text.trim().isEmpty || _sending || _loading || _loadFailed) ? null : _send,
            icon: _sending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send),
            tooltip: '보내기',
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = message.mine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : AppColors.buttonSecondary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: theme.textTheme.bodyMedium?.copyWith(color: mine ? Colors.white : AppColors.ink),
            ),
            const SizedBox(height: 2),
            Text(
              _timeLabel(message.createdAt),
              style: theme.textTheme.labelSmall?.copyWith(
                // 흰 70% 는 파랑 위 대비 약 3:1 이라 작은 글씨로는 흐리다 — 흰색 그대로 4.6:1(#235 리뷰).
                color: mine ? Colors.white : AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 오늘이면 「오후 3:05」, 아니면 「9/14 오후 3:05」.
  static String _timeLabel(DateTime createdAt) {
    final local = createdAt.toLocal();
    final now = DateTime.now();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final time = '${local.hour < 12 ? '오전' : '오후'} $hour12:${local.minute.toString().padLeft(2, '0')}';
    final today = local.year == now.year && local.month == now.month && local.day == now.day;
    return today ? time : '${local.month}/${local.day} $time';
  }
}
