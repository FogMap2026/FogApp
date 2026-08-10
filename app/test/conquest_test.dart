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
}
