import 'package:flutter_test/flutter_test.dart';
import 'package:fogapp/models/spot.dart';
import 'package:fogapp/services/spot_geofence_controller.dart';

Spot _spot(int id, {double lat = 37.5665, double lng = 126.9780}) => Spot(
      id: id,
      contentId: 'c$id',
      title: 'spot-$id',
      lat: lat,
      lng: lng,
      unlocked: false,
    );

/// 위도 [deg]도 = 위도 방향으로 약 111.32km. 시청 근처(위도 37.5665)를 기준으로
/// 지정한 미터만큼 북쪽으로 이동한 좌표를 만든다.
double _latOffset(double baseLat, double meters) => baseLat + meters / 111320;

void main() {
  group('SpotGeofenceController', () {
    test('반경 안으로 들어오면 onEnter가 발생한다', () async {
      final controller = SpotGeofenceController(enterRadiusMeters: 100, exitRadiusMeters: 130);
      addTearDown(controller.dispose);
      final spot = _spot(1);
      controller.updateCandidates([spot]);

      final events = <GeofenceEnterEvent>[];
      controller.onEnter.listen(events.add);

      // 200m 밖 → 아직 진입 아님
      controller.updatePosition(lat: _latOffset(spot.lat, 200), lng: spot.lng);
      // 50m 안 → 진입
      controller.updatePosition(lat: _latOffset(spot.lat, 50), lng: spot.lng);

      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1));
      expect(events.single.spot.id, 1);
      expect(controller.insideSpotIds, {1});
    });

    test('같은 스팟에 대해 반경 안에 머무는 동안 onEnter가 중복 발생하지 않는다', () async {
      final controller = SpotGeofenceController(enterRadiusMeters: 100, exitRadiusMeters: 130);
      addTearDown(controller.dispose);
      final spot = _spot(1);
      controller.updateCandidates([spot]);

      final events = <GeofenceEnterEvent>[];
      controller.onEnter.listen(events.add);

      controller.updatePosition(lat: _latOffset(spot.lat, 50), lng: spot.lng);
      controller.updatePosition(lat: _latOffset(spot.lat, 40), lng: spot.lng);
      controller.updatePosition(lat: _latOffset(spot.lat, 60), lng: spot.lng);

      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1));
    });

    test('exitRadius를 벗어나야 onExit이 발생한다 (히스테리시스)', () async {
      final controller = SpotGeofenceController(enterRadiusMeters: 100, exitRadiusMeters: 130);
      addTearDown(controller.dispose);
      final spot = _spot(1);
      controller.updateCandidates([spot]);

      final exits = <Spot>[];
      controller.onExit.listen(exits.add);

      controller.updatePosition(lat: _latOffset(spot.lat, 50), lng: spot.lng); // 진입
      // enterRadius(100m)는 넘었지만 exitRadius(130m) 안쪽 — 아직 이탈 아님(떨림 방지)
      controller.updatePosition(lat: _latOffset(spot.lat, 110), lng: spot.lng);
      await Future<void>.delayed(Duration.zero);
      expect(exits, isEmpty);
      expect(controller.insideSpotIds, {1});

      // exitRadius(130m) 밖으로 완전히 벗어나면 이탈
      controller.updatePosition(lat: _latOffset(spot.lat, 200), lng: spot.lng);
      await Future<void>.delayed(Duration.zero);
      expect(exits, hasLength(1));
      expect(controller.insideSpotIds, isEmpty);
    });

    test('후보 목록에서 제거된 스팟은 onExit 없이 추적을 멈춘다', () async {
      final controller = SpotGeofenceController(enterRadiusMeters: 100, exitRadiusMeters: 130);
      addTearDown(controller.dispose);
      final spot = _spot(1);
      controller.updateCandidates([spot]);
      controller.updatePosition(lat: spot.lat, lng: spot.lng);
      expect(controller.insideSpotIds, {1});

      final exits = <Spot>[];
      controller.onExit.listen(exits.add);

      controller.updateCandidates([]); // 뷰포트 밖으로 나가 후보에서 제거됨
      await Future<void>.delayed(Duration.zero);

      expect(exits, isEmpty);
      expect(controller.insideSpotIds, isEmpty);
    });

    test('서로 다른 두 스팟을 동시에 독립적으로 판정한다', () async {
      final controller = SpotGeofenceController(enterRadiusMeters: 100, exitRadiusMeters: 130);
      addTearDown(controller.dispose);
      final near = _spot(1);
      final far = _spot(2, lat: _latOffset(37.5665, 500));
      controller.updateCandidates([near, far]);

      controller.updatePosition(lat: near.lat, lng: near.lng);

      expect(controller.insideSpotIds, {1});
    });
  });
}
