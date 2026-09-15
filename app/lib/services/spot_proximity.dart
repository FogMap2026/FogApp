import 'dart:math';

import 'package:geolocator/geolocator.dart';

import '../models/spot.dart';

/// 스팟에 얼마나 가까운가 — 지도 우하단 근접 아이콘의 두 단계.
enum ProximityLevel {
  /// [SpotProximity.nearEnterMeters] 안. 조용한 «!» 아이콘만 뜬다 — 눌러야 알림으로 펼쳐진다.
  near,

  /// 인증 반경([SpotProximity.verifyEnterMeters]) 안. 진동과 함께 눈에 띄는 인증 아이콘이 뜨고,
  /// 누르면 곧바로 인증 화면으로 간다.
  verifiable,
}

/// 지금 알릴 스팟 하나와 그 단계.
class SpotProximity {
  const SpotProximity({required this.spot, required this.distanceMeters, required this.level});

  final Spot spot;
  final double distanceMeters;
  final ProximityLevel level;

  /// «근처» 진입 반경. 걸어서 4분쯤 — 아이콘을 보고 방향을 틀 여유가 있는 거리다.
  /// 인증 반경의 세 배라, 아이콘이 뜬 뒤 바로 인증 단계로 넘어가 버리지 않는다.
  static const nearEnterMeters = 300.0;

  /// «근처» 이탈 반경. 진입보다 크게 잡아 경계에서 GPS 가 흔들릴 때 아이콘이
  /// 떴다 꺼졌다 하지 않게 한다(히스테리시스).
  static const nearExitMeters = 350.0;

  /// 인증 가능 반경. 🔴 **서버 `visit.radius-meters`(100)와 같은 값이어야 한다** — 앱이 더
  /// 넓으면 «인증하세요» 아이콘을 눌러도 서버가 422 로 거절하고, 더 좁으면 인증할 수
  /// 있는 자리에서 아이콘이 안 뜬다.
  static const verifyEnterMeters = 100.0;

  /// 인증 단계 이탈 반경 — 예전 `SpotGeofenceController` 의 130m 를 그대로 잇는다.
  static const verifyExitMeters = 130.0;

  /// 인증 단계에서 알리던 스팟을 **바꾸는** 기준 — 다른 스팟이 이만큼 더 가까워야 바꾼다.
  ///
  /// 인천시청 앞처럼 스팟 셋이 100m 안에 겹치면, 처음 잡은 스팟이 그대로 남아 「인천애뜰 인증
  /// 가능」인데 실제로는 한복사랑 앞에 서 있는 일이 났다(시진, 실기기 09-14). 인증은 «지금 서
  /// 있는 곳»이 중요하니 가까운 쪽으로 바꾸되, GPS 가 튀는 몇 m 로 왔다 갔다 하지 않게 여유를 둔다.
  ///
  /// GPS 정확도가 이보다 나쁘면(실내 50~100m) 정확도만큼을 여유로 쓴다 — 인천애뜰과 한복사랑처럼
  /// 30m 떨어진 두 스팟 사이에서 실내 좌표가 튈 때마다 문구가 번갈아 바뀌었다(시진, 09-15).
  static const verifySwitchMarginMeters = 20.0;

  static double switchMargin(double? accuracyMeters) =>
      accuracyMeters == null ? verifySwitchMarginMeters : max(verifySwitchMarginMeters, accuracyMeters);
}

