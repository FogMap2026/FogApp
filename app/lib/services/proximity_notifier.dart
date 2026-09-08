import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 화면이 꺼져 있을 때 스팟 근접을 알리는 **로컬 알림**(#135, 3-2에서 이관된 #46의 나머지).
///
/// 포그라운드에서는 지도 위 배너로 알린다(#46) — 앱을 보고 있는데 알림 표시줄로
/// 보내면 오히려 흐름이 끊긴다. 이 클래스는 **화면이 꺼진 동안에만** 쓴다.
///
/// FCM(`firebase_messaging`)과는 다르다. FCM 은 서버가 보내는 푸시(6-4, #134)이고,
/// 이건 기기가 스스로 띄우는 알림이라 서버가 필요 없다 — 근접 판정 자체가 기기에서
/// 일어나기 때문이다([SpotGeofenceController]).
class ProximityNotifier {
  ProximityNotifier(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _channelId = 'fogapp_proximity';
  static const _channelName = '주변 스팟 알림';
  static const _channelDescription = '근처에 인증할 수 있는 스팟이 있을 때 알려줍니다';

  bool _initialized = false;

  /// 알림 채널을 준비한다. 여러 번 불러도 한 번만 수행한다.
  Future<void> init() async {
    if (_initialized) return;
    // 런처 아이콘을 그대로 쓴다 — 알림 전용 아이콘은 아직 없다(#143 에서 런처만 정리됨).
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  /// Android 13+ 의 알림 권한을 요청한다. 거부돼도 앱은 그대로 동작한다 —
  /// 백그라운드 알림만 안 뜬다.
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    return await android.requestNotificationsPermission() ?? false;
  }

  /// 스팟 반경에 들어왔음을 알린다.
  ///
  /// 알림 id 로 [spotId] 를 쓴다 — 같은 스팟이 여러 번 잡혀도 알림이 쌓이지 않고
  /// 하나가 갱신된다. 세션당 1회 제한은 호출부(`MapScreen`)가 이미 하고 있다(#46).
  Future<void> notifySpotNearby({
    required int spotId,
    required String spotTitle,
    required double distanceMeters,
  }) async {
    try {
      await init();
      await _plugin.show(
        id: spotId,
        title: '$spotTitle 근처예요',
        body: '${distanceMeters.round()}m — 지금 방문 인증을 할 수 있어요',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (e) {
      // 알림은 보조 수단이다 — 실패해도 앱을 열면 배너로 볼 수 있다.
      debugPrint('[ProximityNotifier] 알림 표시 실패: $e');
    }
  }
}

final proximityNotifierProvider = Provider<ProximityNotifier>((ref) {
  return ProximityNotifier(FlutterLocalNotificationsPlugin());
});
