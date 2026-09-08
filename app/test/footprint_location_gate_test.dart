import 'package:flutter_test/flutter_test.dart';
import 'package:fogapp/services/footprint_location_gate.dart';

void main() {
  test('정확도가 10m 이내면 좌표를 그대로 쓸 수 있다', () {
    final result = classifyFootprintLocation(lat: 37.5665, lng: 126.9780, accuracyMeters: 8);

    expect(result, isA<FootprintLocationReady>());
    final ready = result as FootprintLocationReady;
    expect(ready.lat, 37.5665);
    expect(ready.lng, 126.9780);
  });

  test('정확도가 정확히 10m면 통과한다(경계값)', () {
    final result = classifyFootprintLocation(lat: 0, lng: 0, accuracyMeters: maxFootprintAccuracyMeters);

    expect(result, isA<FootprintLocationReady>());
  });

  test('정확도가 10m를 넘으면 부정확 판정과 함께 값을 담아 돌려준다', () {
    final result = classifyFootprintLocation(lat: 0, lng: 0, accuracyMeters: 15);

    expect(result, isA<FootprintLocationInaccurate>());
    expect((result as FootprintLocationInaccurate).accuracyMeters, 15);
  });

  test('부정확해도 좌표를 함께 돌려준다 — 사용자가 동의하면 그대로 쓴다', () {
    // 10m 는 보안 규칙이 아니라 UX 규칙이라(footprint-redesign 3-1·5-2) 막다른
    // 길이면 안 된다. 실내 GPS 는 보통 20~50m 이고, 좌표를 안 돌려주면 실내에서는
    // 글을 아예 남길 수 없다.
    final result = classifyFootprintLocation(lat: 37.5665, lng: 126.9780, accuracyMeters: 35);

    final inaccurate = result as FootprintLocationInaccurate;
    expect(inaccurate.lat, 37.5665);
    expect(inaccurate.lng, 126.9780);
    expect(inaccurate.accuracyMeters, 35);
  });
}
