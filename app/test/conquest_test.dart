import 'package:flutter_test/flutter_test.dart';
import 'package:fogapp/models/conquest.dart';

void main() {
  test('sigunguCode가 있으면 areaCode-sigunguCode 형태가 된다', () {
    expect(regionCodeFor(areaCode: '35', sigunguCode: '2'), '35-2');
  });

  test('sigunguCode가 없으면 뒤에 하이픈만 붙는다 (서버 규칙과 동일)', () {
    expect(regionCodeFor(areaCode: '35'), '35-');
    expect(regionCodeFor(areaCode: '35', sigunguCode: null), '35-');
  });

  test('ConquestRegion.fromJson이 서버 응답 필드를 그대로 매핑한다', () {
    final region = ConquestRegion.fromJson({
      'regionCode': '35-2',
      'regionName': '경상북도 경주시',
      'totalSpots': 412,
      'visitedSpots': 61,
      'rate': 0.148,
    });

    expect(region.regionCode, '35-2');
    expect(region.regionName, '경상북도 경주시');
    expect(region.totalSpots, 412);
    expect(region.visitedSpots, 61);
    expect(region.rate, 0.148);
  });

  _sidoTests();
  _provinceTests();
}

ConquestRegion _region(String code, String name, int total, int visited) => ConquestRegion(
      regionCode: code,
      regionName: name,
      totalSpots: total,
      visitedSpots: visited,
      rate: total == 0 ? 0 : visited / total,
    );

void _sidoTests() {
  test('시/군/구를 시/도로 합산한다 — 비율의 평균이 아니라 합산 후 나눈 값', () {
    // 부천 3/3(100%) + 수원 0/300(0%) → 평균이면 50%, 합산이면 1%.
    final sidos = aggregateBySido([
      _region('31-1', '경기도 부천시', 3, 3),
      _region('31-2', '경기도 수원시', 300, 0),
      _region('2-1', '인천광역시 남동구', 10, 5),
    ]);
    final gyeonggi = sidos.singleWhere((s) => s.areaCodes.contains('31'));
    expect(gyeonggi.sidoName, '경기도');
    expect(gyeonggi.totalSpots, 303);
    expect(gyeonggi.visitedSpots, 3);
    expect(gyeonggi.rate, closeTo(0.0099, 0.0001));
    expect(sidos.singleWhere((s) => s.areaCodes.contains('2')).rate, 0.5);
  });

  test('통합된 시/도는 코드가 둘이어도 배지 하나다 — 광주(5)·전남(38) → 전남광주통합특별시', () {
    final sidos = aggregateBySido([
      _region('5-1', '전남광주통합특별시 동구', 100, 10),
      _region('38-3', '전남광주통합특별시 순천시', 200, 0),
      _region('38-4', '전남광주통합특별시 여수시', 100, 10),
    ]);
    final merged = sidos.single;
    expect(merged.areaCodes, ['5', '38']);
    expect(merged.totalSpots, 400);
    expect(merged.visitedSpots, 20);
    expect(findSidoConquest(sidos, areaCode: '38'), same(merged));
  });

  test('이름을 못 만든 지역(코드 폴백)은 시/도 이름을 더럽히지 않는다', () {
    final sidos = aggregateBySido([
      _region('35-9', '35-9', 4, 0), // addr1 이 비어 서버가 코드로 폴백한 지역
      _region('35-2', '경상북도 경주시', 20, 2),
    ]);
    // 같은 코드(35)의 이름 있는 시/도가 있으니 거기에 합친다 — 배지가 늘지 않는다.
    final gyeongbuk = sidos.single;
    expect(gyeongbuk.sidoName, '경상북도');
    expect(gyeongbuk.totalSpots, 24);
  });

  test('코드와 주소가 어긋난 소수 스팟이 있어도 코드는 «다수» 시/도의 것이다', () {
    // 코드 34(충남) 안에 주소가 「대전」인 시/군/구가 소수 섞여 있고, 주소 없는 그룹도 있다.
    final sidos = aggregateBySido([
      _region('34-1', '충청남도 천안시', 800, 8),
      _region('34-2', '대전광역시 유성구', 20, 0), // 코드는 충남인데 주소는 대전
      _region('34-9', '34-9', 180, 0), // 주소 없음
      _region('3-1', '대전광역시 서구', 300, 3),
    ]);
    final chungnam = sidos.singleWhere((s) => s.sidoName == '충청남도');
    final daejeon = sidos.singleWhere((s) => s.sidoName == '대전광역시');
    // 코드 34 는 통째로 충남 — 어긋난 20개와 주소 없는 180개까지.
    expect(chungnam.areaCodes, ['34']);
    expect(chungnam.totalSpots, 1000);
    // 대전은 자기 코드(3)만. 코드 34 가 끼어들지 않는다.
    expect(daejeon.areaCodes, ['3']);
    expect(daejeon.totalSpots, 300);
  });

  test('같은 코드의 이름 있는 시/도가 아예 없을 때만 코드 배지로 남는다', () {
    final sidos = aggregateBySido([
      _region('39-1', '39-1', 5, 0),
      _region('2-1', '인천광역시 남동구', 10, 5),
    ]);
    expect(sidos, hasLength(2));
    expect(sidos.singleWhere((s) => s.sidoName.isEmpty).areaCodes, ['39']);
  });

  test('역지오코딩과 관광공사 주소가 다르게 부르는 시/도를 같은 것으로 본다', () {
    expect(normalizeSidoName('강원특별자치도'), normalizeSidoName('강원도'));
    expect(normalizeSidoName('전북특별자치도'), normalizeSidoName('전라북도'));
    expect(normalizeSidoName('세종특별자치시'), '세종');
    expect(normalizeSidoName('인천광역시'), '인천');
    expect(normalizeSidoName('경기도'), isNot(normalizeSidoName('경상북도')));
  });

  test('상단 바 이름으로 먼저 찾고, 안 맞으면 스팟 areaCode 로 찾는다', () {
    final sidos = aggregateBySido([_region('31-1', '경기도 부천시', 10, 1), _region('2-1', '인천광역시 남동구', 10, 5)]);
    // 이름이 맞으면 스팟이 다른 시/도를 가리켜도 이름을 따른다 — 바에 뜬 것이 기준이다.
    expect(findSidoConquest(sidos, regionName: '인천광역시', areaCode: '31')?.areaCodes, ['2']);
    // 이름을 못 찾으면(주소 품질 문제 등) 스팟 코드가 안전망.
    expect(findSidoConquest(sidos, regionName: '알 수 없음', areaCode: '31')?.areaCodes, ['31']);
    expect(findSidoConquest(sidos, regionName: null, areaCode: '31')?.areaCodes, ['31']);
    expect(findSidoConquest(sidos, regionName: '알 수 없음', areaCode: null), isNull);
  });
}

