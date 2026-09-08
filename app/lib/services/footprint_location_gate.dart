import 'package:geolocator/geolocator.dart';

import 'location_permission_gate.dart';

/// 발자취 작성 시 "여기"라고 말할 수 있을 만큼 위치가 정확한지 확인한다(#118).
///
/// 서버는 사용자의 진짜 위치를 모르므로 좌표 자체를 검증할 수 없다
/// (docs/footprint-redesign.md 5-2) — 그래서 앱이 GPS 측정치의 정확도
/// (`Position.accuracy`, 미터)를 직접 확인한다.
///
/// **이 값 이내면 아무것도 묻지 않고 그대로 쓴다.** 넘으면 막지 않고 오차를 알린 뒤
/// 사용자에게 맡긴다(3-1 보완) — 10m는 보안 규칙이 아니라 품질 규칙이라, 막다른 길로
/// 두면 실내(보통 20~50m)에서는 글을 아예 남길 수 없다.
///
/// 단, 무한정 열어두지는 않는다. [maxConfirmableAccuracyMeters] 참고.
const double maxFootprintAccuracyMeters = 10;

/// 동의를 받아도 이 값을 넘으면 작성을 막는다.
///
/// 10m 규칙이 실제로 막고 있던 것은 좌표 위조(= 악의)가 아니라 **사고성 오배치**다 —
/// 설계 문서 3-1의 *"이보다 넓으면 보지도 않은 골목에 글을 남길 수 있다"* 가 그 얘기다.
/// 그런데 사용자는 "35m면 뭐" 하고 누르지, GPS가 튀어서 나온 2km를 상상하고 누르지 않는다.
/// 오차를 숫자로 보여주는 것만으로는 그 판단을 맡길 수 없다.
///
/// **100m는 방문 인증 반경(`VisitProperties.radiusMeters`)과 같은 값이다.** 그보다 멀면
/// "여기"라는 말 자체가 성립하지 않는다고 보는 것이 이 앱의 이미 정한 기준이다.
/// 실내 20~50m는 그대로 통과한다.
const double maxConfirmableAccuracyMeters = 100;

sealed class FootprintLocationCheck {
  const FootprintLocationCheck();
}

/// 위치를 정확도 안에서 얻었다. 이 좌표를 그대로 써도 된다.
class FootprintLocationReady extends FootprintLocationCheck {
  const FootprintLocationReady({required this.lat, required this.lng});
  final double lat;
  final double lng;
}

/// 위치 서비스(GPS)가 꺼져 있거나 권한이 없다.
class FootprintLocationUnavailable extends FootprintLocationCheck {
  const FootprintLocationUnavailable();
}

/// 위치는 얻었지만 정확도가 [maxFootprintAccuracyMeters]를 넘는다 —
/// 실내·건물 사이 등에서 흔하다.
///
/// **좌표를 함께 담아 돌려준다.** 10m는 보안 규칙이 아니라 "여기라고 말할 수
/// 있는 범위"를 지키기 위한 UX 규칙이라(docs/footprint-redesign.md 3-1·5-2),
/// 막다른 길로 두면 실내에서는 글을 아예 남길 수 없다. 호출부가 오차를
/// 사용자에게 알리고 동의를 받은 뒤 이 좌표를 쓸 수 있게 한다.
class FootprintLocationInaccurate extends FootprintLocationCheck {
  const FootprintLocationInaccurate({
    required this.accuracyMeters,
    required this.lat,
    required this.lng,
  });
  final double accuracyMeters;
  final double lat;
  final double lng;
}

/// 정확도가 [maxConfirmableAccuracyMeters]마저 넘는다 — 동의를 받아도 쓰지 않는다.
///
/// 좌표를 담지 않는다. 쓸 일이 없기 때문이다.
class FootprintLocationTooInaccurate extends FootprintLocationCheck {
  const FootprintLocationTooInaccurate(this.accuracyMeters);
  final double accuracyMeters;
}

/// GPS 측정 자체가 실패했다(타임아웃 등).
class FootprintLocationFailed extends FootprintLocationCheck {
  const FootprintLocationFailed();
}

/// 정확도를 세 구간으로 가른다. `Position` 전체가 아니라 정확도 값만 받아 순수 함수로
/// 두어 테스트하기 쉽게 한다.
///
/// | 정확도 | 결과 |
/// |---|---|
/// | ~ [maxFootprintAccuracyMeters] | [FootprintLocationReady] — 묻지 않는다 |
/// | ~ [maxConfirmableAccuracyMeters] | [FootprintLocationInaccurate] — 오차를 알리고 맡긴다 |
/// | 그 위 | [FootprintLocationTooInaccurate] — 막는다 |
FootprintLocationCheck classifyFootprintLocation({
  required double lat,
  required double lng,
  required double accuracyMeters,
}) {
  if (accuracyMeters > maxConfirmableAccuracyMeters) {
    return FootprintLocationTooInaccurate(accuracyMeters);
  }
  if (accuracyMeters > maxFootprintAccuracyMeters) {
    return FootprintLocationInaccurate(
      accuracyMeters: accuracyMeters,
      lat: lat,
      lng: lng,
    );
  }
  return FootprintLocationReady(lat: lat, lng: lng);
}

/// 현재 위치를 새로 측정해 발자취 작성에 쓸 수 있는지 판정한다.
class FootprintLocationGate {
  const FootprintLocationGate._();

  static Future<FootprintLocationCheck> check() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return const FootprintLocationUnavailable();

    final permission = await LocationPermissionGate.request();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return const FootprintLocationUnavailable();
    }

    try {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      return classifyFootprintLocation(
        lat: position.latitude,
        lng: position.longitude,
        accuracyMeters: position.accuracy,
      );
    } catch (_) {
      return const FootprintLocationFailed();
    }
  }
}
