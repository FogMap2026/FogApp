/// 주변 익명 여행자 한 명(#133). 서버가 좌표 대신 스팟 기준으로 환산해 내려준다.
///
/// 여기 담긴 [lat]/[lng]는 여행자 본인의 좌표가 **아니라 스팟의 좌표**다 — 본인
/// 위치는 서버가 저장조차 하지 않는다. `userId`·닉네임은 응답에 아예 없다.
class NearbyTraveler {
  const NearbyTraveler({
    required this.spotId,
    required this.lat,
    required this.lng,
    required this.seenAt,
  });

  final int spotId;
  final double lat;
  final double lng;

  /// 서버가 30분 이상 지난 것만 돌려준다 — 실시간이 아니다("~분 전" 표시에 쓴다).
  final DateTime seenAt;

  factory NearbyTraveler.fromJson(Map<String, dynamic> json) {
    return NearbyTraveler(
      spotId: json['spotId'] as int,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      seenAt: DateTime.parse(json['seenAt'] as String),
    );
  }
}
