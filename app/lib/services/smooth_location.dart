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
    this.maxSpeedMetersPerSecond = 55,
    this.minDuration = const Duration(milliseconds: 300),
    this.maxDuration = const Duration(seconds: 3),
    this.durationFactor = 1.25,
  });

  /// 이보다 멀리 뛰면 **채우지 않고 바로 옮긴다.** 측위가 크게 틀렸다가 잡히는 순간(도심 반사·
  /// 실내 → 실외)인데, 그걸 미끄러뜨리면 몇 초 동안 «엉뚱한 곳에서 미끄러져 오는» 그림이 된다.
  ///
  /// 🔴 **거리만으로 자르면 차가 끊긴다.** 시속 100km 면 2초에 56m, 3초에 83m 라 멀쩡한 이동도
  /// 이 값을 넘어 순간이동으로 보인다(사용자 제보, 09-18). 그래서 실제 기준은 «그 시간 안에 갈 수
  /// 있었나»이고([maxSpeedMetersPerSecond]), 이 값은 **간격이 짧을 때의 바닥**이다.
  final double snapDistanceMeters;

  /// 사람이 탈것으로 낼 수 있다고 보는 최고 속도(m/s). 55m/s ≈ 198km/h — 고속열차만 아니면
  /// 넘지 않는다. 이보다 빠른 «이동»은 이동이 아니라 측위 오류라 보고 바로 옮긴다.
  final double maxSpeedMetersPerSecond;

  /// 채우는 시간의 아래·위 한계. 새 점이 오면 «지난 점과의 간격»만큼 걸려 목표에 닿게 하되,
  /// 너무 짧으면 결국 끊겨 보이고 너무 길면 실제 위치보다 한참 뒤처져 따라간다.
  final Duration minDuration;
  final Duration maxDuration;

  /// 간격에 이만큼 곱한 시간에 걸쳐 옮긴다.
  ///
  /// 🔴 **딱 간격만큼이면 «움직였다 멈췄다»가 된다.** GPS 간격은 일정하지 않아서(1.0초 뒤 1.4초)
  /// 먼저 도착해 버리면 다음 점이 올 때까지 서 있고, 그게 빠르게 갈수록 눈에 띈다(사용자 제보,
  /// 09-18). 조금 길게 잡으면 다음 점이 올 때 **아직 움직이는 중**이라 끊기지 않는다. 대가는
  /// 간격의 25%(≈0.25초)만큼 뒤처지는 것이고, 그건 눈에 안 띈다.
  final double durationFactor;

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
    if (_target == null || jump > _allowedJump(lastFixAt == null ? null : at.difference(lastFixAt))) {
      _from = fix;
      _target = fix;
      _startedAt = at;
      _duration = Duration.zero;
      return;
    }

    _from = current;
    _target = fix;
    _startedAt = at;
    // 다음 점도 이만큼 뒤에 온다고 보고, 거기에 [durationFactor] 를 곱한 시간에 걸쳐 옮긴다.
    final gap = lastFixAt == null ? minDuration : at.difference(lastFixAt);
    final target = gap * durationFactor;
    _duration = target < minDuration ? minDuration : (target > maxDuration ? maxDuration : target);
  }

  /// 이 간격 안에 갈 수 있었던 거리. 넘으면 이동이 아니라 측위 오류로 본다.
  ///
  /// 간격을 [maxDuration] 으로 잘라 두는 것이 중요하다 — 앱을 한참 백그라운드에 뒀다 돌아오면
  /// 간격이 몇 분이라, 자르지 않으면 «수 km 를 3초에 걸쳐 미끄러져 오는» 그림이 된다.
  double _allowedJump(Duration? gap) {
    final capped = gap == null || gap > maxDuration ? maxDuration : gap;
    final bySpeed = maxSpeedMetersPerSecond * capped.inMilliseconds / 1000;
    return bySpeed > snapDistanceMeters ? bySpeed : snapDistanceMeters;
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
