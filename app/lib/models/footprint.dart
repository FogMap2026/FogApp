/// 서버 `FootprintResponse`(#1-8, #23)에 대응하는 발자취 모델.
class Footprint {
  const Footprint({
    required this.id,
    required this.userId,
    required this.spotId,
    required this.content,
    required this.likeCount,
    required this.createdAt,
    this.photoUrl,
  });

  factory Footprint.fromJson(Map<String, dynamic> json) => Footprint(
        id: json['id'] as int,
        userId: json['userId'] as int,
        spotId: json['spotId'] as int,
        content: json['content'] as String,
        photoUrl: json['photoUrl'] as String?,
        likeCount: json['likeCount'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final int id;
  final int userId;
  final int spotId;
  final String content;
  final String? photoUrl;
  final int likeCount;
  final DateTime createdAt;
}
