import 'package:flutter_test/flutter_test.dart';
import 'package:fogapp/screens/map_screen.dart';

/// 기본값은 "정상적으로 조회가 끝났고 스팟도 있다" — 각 테스트가 필요한 것만 바꾼다.
MapNotice notice({
  bool loadFailed = false,
  bool spotsEverLoaded = true,
  int spotCount = 3,
  bool serverErrorDismissed = false,
  bool emptyAreaDismissed = false,
}) {
  return mapNoticeFor(
    loadFailed: loadFailed,
    spotsEverLoaded: spotsEverLoaded,
    spotCount: spotCount,
    serverErrorDismissed: serverErrorDismissed,
    emptyAreaDismissed: emptyAreaDismissed,
  );
}

void main() {
  group('mapNoticeFor — 빈 지역 (#144)', () {
    test('첫 조회가 끝나기 전에는 아무것도 띄우지 않는다', () {
      // 이걸 놓치면 스팟이 있는 지역에서도 앱을 켤 때마다 안내가 번쩍인다 —
      // 조회 전 상태는 "0건"이 아니라 "아직 모름"이다.
      expect(notice(spotsEverLoaded: false, spotCount: 0), MapNotice.none);
    });

    test('조회했는데 0건이면 빈 지역 안내', () {
      expect(notice(spotCount: 0), MapNotice.emptyArea);
    });

    test('스팟이 있으면 아무것도 띄우지 않는다', () {
      expect(notice(spotCount: 3), MapNotice.none);
    });

    test('닫은 뒤에는 다시 비어도 띄우지 않는다', () {
      expect(notice(spotCount: 0, emptyAreaDismissed: true), MapNotice.none);
    });
  });

  group('mapNoticeFor — 서버 연결 실패 (#146)', () {
    test('조회에 실패하면 서버 안내를 띄운다', () {
      expect(
        notice(loadFailed: true, spotsEverLoaded: false, spotCount: 0),
        MapNotice.serverError,
      );
    });

    test('실패는 빈 지역보다 우선한다 — 서버가 죽었는데 "스팟이 없다"고 하면 거짓말이다', () {
      // #146의 핵심. 못 물어봤으니 이 근처에 스팟이 있는지 없는지 알 수 없다.
      expect(notice(loadFailed: true, spotCount: 0), MapNotice.serverError);
    });

    test('예전에 성공해 스팟을 갖고 있어도, 지금 실패했으면 서버 안내를 띄운다', () {
      expect(notice(loadFailed: true, spotCount: 5), MapNotice.serverError);
    });

    test('닫으면 띄우지 않는다', () {
      expect(
        notice(loadFailed: true, spotCount: 0, serverErrorDismissed: true),
        MapNotice.none,
      );
    });

    test('서버 안내를 닫아둔 상태여도, 실패가 아니면 빈 지역 안내는 정상적으로 뜬다', () {
      expect(notice(spotCount: 0, serverErrorDismissed: true), MapNotice.emptyArea);
    });

    test('다시 성공하면(loadFailed=false) 서버 안내가 사라진다', () {
      expect(notice(loadFailed: true, spotCount: 5), MapNotice.serverError);
      expect(notice(spotCount: 5), MapNotice.none);
    });
  });

  group('mapNoticeFor — 두 안내가 동시에 뜨지 않는다', () {
    test('반환값이 하나뿐이라 어떤 입력에서도 배너가 겹칠 수 없다', () {
      // 불리언 두 개로 두면 만들 수 있는 상태 — 타입으로 막았다는 것을 고정해 둔다.
      for (final failed in [true, false]) {
        for (final loaded in [true, false]) {
          for (final count in [0, 3]) {
            for (final dismissA in [true, false]) {
              for (final dismissB in [true, false]) {
                final result = notice(
                  loadFailed: failed,
                  spotsEverLoaded: loaded,
                  spotCount: count,
                  serverErrorDismissed: dismissA,
                  emptyAreaDismissed: dismissB,
                );
                expect(MapNotice.values, contains(result));
              }
            }
          }
        }
      }
    });
  });
}
