// 내 위치가 GPS 점 사이를 미끄러지듯 움직이는지 — 지도·GPS 없이 시계를 넣어 검증한다.
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogapp/services/smooth_location.dart';
import 'package:geolocator/geolocator.dart';

const _lat = 37.5665;
const _lng = 126.9780;

/// 북쪽으로 [meters] 만큼 떨어진 점. 위도 1도 ≈ 111,320m.
NLatLng _north(double meters) => NLatLng(_lat + meters / 111320, _lng);

double _metersFromBase(NLatLng p) => Geolocator.distanceBetween(_lat, _lng, p.latitude, p.longitude);

void main() {
  final t0 = DateTime(2026, 9, 17, 10);

  test('첫 점은 그 자리에 바로 찍는다 — 채울 이전 위치가 없다', () {
    final smooth = SmoothLocation();
    expect(smooth.positionAt(t0), isNull);

    smooth.onFix(_north(0), at: t0);
    expect(_metersFromBase(smooth.positionAt(t0)!), closeTo(0, 0.1));
    expect(smooth.settledAt(t0), isTrue);
  });

  test('두 점 사이를 시간에 비례해 채운다 — 받은 순간에만 툭 옮기지 않는다', () {
    final smooth = SmoothLocation();
    smooth.onFix(_north(0), at: t0);
    smooth.onFix(_north(10), at: t0.add(const Duration(seconds: 1)));

    // 새 점을 받은 «직후»에는 아직 옛 자리다.
    expect(_metersFromBase(smooth.positionAt(t0.add(const Duration(seconds: 1)))!), closeTo(0, 0.5));
    // 그 뒤로 조금씩 옮겨 간다.
    expect(_metersFromBase(smooth.positionAt(t0.add(const Duration(milliseconds: 1300)))!), closeTo(3, 0.5));
    expect(_metersFromBase(smooth.positionAt(t0.add(const Duration(milliseconds: 1500)))!), closeTo(5, 0.5));
    expect(smooth.settledAt(t0.add(const Duration(milliseconds: 1500))), isFalse);
  });

  test('채우는 시간이 지나면 목표에 멈춘다 — 넘어가지 않는다', () {
    final smooth = SmoothLocation();
    smooth.onFix(_north(0), at: t0);
    smooth.onFix(_north(10), at: t0.add(const Duration(seconds: 1)));

    final settled = t0.add(const Duration(seconds: 2));
    expect(_metersFromBase(smooth.positionAt(settled)!), closeTo(10, 0.5));
    expect(smooth.settledAt(settled), isTrue);
    // 한참 뒤에도 목표 그대로 — 계속 북쪽으로 흘러가면 안 된다.
    expect(_metersFromBase(smooth.positionAt(t0.add(const Duration(minutes: 1)))!), closeTo(10, 0.5));
  });

  test('멀리 튄 점은 채우지 않고 바로 옮긴다 — 엉뚱한 곳에서 미끄러져 오지 않게', () {
    final smooth = SmoothLocation();
    smooth.onFix(_north(0), at: t0);
    smooth.onFix(_north(500), at: t0.add(const Duration(seconds: 1)));

    final at = t0.add(const Duration(seconds: 1));
    expect(_metersFromBase(smooth.positionAt(at)!), closeTo(500, 1));
    expect(smooth.settledAt(at), isTrue);
  });

  test('점이 늦게 와도 최대 시간까지만 걸린다 — 실제 위치보다 한없이 뒤처지지 않게', () {
    final smooth = SmoothLocation(maxDuration: const Duration(seconds: 2));
    smooth.onFix(_north(0), at: t0);
    // 10초 만에 온 점: 10초에 걸쳐 옮기면 그동안 계속 뒤처져 보인다.
    smooth.onFix(_north(20), at: t0.add(const Duration(seconds: 10)));

    final settled = t0.add(const Duration(seconds: 12));
    expect(_metersFromBase(smooth.positionAt(settled)!), closeTo(20, 0.5));
    expect(smooth.settledAt(settled), isTrue);
  });

  test('연달아 오는 점은 이전에 «가 있던 자리»에서 이어간다 — 되감기지 않는다', () {
    final smooth = SmoothLocation();
    smooth.onFix(_north(0), at: t0);
    smooth.onFix(_north(10), at: t0.add(const Duration(seconds: 1)));

    // 절반쯤 갔을 때(5m) 다음 점이 온다.
    final half = t0.add(const Duration(milliseconds: 1500));
    final before = _metersFromBase(smooth.positionAt(half)!);
    smooth.onFix(_north(20), at: half);
    expect(_metersFromBase(smooth.positionAt(half)!), closeTo(before, 0.1)); // 그 자리에서 이어간다
    expect(_metersFromBase(smooth.positionAt(half.add(const Duration(seconds: 1)))!), closeTo(20, 0.5));
  });
}
