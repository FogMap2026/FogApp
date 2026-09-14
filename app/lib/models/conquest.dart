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

/// 시/도 단위로 합산한 정복률 — 지도 상단 바가 쓴다.
///
/// 서버는 시/군/구 단위로 내려주지만(`ConquestRepository`), 상단 바에 뜨는 지역명은
/// 역지오코딩의 시/도(「경기도」·「인천광역시」)다. 바 옆의 퍼센트도 **그 이름과 같은
/// 단위**여야 읽는 사람이 헷갈리지 않는다 — 「경기도 · 정복률 15%」인데 실제로는 부천시
/// 비율이면 다른 시로 넘어갈 때 숫자가 이유 없이 널뛴다.
///
/// 시/군/구 목록은 그대로 둔다 — 전국 정복 현황 화면(#215)이 그 단위로 쓴다.
class ConquestSido {
  const ConquestSido({
    required this.areaCode,
    required this.sidoName,
    required this.totalSpots,
    required this.visitedSpots,
  });

  /// 관광공사 지역 코드(`Spot.areaCode`). `regionCode` 의 `-` 앞부분과 같다.
  final String areaCode;

  /// 서버 `regionName`(「경기도 부천시」)의 첫 토큰. 이름을 못 만든 지역(코드 폴백)은 빈 문자열.
  final String sidoName;
  final int totalSpots;
  final int visitedSpots;

  /// 0.0~1.0. 시/군/구 비율의 평균이 아니라 **합산 후 나눈 값**이다 — 스팟 3개짜리
  /// 군과 300개짜리 시가 같은 무게로 섞이면 안 된다.
  double get rate => totalSpots == 0 ? 0 : visitedSpots / totalSpots;
}

/// 시/군/구 목록을 시/도별로 합산한다. 순서는 입력에 처음 나타난 시/도 순.
List<ConquestSido> aggregateBySido(List<ConquestRegion> regions) {
  final byArea = <String, ConquestSido>{};
  for (final region in regions) {
    final areaCode = region.regionCode.split('-').first;
    // 이름을 못 만든 지역은 regionName 이 코드(「35-2」)라 첫 토큰이 시/도가 아니다.
    final sidoName = region.regionName == region.regionCode ? '' : region.regionName.split(' ').first;
    final prev = byArea[areaCode];
    byArea[areaCode] = ConquestSido(
      areaCode: areaCode,
      sidoName: (prev == null || prev.sidoName.isEmpty) ? sidoName : prev.sidoName,
      totalSpots: (prev?.totalSpots ?? 0) + region.totalSpots,
      visitedSpots: (prev?.visitedSpots ?? 0) + region.visitedSpots,
    );
  }
  return byArea.values.toList();
}

/// 시/도 이름 비교용 정규화. 역지오코딩과 관광공사 주소가 같은 곳을 다르게 부른다 —
/// 「강원특별자치도」/「강원도」, 「전북특별자치도」/「전라북도」. 행정 접미어를 떼고
/// 줄임말을 펴서 「강원」·「전라북」으로 맞춘다.
String normalizeSidoName(String name) {
  var s = name.trim();
  for (final suffix in const ['특별자치도', '특별자치시', '특별시', '광역시', '도', '시']) {
    if (s.endsWith(suffix) && s.length > suffix.length) {
      s = s.substring(0, s.length - suffix.length);
      break;
    }
  }
  const aliases = {'전북': '전라북', '전남': '전라남', '경북': '경상북', '경남': '경상남', '충북': '충청북', '충남': '충청남'};
  return aliases[s] ?? s;
}

/// 상단 바에 보여줄 시/도 정복률. 먼저 **바에 뜬 이름**([regionName])으로 찾고, 이름이
/// 없거나 안 맞으면 가장 가까운 스팟의 [areaCode]로 찾는다 — 역지오코딩과 관광공사
/// 주소가 끝내 안 맞는 곳(주소 품질 문제로 코드만 남은 지역 등)의 안전망이다.
ConquestSido? findSidoConquest(List<ConquestSido> sidos, {String? regionName, String? areaCode}) {
  if (regionName != null) {
    final wanted = normalizeSidoName(regionName);
    for (final sido in sidos) {
      if (sido.sidoName.isNotEmpty && normalizeSidoName(sido.sidoName) == wanted) return sido;
    }
  }
  if (areaCode != null) {
    for (final sido in sidos) {
      if (sido.areaCode == areaCode) return sido;
    }
  }
  return null;
}
