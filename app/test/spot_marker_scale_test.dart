// 줌 → 스팟 마커 배율. 지도 컨트롤러 없이 표 보간만 검증한다.
import 'package:flutter_test/flutter_test.dart';
import 'package:fogapp/services/spot_marker_controller.dart';

void main() {
  test('줌 15 이상은 원래 크기, 10 이하는 50% 에서 멈춘다', () {
    expect(SpotMarkerController.scaleForZoom(15), 1.0);
    expect(SpotMarkerController.scaleForZoom(18), 1.0);
    expect(SpotMarkerController.scaleForZoom(10), 0.5);
    expect(SpotMarkerController.scaleForZoom(6), 0.5);
  });

  test('한 단계에 6~12% 씩만 준다 — 조금 빼도 확 작아지지 않는다', () {
    expect(SpotMarkerController.scaleForZoom(14), closeTo(0.88, 1e-9));
    expect(SpotMarkerController.scaleForZoom(13), closeTo(0.76, 1e-9));
    expect(SpotMarkerController.scaleForZoom(12), closeTo(0.65, 1e-9));
    expect(SpotMarkerController.scaleForZoom(11), closeTo(0.56, 1e-9));
    for (var z = 15.0; z > 10; z -= 1) {
      final drop = SpotMarkerController.scaleForZoom(z) - SpotMarkerController.scaleForZoom(z - 1);
      expect(drop, inInclusiveRange(0.059, 0.121), reason: '줌 $z → ${z - 1}');
    }
  });

  test('사이 값은 선형 보간 — 핀치 중에 뚝뚝 끊기지 않는다', () {
    expect(SpotMarkerController.scaleForZoom(14.5), closeTo(0.94, 1e-9));
    expect(SpotMarkerController.scaleForZoom(13.5), closeTo(0.82, 1e-9));
    expect(SpotMarkerController.scaleForZoom(12.5), closeTo(0.705, 1e-9));
  });
}