/// [candidates] 가운데 지금 알릴 스팟을 고른다. 알릴 것이 없으면 `null`.
///
/// - 이미 인증한 스팟([visitedSpotIds])은 알리지 않는다.
/// - **단계가 높은 쪽이 이긴다** — 인증할 수 있는 스팟이 있으면 더 가까운 «근처» 스팟보다 먼저다.
/// - 같은 «근처» 단계면 **지금 알리고 있던 스팟([previous])을 유지한다.** 두 스팟 사이를 걸을 때
///   15m 마다 대상이 번갈아 바뀌면 펼쳐 둔 알림 문구가 계속 바뀐다. 처음 고를 때만 가까운 쪽.
/// - «인증 가능» 단계는 예외 — 다른 스팟이 [SpotProximity.verifySwitchMarginMeters] 이상 더
///   가까우면 그쪽으로 바꾼다. 인증은 지금 서 있는 스팟이어야 한다.
/// - 이탈은 [previous] 로 판정한다 — 이미 알리던 스팟은 이탈 반경까지 붙잡아 둔다.
///
/// 후보에서 빠진 스팟(지도를 멀리 옮겨 목록이 바뀐 경우)은 조용히 사라진다. 실제로 멀어졌다고
/// 볼 수는 없지만, 좌표를 모르는 스팟을 계속 알릴 수도 없다.
///
/// 위치 소스와 무관한 순수 함수라 지도 없이 검증한다(`spot_proximity_test.dart`).
SpotProximity? resolveSpotProximity({
  required Iterable<Spot> candidates,
  required double lat,
  required double lng,
  Set<int> visitedSpotIds = const {},
  SpotProximity? previous,
  double? accuracyMeters,
}) {
  final margin = SpotProximity.switchMargin(accuracyMeters);
  SpotProximity? best;
  for (final spot in candidates) {
    if (visitedSpotIds.contains(spot.id)) continue;
    final distance = Geolocator.distanceBetween(lat, lng, spot.lat, spot.lng);
    final wasLevel = previous?.spot.id == spot.id ? previous!.level : null;
    final level = _levelFor(distance, wasLevel);
    if (level == null) continue;
    final candidate = SpotProximity(spot: spot, distanceMeters: distance, level: level);
    if (best == null || _outranks(candidate, best, previous?.spot.id, margin)) best = candidate;
  }
  return best;
}

ProximityLevel? _levelFor(double distance, ProximityLevel? wasLevel) {
  final verifyLimit =
      wasLevel == ProximityLevel.verifiable ? SpotProximity.verifyExitMeters : SpotProximity.verifyEnterMeters;
  if (distance <= verifyLimit) return ProximityLevel.verifiable;
  final nearLimit = wasLevel != null ? SpotProximity.nearExitMeters : SpotProximity.nearEnterMeters;
  if (distance <= nearLimit) return ProximityLevel.near;
  return null;
}

/// 근접 판정 후보 스팟 — **내 위치 기준으로 불러온 목록만** 받아들인다.
///
/// 지도 마커는 📍 모드(화면 중심 기준 조회)에서 지도를 민 곳의 스팟으로 바뀐다. 그 목록을
/// 근접 판정에 그대로 쓰면, 지도를 멀리 민 순간 **실제로 스팟 옆에 서 있어도 「인증 가능」이
/// 사라진다** — 후보에서 빠진 스팟은 조용히 사라지기 때문이다([resolveSpotProximity]).
/// 근접은 «내가 어디 있나»의 문제라 화면이 어디를 보고 있는지와 무관해야 한다.
///
/// 조회를 보낼 때 [expectLoadAt] 으로 중심을 적어 두고, 결과는 [offer] 로 내민다 — 중심이
/// 다르면 버린다. 덕분에 걷는 사이 **먼저 보낸 옛 위치 조회가 늦게 도착해도** 새 목록을
/// 덮어쓰지 않는다.
///
/// 지도 없이 검증하려고 좌표를 `NLatLng` 대신 숫자로 받는다(`spot_proximity_test.dart`).
class ProximityCandidates {
  List<Spot> _spots = const [];
  ({double lat, double lng})? _expected;

  /// 지금 근접 판정에 쓸 목록.
  List<Spot> get spots => _spots;

  /// 내 위치 기준 조회를 보냈다 — 이 중심에서 온 결과만 받아들인다.
  void expectLoadAt({required double lat, required double lng}) => _expected = (lat: lat, lng: lng);

  /// 조회 결과를 내민다. [lat]·[lng] 는 그 조회의 중심. 받아들였으면 `true` — 호출부가 근접을
  /// 다시 계산한다. 기다리던 내 위치 조회가 아니면(화면 중심 조회, 옛 위치 조회) `false`.
  bool offer(List<Spot> spots, {required double lat, required double lng}) {
    if (_expected != (lat: lat, lng: lng)) return false;
    _spots = spots;
    return true;
  }
}

bool _outranks(SpotProximity a, SpotProximity b, int? previousSpotId, double margin) {
  if (a.level != b.level) return a.level.index > b.level.index;
  if (a.level == ProximityLevel.verifiable) {
    // 인증 단계: 알리던 스팟이라도 다른 스팟이 여유(20m, 정확도가 나쁘면 그만큼) 이상 더 가까우면 넘겨준다.
    if (b.spot.id == previousSpotId) return a.distanceMeters + margin < b.distanceMeters;
    if (a.spot.id == previousSpotId) return b.distanceMeters + margin >= a.distanceMeters;
    return a.distanceMeters < b.distanceMeters;
  }
  if (b.spot.id == previousSpotId) return false;
  if (a.spot.id == previousSpotId) return true;
  return a.distanceMeters < b.distanceMeters;
}
