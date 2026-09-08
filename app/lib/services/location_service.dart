import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'location_permission_gate.dart';

/// 위치를 언제까지 추적할지(#135). 기본값은 [foregroundOnly] —
/// 백그라운드 추적은 상시 알림이 뜨고 배터리를 쓰므로 켜는 사람만 켠다.
enum LocationTrackingMode {
  /// 앱을 보고 있을 때만. 화면이 백그라운드로 가면 GPS를 끈다.
  foregroundOnly,

  /// 화면을 꺼도 계속. Android 포그라운드 서비스가 붙고 **끌 수 없는 상시 알림**이 뜬다.
  always,
}

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

  /// 화면이 꺼진 동안 쓰는 설정(#135).
  ///
  /// **정확도와 주기를 낮춘다.** 걷는 내내 켜져 있게 되므로 포그라운드와 같은 강도로
  /// 돌리면 배터리가 눈에 띄게 준다. 다만 근접 감지(반경 100m)를 놓치면 기능 자체가
  /// 무의미하므로, `distanceFilter` 를 그 절반인 50m 로 두어 반경에 들어가기 전에
  /// 최소 한 번은 갱신이 오도록 했다.
  ///
  /// `foregroundNotificationConfig` 가 있어야 Android 가 포그라운드 서비스로 띄운다 —
  /// 없으면 화면이 꺼진 뒤 잠시 후 OS 가 위치 갱신을 끊는다. 이때 뜨는 **상시 알림은
  /// 사용자가 끌 수 없다**(Android 정책). 그래서 이 모드 자체를 끄는 스위치가 필요하다.
  ///
  /// ⚠️ **Android 전용이다.** iOS 는 출품 범위에서 빠져 있어([#137](../../pull/137))
  /// [AppleSettings] 분기를 두지 않았다. iOS 를 되살린다면 여기서 플랫폼을 갈라
  /// `AppleSettings(allowBackgroundLocationUpdates: true, ...)` 를 함께 줘야 하고,
  /// `Info.plist` 의 `UIBackgroundModes`·`NSLocationAlwaysAndWhenInUseUsageDescription`
  /// 도 같이 필요하다(#135 To-do 3번).
  static final backgroundLocationSettings = AndroidSettings(
    accuracy: LocationAccuracy.medium,
    distanceFilter: 50,
    intervalDuration: const Duration(seconds: 30),
    foregroundNotificationConfig: const ForegroundNotificationConfig(
      notificationTitle: 'FogApp 이 주변을 살피고 있어요',
      notificationText: '근처에 인증할 수 있는 스팟이 나타나면 알려드립니다',
      notificationChannelName: '탐험 중 위치 추적',
      enableWakeLock: true,
      setOngoing: true,
    ),
  );

  final _positions = StreamController<Position>.broadcast();
  StreamSubscription<Position>? _subscription;
  Position? _lastKnown;

  /// 사용자가 고른 추적 방식(#135). 기본값은 **꺼짐**([LocationTrackingMode.foregroundOnly]) —
  /// 백그라운드 위치는 켜는 사람만 켜는 기능이다.
  LocationTrackingMode _mode = LocationTrackingMode.foregroundOnly;

  /// 앱이 화면에 떠 있는지. 화면이 알려준다.
  bool _appInForeground = true;

  /// 추적을 원하는 상태인지([start] 했고 아직 [stop] 안 함).
  bool _started = false;

  /// 지금 돌고 있는 구독이 백그라운드 설정인지 — 설정이 바뀔 때만 다시 구독한다.
  bool _runningInBackground = false;

  LocationTrackingMode get mode => _mode;

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

  /// 위치 추적을 시작한다. 위치 서비스가 꺼져 있거나 권한이 없으면 `false`.
  Future<bool> start() {
    _started = true;
    return _apply();
  }

  /// 위치 추적을 멈춘다. [lastKnown]은 남긴다.
  void stop() {
    _started = false;
    _cancel();
  }

  /// 앱이 화면에 떠 있는지 알린다. **화면은 사실만 알리고, 어떻게 할지는 여기서 정한다** —
  /// 예전에는 `MapScreen` 이 직접 구독을 끊었고, 그래서 백그라운드 추적을 넣으려면
  /// 화면 코드를 고쳐야 했다(#135).
  Future<void> setAppInForeground(bool inForeground) {
    if (_appInForeground == inForeground) return Future.value();
    _appInForeground = inForeground;
    return _apply().then((_) {});
  }

  /// 사용자 설정(#135 To-do "끌 수 있는 스위치")을 반영한다.
  Future<void> setMode(LocationTrackingMode mode) {
    if (_mode == mode) return Future.value();
    _mode = mode;
    return _apply().then((_) {});
  }

  /// 지금 상태에 맞는 구독을 만든다 — 필요 없으면 끊고, 설정이 달라졌으면 다시 연다.
  Future<bool> _apply() async {
    final shouldTrack =
        _started && (_appInForeground || _mode == LocationTrackingMode.always);
    if (!shouldTrack) {
      _cancel();
      return false;
    }

    // 백그라운드에서만 포그라운드 서비스 설정을 쓴다 — 앱을 보고 있는 동안에는
    // 상시 알림을 띄울 이유가 없다.
    final wantBackground = !_appInForeground;
    if (_subscription != null && _runningInBackground == wantBackground) return true;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    final permission = await LocationPermissionGate.request();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    _cancel();
    _subscription = Geolocator.getPositionStream(
      locationSettings: wantBackground ? backgroundLocationSettings : locationSettings,
    ).listen(
      (position) {
        _lastKnown = position;
        _positions.add(position);
      },
      onError: (Object error) {
        // 스트림을 끊지 않는다 — GPS가 일시적으로 실패해도 다음 측정에서 복구된다.
        debugPrint('[LocationService] 위치 스트림 오류: $error');
      },
    );
    _runningInBackground = wantBackground;
    return true;
  }

  void _cancel() {
    _subscription?.cancel();
    _subscription = null;
    _runningInBackground = false;
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
