// 줌 → 스팟 마커 배율. 지도 컨트롤러 없이 표 보간만 검증한다.
import 'package:flutter_test/flutter_test.dart';
import 'package:fogapp/services/spot_marker_controller.dart';

void main() {
  test('줌 15 이상은 원래 크기, 12 이하는 50% 에서 멈춘다', () {
    expect(SpotMarkerController.scaleForZoom(15), 1.0);
    expect(SpotMarkerController.scaleForZoom(18), 1.0);
    expect(SpotMarkerController.scaleForZoom(12), 0.5);
    expect(SpotMarkerController.scaleForZoom(6), 0.5);
  });

  test('한 단계씩 90 → 70 → 50', () {
    expect(SpotMarkerController.scaleForZoom(14), closeTo(0.9, 1e-9));
    expect(SpotMarkerController.scaleForZoom(13), closeTo(0.7, 1e-9));
  });

  test('사이 값은 선형 보간 — 핀치 중에 뚝뚝 끊기지 않는다', () {
    expect(SpotMarkerController.scaleForZoom(14.5), closeTo(0.95, 1e-9));
    expect(SpotMarkerController.scaleForZoom(13.5), closeTo(0.8, 1e-9));
    expect(SpotMarkerController.scaleForZoom(12.5), closeTo(0.6, 1e-9));
  });
}
