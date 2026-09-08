import 'package:flutter_test/flutter_test.dart';
import 'package:fogapp/screens/map_screen.dart';

void main() {
  group('shouldShowEmptyAreaNotice', () {
    test('첫 조회가 끝나기 전에는 띄우지 않는다', () {
      // 이걸 놓치면 스팟이 있는 지역에서도 앱을 켤 때마다 안내가 번쩍인다 —
      // 조회 전 상태는 "0건"이 아니라 "아직 모름"이다.
      expect(
        shouldShowEmptyAreaNotice(spotsEverLoaded: false, spotCount: 0, dismissed: false),
        isFalse,
      );
    });

    test('조회했는데 0건이면 띄운다', () {
      expect(
        shouldShowEmptyAreaNotice(spotsEverLoaded: true, spotCount: 0, dismissed: false),
        isTrue,
      );
    });

    test('스팟이 있으면 띄우지 않는다', () {
      expect(
        shouldShowEmptyAreaNotice(spotsEverLoaded: true, spotCount: 3, dismissed: false),
        isFalse,
      );
    });

    test('닫은 뒤에는 다시 비어도 띄우지 않는다', () {
      expect(
        shouldShowEmptyAreaNotice(spotsEverLoaded: true, spotCount: 0, dismissed: true),
        isFalse,
      );
    });
  });
}
