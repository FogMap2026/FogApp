// 지도 우상단 상자가 무엇을 말할지 고르는 판정 — 순수 함수라 지도 없이 검증한다.
// 그리는 쪽(MapTopBar·ProximityBanner)은 map_top_bar.dart 다.
import 'package:flutter_test/flutter_test.dart';
import 'package:fogapp/models/spot.dart';
import 'package:fogapp/services/spot_proximity.dart';
import 'package:fogapp/widgets/conquest_pill_mode.dart';

Spot _spot(int id) => Spot(
      id: id,
      contentId: 'c$id',
      title: '스팟$id',
      lat: 37.5665,
      lng: 126.978,
      unlocked: false,
    );

SpotProximity _proximity(int id, ProximityLevel level) => SpotProximity(
      spot: _spot(id),
      distanceMeters: level == ProximityLevel.verifiable ? 40 : 200,
      level: level,
    );

void main() {
  group('conquestPillModeFor', () {
    test('알릴 스팟이 없으면 탐험률을 보여준다', () {
      expect(
        conquestPillModeFor(proximity: null, dismissedSpotId: null),
        ConquestPillMode.progress,
      );
    });

    test('근처 스팟이 있으면 알림으로 바뀐다', () {
      expect(
        conquestPillModeFor(
          proximity: _proximity(1, ProximityLevel.near),
          dismissedSpotId: null,
        ),
        ConquestPillMode.near,
      );
    });

    test('닫은 스팟의 «근처» 알림은 다시 뜨지 않는다', () {
      expect(
        conquestPillModeFor(
          proximity: _proximity(1, ProximityLevel.near),
          dismissedSpotId: 1,
        ),
        ConquestPillMode.progress,
      );
    });

    test('다른 스팟이면 닫아 둔 것과 무관하게 알린다', () {
      expect(
        conquestPillModeFor(
          proximity: _proximity(2, ProximityLevel.near),
          dismissedSpotId: 1,
        ),
        ConquestPillMode.near,
      );
    });

    // 🔴 이게 깨지면 «인증 가능»을 영영 못 보는 사람이 생긴다 — 300m 에서 알림을 한 번 닫고
    //    그대로 걸어 들어가면 인증할 수 있게 돼도 화면이 아무 말을 안 한다.
    test('닫은 스팟이라도 인증 가능해지면 다시 알린다', () {
      expect(
        conquestPillModeFor(
          proximity: _proximity(1, ProximityLevel.verifiable),
          dismissedSpotId: 1,
        ),
        ConquestPillMode.verifiable,
      );
    });
  });
}
