// 걸어온 자리의 안개 — 격자 키와 «정확도 게이트».
//
// 지도 컨트롤러가 필요한 `FogOverlayController` 대신 판정만 떼어 검증한다 —
// `mapNoticeFor`·`classifyFootprintLocation` 과 같은 이유다.
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogapp/services/fog_overlay_controller.dart';
import 'package:fogapp/services/footprint_location_gate.dart';

/// 위도 1도 ≒ 111,320m. 테스트에서 「N미터 떨어진 좌표」를 만들 때 쓴다.
const _metersPerDegreeLat = 111320.0;

NLatLng _movedNorth(NLatLng from, double meters) =>
    NLatLng(from.latitude + meters / _metersPerDegreeLat, from.longitude);

void main() {
  // 서울 시청 근처. 위도 37.5 에서 경도 보정이 실제로 걸린다.
  const seoul = NLatLng(37.5665, 126.9780);
  const cell = FogOverlayController.trailRadiusMeters; // 15m

  test('같은 칸을 다시 밟으면 같은 키다 — 구멍이 늘지 않는다', () {
    // 5m 이동은 15m 격자 안에서 같은 칸일 수도, 경계를 넘을 수도 있다.
    // 「바로 그 자리」는 반드시 같아야 한다.
    expect(fogTrailKey(seoul, cell), fogTrailKey(seoul, cell));
  });

  test('한 칸 이상 움직이면 다른 키다 — 길이 이어진다', () {
    // 45m = 3칸. 경계에 걸쳐도 확실히 다른 칸이다.
    final far = _movedNorth(seoul, cell * 3);

    expect(fogTrailKey(far, cell), isNot(fogTrailKey(seoul, cell)));
  });

  test('격자 안의 미세 이동은 키를 바꾸지 않는다', () {
    // 같은 칸 중앙 근처에서 1m 움직인 경우. GPS 지터로 흔히 생긴다 —
    // 이때마다 새 구멍이 생기면 제자리에서도 목록이 계속 늘어난다.
    final center = NLatLng(
      (seoul.latitude / (cell / _metersPerDegreeLat)).roundToDouble() * (cell / _metersPerDegreeLat),
      seoul.longitude,
    );
    final jitter = _movedNorth(center, 1);

    expect(fogTrailKey(jitter, cell), fogTrailKey(center, cell));
  });

  test('🔴 스팟 id 와 절대 겹치지 않는다 — 겹치면 걷힌 스팟이 다시 잠긴다', () {
    // 구멍은 스팟과 궤적이 «한 Map» 에 담긴다. 스팟 키는 id 문자열("12")이므로,
    // 궤적 키가 그런 모양이 되면 인증으로 걷어낸 구멍을 덮어쓴다.
    final key = fogTrailKey(seoul, cell);

    expect(key, startsWith('trail:'));
    expect(int.tryParse(key), isNull, reason: '숫자만으로 된 키는 스팟 id 와 충돌한다');
  });

  test('경도 보정이 걸린다 — 위도가 다르면 같은 경도라도 칸이 다르게 나뉜다', () {
    // cos(lat) 보정을 빼면 북쪽에서 격자가 촘촘해져, 같은 거리를 움직여도
    // 칸이 더 많이 쪼개진다. 제주(33도)와 강원(38도)에서 경도 칸 크기가 달라야 한다.
    const jeju = NLatLng(33.4, 126.5);
    const gangwon = NLatLng(38.2, 126.5);

    // 같은 경도인데 위도가 달라 lngStep 이 다르므로, 경도 칸 번호가 달라진다.
    final jejuLngCell = fogTrailKey(jeju, cell).split(':')[2];
    final gangwonLngCell = fogTrailKey(gangwon, cell).split(':')[2];

    expect(jejuLngCell, isNot(gangwonLngCell));
  });

  test('격자 크기를 키우면 같은 두 점이 한 칸으로 묶인다', () {
    final p = _movedNorth(seoul, 20);

    // 15m 격자에서는 다른 칸
    expect(fogTrailKey(p, 15), isNot(fogTrailKey(seoul, 15)));
    // 150m 격자(인증 반경)에서는 같은 칸 — 반경이 곧 칸 크기라는 관계를 고정한다
    expect(fogTrailKey(p, 150), fogTrailKey(seoul, 150));
  });

  // ── 정확도 게이트(#131 리뷰) ───────────────────────────────────────────
  // 🔴 궤적은 «지우는 길이 없다». 인증·발자취와 달리 이용자가 그 자리에 있었다는
  //    판정을 안 거치고, 삭제 API 도 없다 — 튄 점 하나가 영영 남는다.

  test('걷는 동안의 흔한 정확도는 통과한다', () {
    // 도심 실외 GPS 는 보통 5~20m 다. 여기가 걸리면 길이 끊긴다.
    for (final a in [4.0, 8.0, 12.0, 20.0, 35.0]) {
      expect(isTrailWorthyAccuracy(a), isTrue, reason: '$a m 가 걸렸다');
    }
  });

  test('콜드 스타트 첫 fix 처럼 크게 튄 것은 버린다', () {
    // 네트워크 측위는 수백 m~수 km 다. distanceFilter 15 는 이걸 «이동»으로 준다.
    for (final a in [51.0, 120.0, 500.0, 2000.0]) {
      expect(isTrailWorthyAccuracy(a), isFalse, reason: '$a m 가 통과했다');
    }
  });

  test('정확도를 «모를 때»는 믿지 않는다', () {
    // Android 는 Location.hasAccuracy() 가 false 면 0 을 준다. 0 을 「완벽」으로
    // 읽으면 가장 못 믿을 측정치가 가장 먼저 통과한다.
    expect(isTrailWorthyAccuracy(0), isFalse);
    expect(isTrailWorthyAccuracy(-1), isFalse);
  });

  test('경계는 상한 «이하»까지다', () {
    expect(isTrailWorthyAccuracy(trailMaxAccuracyMeters), isTrue);
    expect(isTrailWorthyAccuracy(trailMaxAccuracyMeters + 0.1), isFalse);
  });

  test('상한이 궤적 반경보다 «크다» — 그래야 걷는 동안 길이 안 끊긴다', () {
    // 상한을 반경(15m)까지 조이면 실외에서도 자주 걸려 길이 점선이 된다.
    // 반대로 너무 열면 「걸어온 자리」가 아니라 「그 근처 어딘가」가 된다.
    expect(trailMaxAccuracyMeters, greaterThan(FogOverlayController.trailRadiusMeters));
    expect(trailMaxAccuracyMeters, lessThan(maxConfirmableAccuracyMeters));
  });
}
