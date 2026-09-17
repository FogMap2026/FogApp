import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';

/// 위치 고정점(fix) 사이를 채워 내 위치가 **미끄러지듯** 움직이게 한다.
///
/// GPS 는 «연속»이 아니라 1초에 한 번쯤 점을 던진다. 그 점을 그대로 지도에 찍으면 캐릭터가
/// 뚝뚝 끊겨 순간이동하듯 보인다(사용자 제보, 09-17). 받은 점을 «목표»로 두고 [positionAt] 이
/// 지금 시각에 맞춰 이전 점에서 목표로 조금씩 옮긴 좌표를 돌려준다 — 화면은 그 사이를 채운다.
///
/// **지도·GPS 없이 시험할 수 있게 시계를 인자로 받는다** — 여기서 `DateTime.now()` 를 부르지
/// 않는다(`smooth_location_test.dart`).
class SmoothLocation {
  SmoothLocation({
    this.snapDistanceMeters = 60,
    this.minDuration = const Duration(milliseconds: 300),
    this.maxDuration = const Duration(seconds: 3),
  });

  /// 이보다 멀리 뛰면 **채우지 않고 바로 옮긴다.** 측위가 크게 틀렸다가 잡히는 순간(도심 반사·
  /// 실내 → 실외)인데, 그걸 미끄러뜨리면 몇 초 동안 «엉뚱한 곳에서 미끄러져 오는» 그림이 된다.
  final double snapDistanceMeters;

  /// 채우는 시간의 아래·위 한계. 새 점이 오면 «지난 점과의 간격»만큼 걸려 목표에 닿게 하되,
  /// 너무 짧으면 결국 끊겨 보이고 너무 길면 실제 위치보다 한참 뒤처져 따라간다.
  final Duration minDuration;
  final Duration maxDuration;

  NLatLng? _from;
  NLatLng? _target;
  DateTime? _startedAt;
  DateTime? _lastFixAt;
  Duration _duration = Duration.zero;

  /// 목표에 닿았나 — 닿았으면 호출부가 화면 갱신 타이머를 멈춰도 된다.
  bool settledAt(DateTime now) {
    final startedAt = _startedAt;
    if (_target == null) return true;
    if (startedAt == null || _duration == Duration.zero) return true;
    return now.difference(startedAt) >= _duration;
  }

  /// 새 GPS 점을 받는다.
  void onFix(NLatLng fix, {required DateTime at}) {
    final current = positionAt(at) ?? fix;
    final lastFixAt = _lastFixAt;
    _lastFixAt = at;

    final jump = Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      fix.latitude,
      fix.longitude,
    );
    if (_target == null || jump > snapDistanceMeters) {
      _from = fix;
      _target = fix;
      _startedAt = at;
      _duration = Duration.zero;
      return;
    }

    _from = current;
    _target = fix;
    _startedAt = at;
    // 다음 점도 이만큼 뒤에 온다고 보고 그 시간에 걸쳐 옮긴다.
    final gap = lastFixAt == null ? minDuration : at.difference(lastFixAt);
    _duration = gap < minDuration ? minDuration : (gap > maxDuration ? maxDuration : gap);
  }

  /// [now] 시점에 화면에 찍을 좌표. 아직 한 점도 못 받았으면 null.
  NLatLng? positionAt(DateTime now) {
    final from = _from;
    final target = _target;
    final startedAt = _startedAt;
    if (from == null || target == null || startedAt == null) return null;
    if (_duration == Duration.zero) return target;

    final elapsed = now.difference(startedAt);
    if (elapsed >= _duration) return target;
    if (elapsed.isNegative) return from;

    final t = elapsed.inMicroseconds / _duration.inMicroseconds;
    return NLatLng(
      from.latitude + (target.latitude - from.latitude) * t,
      from.longitude + (target.longitude - from.longitude) * t,
    );
  }
}
