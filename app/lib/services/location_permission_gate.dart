import 'package:geolocator/geolocator.dart';

/// 위치 권한 요청을 앱 전체에서 한 번에 하나만 진행되도록 직렬화한다.
///
/// `MapScreen._requestLocationPermission()`과 `FogLocationTracker.
/// startLocationService()`(네이티브 "내 위치" 버튼 탭 시에도 호출됨)가 각자
/// 독립적으로 `Geolocator.requestPermission()`을 호출할 수 있는데, 두 호출이
/// 겹치면 Android가 "Can request only one set of permissions at a time"
/// 경고와 함께 나중 요청을 빈 결과로 무시한다(#26에서 발견/수정된 버그).
/// 호출 시점이 다른 두 곳이라 타이밍만으로는 재발을 막을 수 없어, 진행 중인
/// 요청이 있으면 새 요청을 만들지 않고 그 결과를 그대로 공유하도록 한다.
class LocationPermissionGate {
  LocationPermissionGate._();

  static Future<LocationPermission>? _inFlight;

  static Future<LocationPermission> request() {
    return _inFlight ??= _requestOnce().whenComplete(() => _inFlight = null);
  }

  static Future<LocationPermission> _requestOnce() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }
}
