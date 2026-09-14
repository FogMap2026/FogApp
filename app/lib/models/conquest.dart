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
    required this.areaCodes,
    required this.sidoName,
    required this.totalSpots,
    required this.visitedSpots,
  });

  /// 이 시/도에 속한 관광공사 지역 코드(`Spot.areaCode`) — **여럿일 수 있다.**
  ///
  /// 관광공사 코드는 옛 행정구역이고 주소는 현재 행정구역이다. 2026 광주·전남 통합 뒤
  /// 주소는 둘 다 「전남광주통합특별시」인데 코드는 광주(5)·전남(38)로 남아 있어,
  /// 코드로 묶으면 같은 이름 배지가 둘 뜬다(실기기, 09-14). 그래서 **이름으로 묶고**
  /// 코드는 목록으로 들고 있다 — 상세 화면이 스팟을 부를 때 전부 돈다.
  final List<String> areaCodes;

  /// 서버 `regionName`(「경기도 부천시」)의 첫 토큰. 이름을 못 만든 지역(코드 폴백)은 빈 문자열.
  final String sidoName;
  final int totalSpots;
  final int visitedSpots;

  /// 0.0~1.0. 시/군/구 비율의 평균이 아니라 **합산 후 나눈 값**이다 — 스팟 3개짜리
  /// 군과 300개짜리 시가 같은 무게로 섞이면 안 된다.
  double get rate => totalSpots == 0 ? 0 : visitedSpots / totalSpots;
}

/// 시/군/구 목록을 시/도별로 합산한다. 순서는 입력에 처음 나타난 시/도 순.
///
/// **관광공사 지역 코드(areaCode)마다 «주인» 시/도를 정하고, 그 코드의 시/군/구는 전부
/// 주인에게 준다.** 주인은 그 코드 안에서 스팟이 가장 많은 이름이다.
///
/// 왜 이름만으로 묶지 않나 — 관광공사 데이터는 «코드는 충남(34)인데 주소는 대전»처럼
/// 코드와 주소가 어긋난 스팟이 소수 섞여 있다. 이름으로만 묶으면 그 소수가 대전 배지에
/// 코드 34 를 끼워 넣고, 이름 없는 34 그룹(주소가 빈 스팟)이 충남이 아니라 대전에 붙는다
/// — 실기기에서 충남 1000 → 1199, 전남광주 1198 → 999 로 199개가 엉뚱한 데 갔다.
/// 코드 주인으로 묶으면 배지 합계가 상세 화면(코드로 스팟을 받는다)과도 정확히 맞는다.
///
/// 통합된 시/도(「전남광주통합특별시」)는 코드 둘(광주 5 · 전남 38)의 주인이 같은 이름이라
/// 배지 하나가 되고([ConquestSido.areaCodes] 둘), 이름을 끝내 못 만든 코드(주소가 전부
/// 빈 경우)만 코드 배지로 남는다.
List<ConquestSido> aggregateBySido(List<ConquestRegion> regions) {
  // 코드 → (정규화 이름 → 스팟 수). 이름 없는 시/군/구는 세지 않는다.
  final votes = <String, Map<String, int>>{};
  // 정규화 이름 → 처음 본 표시 이름.
  final displayName = <String, String>{};
  for (final region in regions) {
    final areaCode = region.regionCode.split('-').first;
    // 이름을 못 만든 지역은 regionName 이 코드(「35-2」)라 첫 토큰이 시/도가 아니다.
    final sidoName = region.regionName == region.regionCode ? '' : region.regionName.split(' ').first;
    if (sidoName.isEmpty) continue;
    final key = normalizeSidoName(sidoName);
    displayName.putIfAbsent(key, () => sidoName);
    votes.putIfAbsent(areaCode, () => {}).update(key, (n) => n + region.totalSpots, ifAbsent: () => region.totalSpots);
  }

  // 코드 → 주인 키. 주인이 없으면(그 코드에 이름 있는 시/군/구가 하나도 없으면) 코드 자신.
  String ownerOf(String areaCode) {
    final v = votes[areaCode];
    if (v == null || v.isEmpty) return 'code:$areaCode';
    return v.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  final byOwner = <String, ConquestSido>{};
  for (final region in regions) {
    final areaCode = region.regionCode.split('-').first;
    final owner = ownerOf(areaCode);
    final prev = byOwner[owner];
    byOwner[owner] = ConquestSido(
      areaCodes: prev == null
          ? [areaCode]
          : (prev.areaCodes.contains(areaCode) ? prev.areaCodes : [...prev.areaCodes, areaCode]),
      sidoName: displayName[owner] ?? '',
      totalSpots: (prev?.totalSpots ?? 0) + region.totalSpots,
      visitedSpots: (prev?.visitedSpots ?? 0) + region.visitedSpots,
    );
  }
  return byOwner.values.toList();
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
      if (sido.areaCodes.contains(areaCode)) return sido;
    }
  }
  return null;
}

/// 경계 데이터의 시/도 이름(2013 통계청 — 「광주광역시」·「전라남도」)을 배지에 맞춘다.
///
/// 이름이 같으면 그대로. 통합된 시/도(「전남광주통합특별시」)는 옛 이름 둘이 하나의 배지에
/// 들어가야 하므로, 배지 이름이 옛 이름의 **줄임말**(광주 · 전남)을 품고 있으면 그 배지다.
/// 이러면 경계 데이터를 행정구역 개편 때마다 다시 그리지 않아도 된다 — 옛 폴리곤 둘을
/// 같은 색으로 칠하면 된다.
ConquestSido? matchSidoForProvince(List<ConquestSido> sidos, String provinceName) {
  final wanted = normalizeSidoName(provinceName);
  for (final sido in sidos) {
    if (sido.sidoName.isNotEmpty && normalizeSidoName(sido.sidoName) == wanted) return sido;
  }
  final short = _shortSidoName(wanted);
  for (final sido in sidos) {
    if (sido.sidoName.isEmpty) continue;
    final badge = normalizeSidoName(sido.sidoName);
    // 배지 이름이 옛 이름보다 길고(통합), 그 안에 옛 이름의 줄임말이 들어 있다.
    if (badge.length > short.length && badge.contains(short)) return sido;
  }
  return null;
}

/// 「전라남」→「전남」처럼 정규화된 이름의 줄임말. 줄임말이 없으면 그대로.
String _shortSidoName(String normalized) {
  const shorts = {'전라북': '전북', '전라남': '전남', '경상북': '경북', '경상남': '경남', '충청북': '충북', '충청남': '충남'};
  return shorts[normalized] ?? normalized;
}
