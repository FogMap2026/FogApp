/// 서버 `SpotResponse`(#7, #50)에 대응하는 스팟 모델.
///
/// [overview](소개)는 **해금된 스팟에서만 채워진다** — 서버가 잠긴 스팟에는
/// 아예 내려주지 않는다. 앱에서만 가리면 API 직접 호출로 우회되기 때문이다.
/// 따라서 [unlocked]가 false면 [overview]는 항상 null이다.
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
    this.overview,
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
        overview: json['overview'] as String?,
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

  /// 스팟 소개. 해금 전에는 서버가 내려주지 않으므로 null이다(#50).
  final String? overview;

  final double lat;
  final double lng;
  final bool unlocked;
}
