import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'location_permission_gate.dart';

/// 앱 전체가 공유하는 **단일 위치 소스**(#135 6-5의 1번 항목).
///
/// 예전에는 GPS 스트림이 두 곳에서 각자 열렸다.
///
/// | 열던 곳 | 먹여주던 것 |
/// |---|---|
/// | `FogLocationTracker` | 지도 SDK의 내 위치 표시(#29) |
/// | `MapScreen._startGeofenceTracking()` | 근접 감지(#45) · 발자취 반경 조회(#117) |
///
/// 캐릭터·여정(#131)까지 각자 열면 셋이 되고, 백그라운드 추적(#135)이 넷째가 된다.
/// 여기서 하나만 열어 나눠준다.
///
/// **개수보다 소유권이 문제였다.** 두 번째 구독의 수명을 `MapScreen`이 쥐고 있어서,
/// 화면이 없으면 위치도 없었다. 이제 수명은 이 서비스가 가진다 — 지금은 `MapScreen`이
/// 포그라운드/백그라운드 전환에 맞춰 [start]·[stop]을 부르지만, **그 판단만 6-5에서
/// 사용자 설정으로 옮기면 되고 구독자 코드는 그대로다.**
class LocationService {
  /// 배터리 절충안. 모든 구독자가 이 설정 하나를 공유한다.
  ///
  /// 예전에는 이 상수가 `FogLocationTracker`에 있으면서 "다른 곳이 다른 정확도로 열지
  /// 않게" 막는 역할을 했다 — 이제 구독 자체가 하나뿐이라 구조적으로 보장된다.
  ///
  /// - 정확도: [LocationAccuracy.high] (`best`/`bestForNavigation`은 배터리 소모가 크다)
  /// - `distanceFilter`: 15m 이상 이동했을 때만 갱신 — 제자리에서의 불필요한 갱신을 막는다
  ///
  /// 백그라운드에서는 주기·정확도를 낮춰야 하는데(#135 To-do), 그때는 이 설정을 갈아끼우고
  /// 내부 구독만 다시 만들면 된다 — **구독자는 그걸 몰라도 된다.**
  static const locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 15,
  );

  final _positions = StreamController<Position>.broadcast();
  StreamSubscription<Position>? _subscription;
  Position? _lastKnown;

  /// 위치 갱신. 구독자가 몇이든 실제 GPS 구독은 하나다.
  Stream<Position> get positions => _positions.stream;

  /// 마지막으로 받은 위치. 추적을 멈춰도 지운다 — 화면이 다시 열렸을 때 마지막으로
  /// 알던 자리를 그대로 쓸 수 있어야 한다.
  ///
  /// **늦게 구독한 쪽에는 이 값이 반드시 필요하다.** `distanceFilter: 15`라 제자리에
  /// 서 있으면 다음 이벤트가 오지 않아서, 스트림만 보고 있으면 위치를 영영 못 받는다.
  Position? get lastKnown => _lastKnown;

  /// 나침반 방향. GPS 이동 방향(`Position.heading`)은 실제로 움직여야 갱신되어
  /// **제자리에서 기기만 돌렸을 때 반응하지 않는다**(#29). 캐릭터 방향(#131)이 이걸 쓴다.
  Stream<double> get headings => (FlutterCompass.events ?? const Stream.empty())
      .map((event) => event.heading)
      .where((heading) => heading != null)
      .cast<double>();

  bool get isTracking => _subscription != null;

  /// 위치 추적을 시작한다. 이미 돌고 있으면 아무 일도 하지 않는다.
  /// 위치 서비스가 꺼져 있거나 권한이 없으면 `false`.
  Future<bool> start() async {
    if (_subscription != null) return true;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    final permission = await LocationPermissionGate.request();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    _subscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (position) {
        _lastKnown = position;
        _positions.add(position);
      },
      onError: (Object error) {
        // 스트림을 끊지 않는다 — GPS가 일시적으로 실패해도 다음 측정에서 복구된다.
        debugPrint('[LocationService] 위치 스트림 오류: $error');
      },
    );
    return true;
  }

  /// 위치 추적을 멈춘다. [lastKnown]은 남긴다.
  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// 지금 위치를 한 번 측정한다. 스트림 첫 값을 기다릴 수 없을 때 쓴다
  /// (예: 지도 진입 직후 내 위치 표시의 초기값).
  Future<Position?> currentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(desiredAccuracy: locationSettings.accuracy);
    } catch (e) {
      debugPrint('[LocationService] 현재 위치 측정 실패: $e');
      return null;
    }
  }

  void dispose() {
    stop();
    _positions.close();
  }
}

final locationServiceProvider = Provider<LocationService>((ref) {
  final service = LocationService();
  ref.onDispose(service.dispose);
  return service;
});
