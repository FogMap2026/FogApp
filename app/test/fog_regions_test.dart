// 안개 구역 — 스팟마다 구역 하나(보로노이 셀), 빈 땅엔 가상 씨앗, 바다엔 안 깐다.
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogapp/models/spot_coord.dart';
import 'package:fogapp/services/fog_overlay_controller.dart';
import 'package:fogapp/services/fog_regions.dart';
import 'package:geolocator/geolocator.dart';

const _lat = 37.4563;
const _lng = 126.7052;

SpotCoord _spot(int id, {double north = 0, double east = 0}) =>
    SpotCoord(id: id, lat: _lat + north / 111320, lng: _lng + east / (111320 * 0.7937));

double _dist(NLatLng a, double lat, double lng) => Geolocator.distanceBetween(a.latitude, a.longitude, lat, lng);

void main() {
  group('build', () {
    test('스팟은 그대로 씨앗이 되고, 1km 안에 스팟이 있는 자리엔 가상 씨앗을 깔지 않는다', () {
      final regions = FogRegions.build([_spot(1), _spot(2, north: 300)]);
      final spots = regions.seeds.where((s) => s.isSpot).toList();
      expect(spots.map((s) => s.spotId), unorderedEquals([1, 2]));
      for (final s in regions.seeds.where((s) => !s.isSpot)) {
        expect(Geolocator.distanceBetween(s.lat, s.lng, _lat, _lng), greaterThan(FogRegions.emptyThresholdMeters - 1));
      }
    });

    test('스팟 둘레 3km 상자의 빈 땅은 가상 씨앗으로 채운다 — 씨앗 사이가 1.5km 를 넘지 않는다', () {
      final regions = FogRegions.build([_spot(1)]);
      // 스팟에서 2km 북쪽 — 스팟 구역 밖이니 가까운 가상 씨앗이 있어야 한다.
      final seed = regions.nearest(_lat + 2000 / 111320, _lng)!;
      expect(seed.isSpot, isFalse);
      expect(
        Geolocator.distanceBetween(seed.lat, seed.lng, _lat + 2000 / 111320, _lng),
        lessThan(FogRegions.fillSpacingMeters),
      );
    });

    test('한반도 밖 좌표는 뺀다 — 하나만 있어도 상자가 수천 km 가 된다', () {
      final regions = FogRegions.build([_spot(1), const SpotCoord(id: 9, lat: 0, lng: 0)]);
      expect(regions.seedOfSpot(9), isNull);
      expect(regions.seeds.length, lessThan(200));
    });

    test('땅 마스크를 주면 그 밖에는 가상 씨앗을 깔지 않는다', () {
      // 스팟을 품는 1km 사각형만 땅.
      const d = 500 / 111320;
      final land = LandMask.fromRings([
        [
          const NLatLng(_lat - d, _lng - d),
          const NLatLng(_lat - d, _lng + d),
          const NLatLng(_lat + d, _lng + d),
          const NLatLng(_lat + d, _lng - d),
        ],
      ]);
      final regions = FogRegions.build([_spot(1)], land: land);
      // 땅 안은 스팟 1km 안이라 가상 씨앗 자리가 없고, 땅 밖은 마스크가 막는다.
      expect(regions.seeds.where((s) => !s.isSpot), isEmpty);
    });
  });

  group('nearest · cell', () {
    test('어느 점이든 가장 가까운 씨앗의 구역이다', () {
      final regions = FogRegions.build([_spot(1), _spot(2, east: 400)]);
      expect(regions.nearest(_lat, _lng + 100 / (111320 * 0.7937))!.spotId, 1);
      expect(regions.nearest(_lat, _lng + 300 / (111320 * 0.7937))!.spotId, 2);
    });

    test('셀은 씨앗을 품는 볼록 다각형이고, 이웃과의 경계는 둘 사이 중간이다', () {
      final regions = FogRegions.build([_spot(1), _spot(2, east: 400)]);
      final a = regions.seedOfSpot(1)!;
      final cell = regions.cell(a);
      expect(cell.length, greaterThanOrEqualTo(3));
      expect(FogGrid.pointInRing(NLatLng(a.lat, a.lng), cell), isTrue);
      // 스팟 2 쪽 경계는 200m 지점 — 190m 는 안, 210m 는 밖.
      const mLng = 111320 * 0.7937;
      expect(FogGrid.pointInRing(const NLatLng(_lat, _lng + 190 / mLng), cell), isTrue);
      expect(FogGrid.pointInRing(const NLatLng(_lat, _lng + 210 / mLng), cell), isFalse);
      // 이웃이 없는 쪽으로도 상한(2.5km)을 넘지 않는다.
      for (final p in cell) {
        expect(_dist(p, a.lat, a.lng), lessThanOrEqualTo(FogRegions.cellCapMeters * 1.5));
      }
    });

    test('좌표가 완전히 같은 스팟 둘(V11 전 데이터)이어도 셀이 비지 않는다', () {
      final regions = FogRegions.build([_spot(1), _spot(2)]);
      expect(regions.cell(regions.seedOfSpot(1)!).length, greaterThanOrEqualTo(3));
    });

    test('맞닿는 두 구역의 공유 변은 같은 좌표다 — 어긋나면 그 틈이 얇은 안개 선으로 보인다', () {
      // 남북으로 1.4km 떨어진 두 스팟. 셀마다 «자기 위도»로 경도를 환산하면 공유 변이
      // 20cm 쯤 어긋났다(사용자 제보, 09-17).
      final regions = FogRegions.build([_spot(1), _spot(2, north: 1400)]);
      final rings = regions.cellsOf([regions.seedOfSpot(1)!, regions.seedOfSpot(2)!]);
      expect(rings.length, 2);

      // 두 셀이 공유하는 변 = 700m 지점을 지나는 가로선. 한쪽 링의 그 변 위 꼭짓점이
      // 다른 링에도 «같은 좌표로» 있어야 한다.
      const shared = _lat + 700 / 111320;
      bool onSharedEdge(NLatLng p) => (p.latitude - shared).abs() < 1e-7;
      final aEdge = rings[0].where(onSharedEdge).toList();
      final bEdge = rings[1].where(onSharedEdge).toList();
      expect(aEdge, isNotEmpty, reason: '경계 위 꼭짓점이 있어야 한다');
      expect(bEdge.length, aEdge.length);

      for (final p in aEdge) {
        final nearest = bEdge
            .map((q) => Geolocator.distanceBetween(p.latitude, p.longitude, q.latitude, q.longitude))
            .reduce((a, b) => a < b ? a : b);
        expect(nearest, lessThan(0.01), reason: '공유 변의 같은 꼭짓점이 1cm 넘게 어긋났다');
      }
    });

    test('좌표가 같은 씨앗 둘을 다 걷어도 구멍은 하나다 — 같은 구멍 둘은 짝홀로 서로 지워진다', () {
      final regions = FogRegions.build([_spot(1), _spot(2), _spot(3, east: 400)]);
      final rings = regions.cellsOf([regions.seedOfSpot(1)!, regions.seedOfSpot(2)!, regions.seedOfSpot(3)!]);
      expect(rings.length, 2);
    });
  });

  group('LandMask', () {
    test('폴리곤 안은 땅, 밖은 바다, 상자 밖도 바다', () {
      const d = 0.05;
      final mask = LandMask.fromRings([
        [
          const NLatLng(_lat - d, _lng - d),
          const NLatLng(_lat - d, _lng + d),
          const NLatLng(_lat + d, _lng + d),
          const NLatLng(_lat + d, _lng - d),
        ],
      ]);
      expect(mask.contains(_lat, _lng), isTrue);
      expect(mask.contains(_lat + d * 2, _lng), isFalse);
      expect(mask.contains(0, 0), isFalse);
    });

    test('오목한 폴리곤(ㄷ자)의 파인 자리는 바다다', () {
      const d = 0.05;
      // ㄷ 자: 오른쪽 가운데가 파여 있다.
      final mask = LandMask.fromRings([
        [
          const NLatLng(_lat - d, _lng - d),
          const NLatLng(_lat - d, _lng + d),
          const NLatLng(_lat - d / 3, _lng + d),
          const NLatLng(_lat - d / 3, _lng),
          const NLatLng(_lat + d / 3, _lng),
          const NLatLng(_lat + d / 3, _lng + d),
          const NLatLng(_lat + d, _lng + d),
          const NLatLng(_lat + d, _lng - d),
        ],
      ]);
      expect(mask.contains(_lat, _lng - d / 2), isTrue); // 왼쪽 몸통
      expect(mask.contains(_lat, _lng + d / 2), isFalse); // 파인 자리
      expect(mask.contains(_lat + d * 0.7, _lng + d / 2), isTrue); // 위 팔
    });
  });
}
