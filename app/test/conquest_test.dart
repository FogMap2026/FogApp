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
    final gyeonggi = sidos.singleWhere((s) => s.areaCode == '31');
    expect(gyeonggi.sidoName, '경기도');
    expect(gyeonggi.totalSpots, 303);
    expect(gyeonggi.visitedSpots, 3);
    expect(gyeonggi.rate, closeTo(0.0099, 0.0001));
    expect(sidos.singleWhere((s) => s.areaCode == '2').rate, 0.5);
  });

  test('이름을 못 만든 지역(코드 폴백)은 시/도 이름을 더럽히지 않는다', () {
    final sidos = aggregateBySido([
      _region('35-9', '35-9', 4, 0), // addr1 이 비어 서버가 코드로 폴백한 지역
      _region('35-2', '경상북도 경주시', 20, 2),
    ]);
    final gyeongbuk = sidos.single;
    expect(gyeongbuk.sidoName, '경상북도');
    expect(gyeongbuk.totalSpots, 24);
  });

  test('역지오코딩과 관광공사 주소가 다르게 부르는 시/도를 같은 것으로 본다', () {
    expect(normalizeSidoName('강원특별자치도'), normalizeSidoName('강원도'));
    expect(normalizeSidoName('전북특별자치도'), normalizeSidoName('전라북도'));
    expect(normalizeSidoName('세종특별자치시'), '세종');
    expect(normalizeSidoName('인천광역시'), '인천');
    expect(normalizeSidoName('경기도'), isNot(normalizeSidoName('경상북도')));
  });

  test('상단 바 이름으로 먼저 찾고, 안 맞으면 스팟 areaCode 로 찾는다', () {
    final sidos = aggregateBySido([
      _region('31-1', '경기도 부천시', 10, 1),
      _region('2-1', '인천광역시 남동구', 10, 5),
    ]);
    // 이름이 맞으면 스팟이 다른 시/도를 가리켜도 이름을 따른다 — 바에 뜬 것이 기준이다.
    expect(findSidoConquest(sidos, regionName: '인천광역시', areaCode: '31')?.areaCode, '2');
    // 이름을 못 찾으면(주소 품질 문제 등) 스팟 코드가 안전망.
    expect(findSidoConquest(sidos, regionName: '알 수 없음', areaCode: '31')?.areaCode, '31');
    expect(findSidoConquest(sidos, regionName: null, areaCode: '31')?.areaCode, '31');
    expect(findSidoConquest(sidos, regionName: '알 수 없음', areaCode: null), isNull);
  });
}
