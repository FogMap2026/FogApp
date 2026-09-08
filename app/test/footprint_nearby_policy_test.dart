import 'package:flutter_test/flutter_test.dart';
import 'package:fogapp/services/footprint_nearby_policy.dart';

const _baseLat = 37.5665;
const _baseLng = 126.9780;

/// 위도 1도 ≈ 111.32km. 기준점에서 북쪽으로 [meters]만큼 이동한 위도.
double _latOffset(double meters) => _baseLat + meters / 111320;

void main() {
  group('FootprintNearbyPolicy 줌 임계', () {
    test('임계 미만에서는 그리지 않는다', () {
      final policy = FootprintNearbyPolicy(minZoom: 15);
      expect(policy.visibleAt(14.9), isFalse);
      expect(policy.visibleAt(6.7), isFalse); // 전국 뷰
    });

    test('임계 이상에서는 그린다', () {
      final policy = FootprintNearbyPolicy(minZoom: 15);
      expect(policy.visibleAt(15), isTrue);
      expect(policy.visibleAt(18), isTrue);
    });
  });

  group('FootprintNearbyPolicy 조회 반경', () {
    test('이동 중에는 50m, 해금된 스팟 안에서는 150m', () {
      final policy = FootprintNearbyPolicy();
      expect(policy.radiusFor(insideUnlockedSpot: false), 50);
      expect(policy.radiusFor(insideUnlockedSpot: true), 150);
    });

    test('스팟 안 반경은 안개 걷힘 반경(150m)과 같다', () {
      // FogOverlayController.clearCircle의 radiusMeters 기본값과 같아야 한다 —
      // 어긋나면 "걷힌 땅인데 글이 안 보이는" 상태가 생긴다.
      expect(FootprintNearbyPolicy().unlockedSpotRadiusMeters, 150);
    });
  });

  group('FootprintNearbyPolicy 재조회 판정', () {
    test('첫 조회는 항상 필요하다', () {
      final policy = FootprintNearbyPolicy();
      expect(
        policy.shouldRefetch(lat: _baseLat, lng: _baseLng, radiusMeters: 50),
        isTrue,
      );
    });

    test('충분히 움직이지 않았으면 다시 부르지 않는다', () {
      final policy = FootprintNearbyPolicy(refetchDistanceMeters: 25);
      policy.markFetched(lat: _baseLat, lng: _baseLng, radiusMeters: 50);

      // 10m 이동 — 걷는 내내 위치가 갱신돼도 요청이 나가면 안 된다.
      expect(
        policy.shouldRefetch(lat: _latOffset(10), lng: _baseLng, radiusMeters: 50),
        isFalse,
      );
    });

    test('임계 거리 이상 움직이면 다시 부른다', () {
      final policy = FootprintNearbyPolicy(refetchDistanceMeters: 25);
      policy.markFetched(lat: _baseLat, lng: _baseLng, radiusMeters: 50);

      expect(
        policy.shouldRefetch(lat: _latOffset(30), lng: _baseLng, radiusMeters: 50),
        isTrue,
      );
    });

    test('제자리에서도 반경이 바뀌면 다시 부른다', () {
      final policy = FootprintNearbyPolicy(refetchDistanceMeters: 25);
      policy.markFetched(lat: _baseLat, lng: _baseLng, radiusMeters: 50);

      // 서 있는 채로 해금 스팟에 진입한 경우. 거리 조건만 보면 넓어진 반경이
      // 영영 반영되지 않는다.
      expect(
        policy.shouldRefetch(lat: _baseLat, lng: _baseLng, radiusMeters: 150),
        isTrue,
      );
    });

    test('판정만으로는 기준점이 움직이지 않는다', () {
      final policy = FootprintNearbyPolicy(refetchDistanceMeters: 25);
      policy.markFetched(lat: _baseLat, lng: _baseLng, radiusMeters: 50);

      // 조회가 실패했다면 기준점이 그대로 남아, 같은 자리에서 다시 시도할 수 있어야 한다.
      final far = _latOffset(30);
      expect(policy.shouldRefetch(lat: far, lng: _baseLng, radiusMeters: 50), isTrue);
      expect(policy.shouldRefetch(lat: far, lng: _baseLng, radiusMeters: 50), isTrue);
      expect(policy.lastFetchLat, _baseLat);
    });

    test('조회에 성공하면 그 자리가 새 기준점이 된다', () {
      final policy = FootprintNearbyPolicy(refetchDistanceMeters: 25);
      policy.markFetched(lat: _baseLat, lng: _baseLng, radiusMeters: 50);

      final moved = _latOffset(30);
      policy.markFetched(lat: moved, lng: _baseLng, radiusMeters: 50);

      expect(policy.lastFetchLat, moved);
      // 새 기준점에서 다시 25m를 채워야 한다.
      expect(policy.shouldRefetch(lat: moved, lng: _baseLng, radiusMeters: 50), isFalse);
    });

    test('reset 후에는 제자리라도 다시 부른다', () {
      final policy = FootprintNearbyPolicy();
      policy.markFetched(lat: _baseLat, lng: _baseLng, radiusMeters: 50);
      expect(policy.shouldRefetch(lat: _baseLat, lng: _baseLng, radiusMeters: 50), isFalse);

      // 발자취를 새로 남긴 직후 — 움직이지 않았어도 다시 그려야 한다.
      policy.reset();
      expect(policy.shouldRefetch(lat: _baseLat, lng: _baseLng, radiusMeters: 50), isTrue);
    });
  });
}
