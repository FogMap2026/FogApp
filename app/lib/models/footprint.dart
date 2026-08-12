/// 서버 `FootprintResponse`(#1-8, #23, #71)에 대응하는 발자취 모델.
///
/// 작성자 정보([authorNickname]·[authorProfileImageUrl])는 목록 응답에 함께 담겨 온다.
/// 카드마다 프로필을 따로 조회하지 않아도 되고, 애초에 남의 프로필을 조회하는 API는 없다.
class Footprint {
  const Footprint({
    required this.id,
    required this.userId,
    required this.spotId,
    required this.content,
    required this.likeCount,
    required this.createdAt,
    this.photoUrl,
    this.authorNickname,
    this.authorProfileImageUrl,
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
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final int id;
  final int userId;

  /// 작성자 닉네임. 닉네임을 정하지 않은 사용자가 있어 null일 수 있다 — [authorLabel]을 쓸 것.
  final String? authorNickname;

  final String? authorProfileImageUrl;
  final int spotId;
  final String content;
  final String? photoUrl;
  final int likeCount;
  final DateTime createdAt;

  /// 카드에 표시할 작성자 이름. 닉네임이 없으면 대체 문구를 쓴다.
  String get authorLabel =>
      (authorNickname != null && authorNickname!.isNotEmpty) ? authorNickname! : '이름 없는 여행자';
}
