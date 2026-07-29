/// 서버 `SpotResponse`(#7)에 대응하는 스팟 모델.
class Spot {
  const Spot({
    required this.id,
    required this.contentId,
    required this.title,
    required this.lat,
    required this.lng,
    required this.unlocked,
    this.contentTypeId,
    this.addr1,
    this.addr2,
    this.areaCode,
    this.sigunguCode,
    this.firstImage,
  });

  factory Spot.fromJson(Map<String, dynamic> json) => Spot(
        id: json['id'] as int,
        contentId: json['contentId'] as String,
        contentTypeId: json['contentTypeId'] as String?,
        title: json['title'] as String,
        addr1: json['addr1'] as String?,
        addr2: json['addr2'] as String?,
        areaCode: json['areaCode'] as String?,
        sigunguCode: json['sigunguCode'] as String?,
        firstImage: json['firstImage'] as String?,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        unlocked: json['unlocked'] as bool? ?? false,
      );

  final int id;
  final String contentId;
  final String? contentTypeId;
  final String title;
  final String? addr1;
  final String? addr2;
  final String? areaCode;
  final String? sigunguCode;
  final String? firstImage;
  final double lat;
  final double lng;
  final bool unlocked;
}
