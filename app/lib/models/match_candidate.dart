/// 서버 `MatchCandidate`(#37, 5-1)에 대응하는 동행 추천 후보.
///
/// 닉네임·유사도만 있다 — 프로필 이미지·성향 유형 코드는 서버 응답에 없다.
/// (있으면 카드가 더 풍부해지겠지만, 이 스코프에서는 없이 진행한다.)
class MatchCandidate {
  const MatchCandidate({required this.userId, required this.similarity, this.nickname});

  factory MatchCandidate.fromJson(Map<String, dynamic> json) => MatchCandidate(
        userId: json['userId'] as int,
        nickname: json['nickname'] as String?,
        similarity: (json['similarity'] as num).toDouble(),
      );

  final int userId;

  /// 후보의 닉네임. **null일 수 있다** — 서버가 `User.nickname`을 그대로 내려주는데
  /// 가입 직후 닉네임을 정하지 않은 사용자가 있다([Footprint.authorNickname]과 같은 이유).
  /// 화면에는 [nicknameLabel]을 쓸 것.
  final String? nickname;

  /// 0~1. 1에 가까울수록 성향이 비슷하다.
  final double similarity;

  /// 카드에 표시할 이름. 닉네임이 없으면 대체 문구를 쓴다 —
  /// [Footprint.authorLabel]과 같은 문구를 써서 화면마다 다르게 부르지 않는다.
  String get nicknameLabel =>
      (nickname != null && nickname!.isNotEmpty) ? nickname! : '이름 없는 여행자';
}
