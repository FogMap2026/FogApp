import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import 'location_service.dart';

/// 백그라운드 추적 on/off 를 기기에 저장한다(#135 To-do "사용자가 끌 수 있는 스위치").
///
/// 서버에 둘 이유가 없다 — 같은 계정이라도 **기기마다** 다르게 두고 싶은 설정이고,
/// 서버가 알아야 할 일도 없다.
///
/// **기본값은 꺼짐이다.** 백그라운드 추적은 끌 수 없는 상시 알림이 뜨고 배터리를 쓴다.
/// 켠 적 없는 사용자에게 그런 상태를 기본으로 주지 않는다 — 위치 공유(#133)와 같은 원칙.
class BackgroundTrackingSetting {
  const BackgroundTrackingSetting._();

  static const _key = 'background_tracking_enabled';

  /// 저장된 설정을 읽는다. 저장된 적 없거나 읽기에 실패하면 꺼짐으로 본다.
  static Future<LocationTrackingMode> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_key) ?? false;
      return enabled ? LocationTrackingMode.always : LocationTrackingMode.foregroundOnly;
    } catch (e) {
      debugPrint('[BackgroundTracking] 설정 읽기 실패: $e');
      return LocationTrackingMode.foregroundOnly;
    }
  }

  /// 설정을 저장한다. 실패하면 이번 실행에만 적용되고 다음 실행에 꺼짐으로 돌아간다 —
  /// 켜진 채로 잘못 남는 것보다 낫다.
  static Future<void> save(LocationTrackingMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, mode == LocationTrackingMode.always);
    } catch (e) {
      debugPrint('[BackgroundTracking] 설정 저장 실패: $e');
    }
  }
}
