import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

/// 푸시 알림(#134, 6-4) — 기기 토큰을 서버에 등록·해제하고 권한을 받는다.
///
/// **보내는 것은 서버가 만드는 이벤트 셋뿐이다** — 친구 요청·수락·새 메시지. 스팟 근접은 푸시로
/// 보내지 않는다: 근접을 판정하려면 앱이 꺼진 동안에도 위치를 받아야 하는데, 그 백그라운드 수집은
/// 취소됐고(#135) 방침·위치정보 신고 접수본에 「위치정보는 앱 실행 중에만」으로 적혀 있다.
///
/// 켜짐/꺼짐은 **서버에 토큰이 있느냐**로 정해진다(별도 플래그 없음). 이 기기의 선택은
/// [_prefsKey] 에 남겨 앱을 다시 켜도 꺼둔 상태가 유지되게 한다.
class PushService {
  PushService(this._apiClient);

  final ApiClient _apiClient;

  static const _prefsKey = 'push_enabled';

  /// 이 기기에서 알림을 켜 둘지. 처음 설치는 켜짐(권한 창은 그때 뜬다).
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? true;
  }

  /// 로그인 직후·설정에서 켤 때. 권한을 받고 토큰을 서버에 등록한다.
  ///
  /// 권한이 거부돼도 **조용히 넘어간다** — 알림은 곁가지라 거절 하나로 지도 진입을 막지 않는다.
  Future<void> enable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[Push] 알림 권한 거부 — 등록하지 않는다');
        return;
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _register(token);
    } catch (e) {
      debugPrint('[Push] 등록 실패: $e');
    }
  }

  /// 설정에서 끌 때·로그아웃할 때. 서버에서 토큰을 지운다 — 보낼 곳이 없어진다.
  ///
  /// [forget] 이 true 면 이 기기의 «꺼둠»을 기억한다(설정에서 끈 경우). 로그아웃은 기억하지 않는다 —
  /// 다음 사람이 켜진 상태로 시작해야 한다.
  Future<void> disable({bool forget = true}) async {
    if (forget) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, false);
    }
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _apiClient.dio.delete<void>('/api/devices/token', data: {'token': token});
    } catch (e) {
      debugPrint('[Push] 해제 실패: $e');
    }
  }

  /// 앱을 켤 때 부른다 — 꺼 둔 기기면 아무것도 하지 않는다.
  Future<void> syncOnStart() async {
    if (await isEnabled()) await enable();
  }

  /// 토큰은 앱 재설치·복원에서 바뀐다. 바뀐 값을 안 올리면 그 뒤로 알림이 조용히 끊긴다.
  StreamSubscription<String> listenTokenRefresh() {
    return FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      if (await isEnabled()) await _register(token);
    });
  }

  Future<void> _register(String token) {
    return _apiClient.dio.post<void>(
      '/api/devices/token',
      data: {'token': token, 'platform': 'android'},
    );
  }
}

final pushServiceProvider = Provider<PushService>((ref) {
  return PushService(ref.watch(apiClientProvider));
});

/// 설정 화면의 「알림 받기」 스위치 값. 앱을 켤 때 저장값으로 채운다.
class PushEnabled extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool enabled) => state = enabled;
}

final pushEnabledProvider = NotifierProvider<PushEnabled, bool>(PushEnabled.new);
