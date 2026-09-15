// 지도 우하단 근접 아이콘의 단계 판정 — 순수 함수라 지도·위치 스트림 없이 검증한다.
import 'package:flutter_test/flutter_test.dart';
import 'package:fogapp/models/spot.dart';
import 'package:fogapp/services/spot_proximity.dart';

const _baseLat = 37.5665;
const _baseLng = 126.9780;

Spot _spot(int id, {double northMeters = 0}) => Spot(
      id: id,
      contentId: 'c$id',
      title: 'spot-$id',
      lat: _baseLat + northMeters / 111320,
      lng: _baseLng,
      unlocked: false,
    );

/// 기준점에서 [northMeters] 만큼 북쪽에 선 사람의 판정.
SpotProximity? _at(
  double northMeters,
  List<Spot> spots, {
  SpotProximity? previous,
  Set<int> visited = const {},
  double? accuracy,
}) =>
    resolveSpotProximity(
      candidates: spots,
      lat: _baseLat + northMeters / 111320,
      lng: _baseLng,
      visitedSpotIds: visited,
      previous: previous,
      accuracyMeters: accuracy,
    );

void main() {
  final spot = _spot(1);

  group('단계', () {
    test('근처 반경 밖이면 알리지 않는다', () {
      expect(_at(400, [spot]), isNull);
    });

    test('300m 안이면 «근처» — 아직 인증은 못 한다', () {
      final p = _at(250, [spot])!;
      expect(p.level, ProximityLevel.near);
      expect(p.spot.id, 1);
      expect(p.distanceMeters, closeTo(250, 1));
    });

    test('100m 안이면 «인증 가능»', () {
      expect(_at(80, [spot])!.level, ProximityLevel.verifiable);
    });

    test('인증 반경은 서버 visit.radius-meters(100)와 같다', () {
      expect(SpotProximity.verifyEnterMeters, 100);
      expect(SpotProximity.nearEnterMeters, greaterThan(SpotProximity.verifyExitMeters));
    });

    test('이미 인증한 스팟은 아무리 가까워도 알리지 않는다', () {
      expect(_at(0, [spot], visited: {1}), isNull);
    });
  });

  group('히스테리시스 — 경계에서 GPS 가 흔들려도 아이콘이 깜빡이지 않는다', () {
    test('처음이면 320m 는 근처가 아니지만, 이미 알리던 스팟이면 350m 까지 붙잡는다', () {
      expect(_at(320, [spot]), isNull);
      final previous = _at(290, [spot]);
      expect(_at(320, [spot], previous: previous)!.level, ProximityLevel.near);
      expect(_at(360, [spot], previous: previous), isNull);
    });

    test('인증 단계도 130m 까지 유지하고, 그 밖에서는 «근처»로 내려온다', () {
      expect(_at(120, [spot])!.level, ProximityLevel.near);
      final previous = _at(90, [spot]);
      expect(_at(120, [spot], previous: previous)!.level, ProximityLevel.verifiable);
      expect(_at(140, [spot], previous: previous)!.level, ProximityLevel.near);
    });
  });

  group('어떤 스팟을 알릴까', () {
    test('인증 가능한 스팟이 «근처» 스팟보다 먼저다', () {
      // 기준점 북쪽 0m 에 A, 200m 에 B. 사람이 북쪽 60m → A 60m(인증) · B 140m(근처).
      final a = _spot(1);
      final b = _spot(2, northMeters: 200);
      expect(_at(60, [b, a])!.spot.id, 1);
    });

    test('처음 고를 때는 가까운 쪽', () {
      final a = _spot(1);
      final b = _spot(2, northMeters: 400);
      // 사람 북쪽 220m → A 220m · B 180m, 둘 다 근처.
      expect(_at(220, [a, b])!.spot.id, 2);
    });

    test('알리던 스팟이 여전히 같은 단계면 바꾸지 않는다 — 두 스팟 사이를 걸을 때 문구가 번갈아 바뀌지 않게', () {
      final a = _spot(1);
      final b = _spot(2, northMeters: 400);
      final previous = _at(150, [a, b]); // A 150m · B 250m → A
      expect(previous!.spot.id, 1);
      // 북쪽 220m 로 걸어감 → B(180m)가 더 가깝지만 A(220m)도 아직 근처다.
      expect(_at(220, [a, b], previous: previous)!.spot.id, 1);
    });

    test('인증 단계에서는 확실히 더 가까운 스팟으로 바꾼다 — 인증은 지금 서 있는 곳이어야 한다', () {
      // 시청 앞처럼 두 스팟이 100m 안에 겹친다: A 기준점, B 북쪽 80m.
      final a = _spot(1);
      final b = _spot(2, northMeters: 80);
      final previous = _at(10, [a, b]); // A 10m · B 70m → A 인증 가능
      expect(previous!.spot.id, 1);
      expect(previous.level, ProximityLevel.verifiable);
      // 북쪽 70m 로 이동 → A 70m · B 10m. 60m 차이는 여유(20m)를 넘으므로 B 로 바꾼다.
      expect(_at(70, [a, b], previous: previous)!.spot.id, 2);
    });

    test('인증 단계라도 몇 m 차이로는 바꾸지 않는다 — GPS 가 튀어도 문구가 흔들리지 않게', () {
      final a = _spot(1);
      final b = _spot(2, northMeters: 80);
      final previous = _at(10, [a, b]); // A
      // 북쪽 45m → A 45m · B 35m. 10m 차이는 여유(20m) 안이라 A 유지.
      expect(_at(45, [a, b], previous: previous)!.spot.id, 1);
    });

    test('GPS 정확도가 나쁘면 그만큼 여유를 둔다 — 실내에서 30m 떨어진 두 스팟이 번갈아 뜨지 않게', () {
      final a = _spot(1);
      final b = _spot(2, northMeters: 80);
      final previous = _at(10, [a, b]); // A
      // 북쪽 70m → A 70m · B 10m. 60m 차이지만 정확도가 80m 면 여유 안이라 A 유지.
      expect(_at(70, [a, b], previous: previous, accuracy: 80)!.spot.id, 1);
      // 정확도가 좋으면(10m) 기본 여유 20m 라 B 로 바꾼다.
      expect(_at(70, [a, b], previous: previous, accuracy: 10)!.spot.id, 2);
    });

    test('알리던 스팟이 후보에서 빠지면 조용히 사라진다', () {
      final previous = _at(50, [spot]);
      expect(_at(50, [], previous: previous), isNull);
    });
  });
}
