import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';

import 'location_permission_gate.dart';

/// 배터리를 고려한 실시간 위치 추적기(#29).
///
/// flutter_naver_map의 기본 트래커([NDefaultMyLocationTracker])는 위치 갱신
/// 주기·정확도를 Dart 쪽에서 설정할 방법이 없다(네이티브 코드에 고정되어 있음).
/// 이미 의존성으로 들어와 있는 `geolocator`로 직접 구현해 다음을 명시적으로 제어한다.
///
/// - 정확도: [LocationAccuracy.high] (배터리 소모가 큰 `best`/`bestForNavigation` 대신)
/// - 갱신 조건: 15m 이상 이동했을 때만 갱신([_locationSettings]의 `distanceFilter`) —
///   제자리에 멈춰 있을 때 불필요한 GPS 갱신을 막는다.
/// - 방향(heading)은 GPS가 아니라 나침반 센서(`flutter_compass`)를 사용한다 — GPS
///   이동 방향은 실제로 움직여야만 갱신되어, 제자리에서 기기를 돌렸을 때 화살표가
///   반응하지 않는 문제가 있다.
///
/// 포그라운드/백그라운드 전환 시 스트림 구독을 멈추고 재개하는 것은 상위 클래스
/// [NMyLocationTracker]가 기본으로 처리한다. `MapScreen`은 여기에 더해 백그라운드
/// 진입 시 추적 모드 자체를 끄는 더 적극적인 절전 처리를 별도로 수행한다.
class FogLocationTracker extends NMyLocationTracker {
  /// geofencing(#45) 등 다른 위치 구독자도 같은 배터리 절충안을 쓰도록 공개해둔다 —
  /// 독립된 GPS 스트림을 또 만들 때 서로 다른 정확도/주기를 쓰지 않게 하기 위함.
  static const locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 15,
  );

  @override
  Future<NLatLng?> startLocationService() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    final permission = await LocationPermissionGate.request();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: locationSettings.accuracy,
    );
    return NLatLng(position.latitude, position.longitude);
  }

  @override
  Stream<NLatLng> get locationStream => Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).map((p) => NLatLng(p.latitude, p.longitude));

  /// 나침반(자기장 센서) 기반 heading. GPS 이동 방향(`Position.heading`)은 실제로
  /// 이동해야만 값이 바뀌어 "제자리에서 폰만 돌렸을 때" 화살표가 반응하지 않는
  /// 문제가 있어, 기기를 돌리는 즉시 반응하는 나침반 값을 사용한다.
  @override
  Stream<double> get headingStream =>
      (FlutterCompass.events ?? const Stream.empty())
          .map((event) => event.heading)
          .where((heading) => heading != null)
          .cast<double>();
}
