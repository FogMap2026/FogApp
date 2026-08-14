/// 서버 `ProfileResponse`(#4)에 대응하는 내 프로필 모델. 본인 것만 조회할 수 있다.
class Profile {
  const Profile({
    required this.id,
    required this.email,
    this.nickname,
    this.profileImageUrl,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as int,
        email: json['email'] as String,
        nickname: json['nickname'] as String?,
        profileImageUrl: json['profileImageUrl'] as String?,
      );

  final int id;
  final String email;
  final String? nickname;
  final String? profileImageUrl;
}
