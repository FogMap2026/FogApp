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

  /// 수락됨 = 친구. 친구 목록에 뜨고 메시지를 주고받을 수 있다.
  bool get isAccepted => status == 'accepted';

  /// 친구 목록 — 수락된 매칭을 상대방 한 명당 하나로.
  ///
  /// 서버는 A→B 와 B→A 를 서로 다른 매칭으로 받아준다(`UNIQUE (requester_id, addressee_id)`).
  /// 둘 다 수락되면 같은 친구가 두 줄로 뜨므로, 상대방마다 가장 먼저 맺어진 것 하나만 남긴다 —
  /// 대화방은 매칭 한 건이라, 늘 같은 방이 열리게.
  static List<Match> friendsOf(List<Match> matches) {
    final accepted = matches.where((m) => m.isAccepted).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final byCounterpart = <int, Match>{};
    for (final match in accepted) {
      byCounterpart.putIfAbsent(match.counterpartId, () => match);
    }
    return byCounterpart.values.toList();
  }

  /// 친구 요청 탭에 남길 것 — 이미 친구가 된 상대와의 매칭은 뺀다(친구 목록으로 옮겨 갔다).
  static List<Match> requestsOf(List<Match> matches) {
    final friendIds = friendsOf(matches).map((m) => m.counterpartId).toSet();
    return matches.where((m) => !m.isAccepted && !friendIds.contains(m.counterpartId)).toList();
  }

  /// 카드에 표시할 상대방 이름. 닉네임이 없으면 대체 문구를 쓴다.
  String get counterpartLabel =>
      (counterpartNickname != null && counterpartNickname!.isNotEmpty) ? counterpartNickname! : '이름 없는 여행자';
}
