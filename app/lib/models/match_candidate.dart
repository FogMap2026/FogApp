/// 서버 `MatchCandidate`(#37, 5-1)에 대응하는 동행 추천 후보.
///
/// 닉네임·유사도만 있다 — 프로필 이미지·성향 유형 코드는 서버 응답에 없다.
/// (있으면 카드가 더 풍부해지겠지만, 이 스코프에서는 없이 진행한다.)
class MatchCandidate {
  const MatchCandidate({required this.userId, required this.nickname, required this.similarity});

  factory MatchCandidate.fromJson(Map<String, dynamic> json) => MatchCandidate(
        userId: json['userId'] as int,
        nickname: json['nickname'] as String,
        similarity: (json['similarity'] as num).toDouble(),
      );

  final int userId;
  final String nickname;

  /// 0~1. 1에 가까울수록 성향이 비슷하다.
  final double similarity;
}
