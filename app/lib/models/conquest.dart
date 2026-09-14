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

/// [regionCodeFor]의 반대 — [ConquestRegion.regionCode]를 시/도 코드와 시/군/구
/// 코드로 나눈다. 시/군/구 코드가 없던 그룹은 규칙대로 빈 문자열이 되는데, 스팟
/// 조회 쪽(`Spot.sigunguCode`)에서는 그 자리가 `null`이므로 여기서도 `null`로 맞춘다.
({String areaCode, String? sigunguCode}) splitRegionCode(String regionCode) {
  final i = regionCode.indexOf('-');
  if (i < 0) return (areaCode: regionCode, sigunguCode: null);
  final sigungu = regionCode.substring(i + 1);
  return (areaCode: regionCode.substring(0, i), sigunguCode: sigungu.isEmpty ? null : sigungu);
}
