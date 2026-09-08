import 'package:geolocator/geolocator.dart';

import 'location_permission_gate.dart';

/// 발자취 작성 시 "여기"라고 말할 수 있을 만큼 위치가 정확한지 확인한다(#118).
///
/// 서버는 사용자의 진짜 위치를 모르므로 좌표 자체를 검증할 수 없다
/// (docs/footprint-redesign.md 5-2) — 그래서 앱이 GPS 측정치의 정확도
/// (`Position.accuracy`, 미터)를 직접 확인한다. 정확도가 이 값 이내인 측정치를
/// 그대로 좌표로 쓰면 "좌표가 실제 위치에서 10m 이내"라는 설계 요구(3-1)를
/// 만족한다 — 이 흐름에는 좌표를 사용자가 직접 조작할 방법이 없기 때문이다.
const double maxFootprintAccuracyMeters = 10;

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

/// GPS 측정 자체가 실패했다(타임아웃 등).
class FootprintLocationFailed extends FootprintLocationCheck {
  const FootprintLocationFailed();
}

/// [accuracyMeters]가 [maxFootprintAccuracyMeters] 이내인지로 판정한다.
/// `Position` 전체가 아니라 정확도 값만 받아 순수 함수로 두어 테스트하기 쉽게 한다.
FootprintLocationCheck classifyFootprintLocation({
  required double lat,
  required double lng,
  required double accuracyMeters,
}) {
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
