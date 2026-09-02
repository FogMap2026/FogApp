import 'personality.dart';

/// 서버 `ProfileResponse`(#4, 5-3)에 대응하는 내 프로필 모델. 본인 것만 조회할 수 있다.
///
/// [personalityType]이 null이면 성향 테스트를 아직 안 한 것이다 — 화면에서 테스트
/// 유도 안내로 분기할 것.
class Profile {
  const Profile({
    required this.id,
    required this.email,
    this.nickname,
    this.profileImageUrl,
    this.personalityType,
    this.personalityScores = const {},
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as int,
        email: json['email'] as String,
        nickname: json['nickname'] as String?,
        profileImageUrl: json['profileImageUrl'] as String?,
        personalityType: json['personalityType'] as String?,
        personalityScores: axisScoresFromJson(
          (json['personalityScores'] as Map<String, dynamic>?) ?? const {},
        ),
      );

  final int id;
  final String email;
  final String? nickname;
  final String? profileImageUrl;
  final String? personalityType;
  final Map<PersonalityAxis, int> personalityScores;
}
