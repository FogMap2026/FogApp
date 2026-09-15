/// 서버 `MessageResponse`에 대응하는 친구 메시지 한 건.
///
/// [mine]은 서버가 로그인 사용자 기준으로 미리 계산해 내려준다 — 말풍선을 좌우로 가르려고
/// 내 사용자 id를 따로 알 필요가 없다(`Match.direction`과 같은 방식).
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.matchId,
    required this.mine,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as int,
        matchId: json['matchId'] as int,
        mine: json['mine'] as bool,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  /// 서버가 받아주는 최대 길이 — `Message.MAX_LENGTH`와 같아야 한다.
  static const maxLength = 1000;

  final int id;
  final int matchId;
  final bool mine;
  final String content;
  final DateTime createdAt;
}
