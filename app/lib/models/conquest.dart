/// 서버 `ConquestResponse`(#51)에 대응하는 지역별 정복률 모델. 지역 단위는 시/군/구.
class ConquestRegion {
  const ConquestRegion({
    required this.regionCode,
    required this.regionName,
    required this.totalSpots,
    required this.visitedSpots,
    required this.rate,
  });

  factory ConquestRegion.fromJson(Map<String, dynamic> json) => ConquestRegion(
        regionCode: json['regionCode'] as String,
        regionName: json['regionName'] as String,
        totalSpots: json['totalSpots'] as int,
        visitedSpots: json['visitedSpots'] as int,
        rate: (json['rate'] as num).toDouble(),
      );

  final String regionCode;
  final String regionName;
  final int totalSpots;
  final int visitedSpots;

  /// 0.0~1.0.
  final double rate;
}

/// [Spot.areaCode]/[Spot.sigunguCode]로부터 서버의 `regionCode` 규칙
/// (`"{areaCode}-{sigunguCode}"`)과 동일한 코드를 만든다.
String regionCodeFor({required String areaCode, String? sigunguCode}) {
  return '$areaCode-${sigunguCode ?? ''}';
}
