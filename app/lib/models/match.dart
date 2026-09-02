/// 서버 `MatchResponse`(#1-8, 5-2)에 대응하는 매칭(동행 요청) 모델.
///
/// [direction]은 서버가 로그인 사용자 기준으로 미리 계산해 내려준다 — "SENT"면 내가
/// 보낸 요청, "RECEIVED"면 내가 받은 요청이다. [counterpartId]도 같은 기준으로,
/// requesterId/addresseeId 중 내가 아닌 쪽이다.
class Match {
  const Match({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    required this.status,
    required this.direction,
    required this.counterpartId,
    required this.createdAt,
    this.score,
    this.counterpartNickname,
    this.counterpartProfileImageUrl,
  });

  factory Match.fromJson(Map<String, dynamic> json) => Match(
        id: json['id'] as int,
        requesterId: json['requesterId'] as int,
        addresseeId: json['addresseeId'] as int,
        status: json['status'] as String,
        score: (json['score'] as num?)?.toDouble(),
        direction: json['direction'] as String,
        counterpartId: json['counterpartId'] as int,
        counterpartNickname: json['counterpartNickname'] as String?,
        counterpartProfileImageUrl: json['counterpartProfileImageUrl'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final int id;
  final int requesterId;
  final int addresseeId;

  /// "pending" | "accepted" | "rejected" — 서버 값 그대로(소문자).
  final String status;

  final double? score;

  /// "SENT" | "RECEIVED".
  final String direction;

  final int counterpartId;
  final String? counterpartNickname;
  final String? counterpartProfileImageUrl;
  final DateTime createdAt;

  bool get isSent => direction == 'SENT';
  bool get isPending => status == 'pending';

  /// 카드에 표시할 상대방 이름. 닉네임이 없으면 대체 문구를 쓴다.
  String get counterpartLabel =>
      (counterpartNickname != null && counterpartNickname!.isNotEmpty) ? counterpartNickname! : '이름 없는 여행자';
}