void _provinceTests() {
  final sidos = aggregateBySido([
    _region('31-1', '경기도 부천시', 10, 1),
    _region('5-1', '전남광주통합특별시 동구', 100, 10),
    _region('38-3', '전남광주통합특별시 순천시', 200, 0),
    _region('32-1', '강원특별자치도 춘천시', 50, 5),
  ]);

  test('경계 데이터의 시/도 이름이 배지와 같으면 그대로 맞는다', () {
    expect(matchSidoForProvince(sidos, '경기도')?.sidoName, '경기도');
    // 2013 경계는 「강원도」, 배지는 「강원특별자치도」 — 접미어 차이는 흡수한다.
    expect(matchSidoForProvince(sidos, '강원도')?.sidoName, '강원특별자치도');
  });

  test('통합된 시/도는 옛 폴리곤 둘이 같은 배지에 맞는다 — 광주 · 전남 → 전남광주통합특별시', () {
    final gwangju = matchSidoForProvince(sidos, '광주광역시');
    final jeonnam = matchSidoForProvince(sidos, '전라남도');
    expect(gwangju?.sidoName, '전남광주통합특별시');
    expect(jeonnam, same(gwangju));
  });

  test('배지에 없는 시/도는 null — 빈 색으로 남긴다', () {
    expect(matchSidoForProvince(sidos, '제주특별자치도'), isNull);
    // 「경상남도」의 줄임말 「경남」이 다른 배지 이름에 우연히 들어 있지 않다.
    expect(matchSidoForProvince(sidos, '경상남도'), isNull);
  });
}
