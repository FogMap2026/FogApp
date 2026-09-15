// 국외 덮개 — 다른 고리 안에 든 고리(광주 ⊂ 전남)는 구멍에서 뺀다. 안 빼면 짝홀로 그 땅에 바다색 구멍이 난다.
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogapp/services/outside_korea_mask.dart';

void main() {
  test('안에 든 고리는 빠지고 바깥 고리·따로 떨어진 고리는 남는다', () {
    const outer = [NLatLng(0, 0), NLatLng(0, 10), NLatLng(10, 10), NLatLng(10, 0)]; // 전남
    const inner = [NLatLng(4, 4), NLatLng(4, 6), NLatLng(6, 6), NLatLng(6, 4)]; // 광주
    const island = [NLatLng(20, 20), NLatLng(20, 21), NLatLng(21, 21), NLatLng(21, 20)]; // 제주
    final out = OutsideKoreaMask.outermostRings([outer, inner, island]);
    expect(out, [outer, island]);
  });
}
