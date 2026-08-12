/// 서버 `FootprintResponse`(#1-8, #23, #71, #72)에 대응하는 발자취 모델.
class Footprint {
  const Footprint({
    required this.id,
    required this.userId,
    required this.spotId,
    required this.content,
    required this.likeCount,
    required this.likedByMe,
    required this.createdAt,
    this.authorNickname,
    this.authorProfileImageUrl,
    this.photoUrl,
  });

  factory Footprint.fromJson(Map<String, dynamic> json) => Footprint(
        id: json['id'] as int,
        userId: json['userId'] as int,
        authorNickname: json['authorNickname'] as String?,
        authorProfileImageUrl: json['authorProfileImageUrl'] as String?,
        spotId: json['spotId'] as int,
        content: json['content'] as String,
        photoUrl: json['photoUrl'] as String?,
        likeCount: json['likeCount'] as int,
        likedByMe: json['likedByMe'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final int id;
  final int userId;

  /// 작성자 닉네임. 탈퇴 등으로 작성자를 찾지 못하면 null이다(#71).
  final String? authorNickname;

  /// 작성자 프로필 이미지 URL. 위와 같은 이유로 null일 수 있다(#71).
  final String? authorProfileImageUrl;

  final int spotId;
  final String content;
  final String? photoUrl;
  final int likeCount;

  /// 로그인한 사용자가 이 발자취에 좋아요를 눌렀는지(#72).
  final bool likedByMe;

  final DateTime createdAt;
}
