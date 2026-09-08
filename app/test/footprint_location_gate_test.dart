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
}
