import '../services/spot_proximity.dart';

/// 지도 우상단 상자(`MapTopBar`)가 지금 무엇을 말하고 있는가.
///
/// 한 자리가 세 가지 일을 한다 — 평소엔 **이 지역 탐험률**, 스팟에 다가서면 **알림**,
/// 인증할 수 있게 되면 **인증 버튼**. 아이폰 다이나믹 아일랜드와 같은 방식이다
/// (피그마 메인화면, oorony 09-15): 새 창이 뜨는 게 아니라 **있던 상자가 옆으로 자란다.**
///
/// 그리는 쪽은 `map_top_bar.dart` 의 `MapTopBar`·`ProximityBanner` 다(#237). 이 파일은
/// **무엇을 말할지 고르는 판정**만 들고 있어서 지도 없이 검증된다.
enum ConquestPillMode {
  /// 평소 — 프로필 버튼 아래에 탐험률 숫자만.
  progress,

  /// 스팟 300m 안. 프로필 왼쪽으로 길게 자라며 «○○ 근처예요»를 띄운다. 누르면 접힌다.
  near,

  /// 인증 반경 100m 안. 근처보다 **더 길게** 자라고, 누르면 인증 화면으로 간다.
  verifiable,
}

/// 지금 알약이 무엇을 말해야 하는가.
///
/// 반환값이 하나뿐인 것이 핵심이다 — 「알림이 떴다」와 「탐험률을 보여준다」를 불리언 둘로
/// 두면 **둘 다 참인** 상태를 만들 수 있는데, 여기서는 타입이 그걸 막는다(`mapNoticeFor`
/// 와 같은 판단, #146).
///
/// [dismissedSpotId] 는 사용자가 «근처» 알림을 눌러 닫은 스팟이다. **«인증 가능»은 이 값을
/// 보지 않는다** — 닫힌 채로 인증 기회를 놓치게 두지 않는다. 그래서 닫아 둔 스팟에
/// 100m 까지 더 다가가면 알림이 **다시** 뜬다.
///
/// 지도·위치 스트림과 무관한 순수 함수라 따로 검증한다(`conquest_pill_mode_test.dart`).
ConquestPillMode conquestPillModeFor({
  required SpotProximity? proximity,
  required int? dismissedSpotId,
}) {
  if (proximity == null) return ConquestPillMode.progress;
  if (proximity.level == ProximityLevel.verifiable) return ConquestPillMode.verifiable;
  if (proximity.spot.id == dismissedSpotId) return ConquestPillMode.progress;
  return ConquestPillMode.near;
}
