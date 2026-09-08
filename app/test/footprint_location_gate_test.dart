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

  test('상한(100m)을 넘으면 동의를 받을 수 있는 상태조차 아니다', () {
    // 오차를 숫자로 보여주는 것만으로는 판단을 맡길 수 없는 범위. 사용자는
    // "35m 면 뭐" 하고 누르지, GPS 가 튀어서 나온 2km 를 상상하고 누르지 않는다.
    final result = classifyFootprintLocation(lat: 37.5, lng: 127.0, accuracyMeters: 2000);

    expect(result, isA<FootprintLocationTooInaccurate>());
    expect((result as FootprintLocationTooInaccurate).accuracyMeters, 2000);
  });

  test('정확히 100m면 아직 물어볼 수 있다(경계값)', () {
    final result = classifyFootprintLocation(
      lat: 37.5,
      lng: 127.0,
      accuracyMeters: maxConfirmableAccuracyMeters,
    );

    expect(result, isA<FootprintLocationInaccurate>());
  });

  test('상한은 방문 인증 반경과 같은 100m다', () {
    // 임의의 숫자가 아니다 — 그보다 멀면 "여기"라는 말이 성립하지 않는다는
    // 기준을 이 앱이 이미 인증 반경(VisitProperties.radiusMeters)으로 정해뒀다.
    expect(maxConfirmableAccuracyMeters, 100);
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
