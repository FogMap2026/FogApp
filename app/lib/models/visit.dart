/// 서버 `VisitResponse`(#48)에 대응하는 방문 인증 모델.
class Visit {
  const Visit({
    required this.id,
    required this.userId,
    required this.spotId,
    required this.photoUrl,
    required this.lat,
    required this.lng,
    required this.verifiedAt,
  });

  factory Visit.fromJson(Map<String, dynamic> json) => Visit(
        id: json['id'] as int,
        userId: json['userId'] as int,
        spotId: json['spotId'] as int,
        photoUrl: json['photoUrl'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        verifiedAt: DateTime.parse(json['verifiedAt'] as String),
      );

  final int id;
  final int userId;
  final int spotId;
  final String photoUrl;
  final double lat;
  final double lng;
  final DateTime verifiedAt;
}
