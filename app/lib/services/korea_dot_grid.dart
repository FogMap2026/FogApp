/// 전국 정복 현황 화면([KoreaDotMap])의 점 격자 계산 — 순수 함수라 위젯 없이 검증한다.
///
/// `assets/geo/kr_boundary.json`(안개 오버레이가 예전에 쓰던 국경 폴리곤, 53개
/// landmass)이 감싸는 영역 안에만 격자점을 남긴다. 화면을 열 때마다 다시 계산하면
/// 큰 본토 폴리곤(꼭짓점 1500개 이상) 때문에 수백 ms 가 걸리므로 [KoreaDotMap]이
/// 결과를 한 번만 계산해 캐싱한다 — 이 파일은 그 계산만 담당한다.
library;

import 'dart:math';
import 'dart:ui';

/// (위도, 경도) 하나 — 격자에 남은 점.
class KoreaDot {
  const KoreaDot(this.lat, this.lng);

  final double lat;
  final double lng;
}

/// [buildKoreaDotGrid]의 결과. 격자점 목록과, 실제 좌표(예: 방문 인증 지점)를 같은
/// 화면에 겹쳐 그리는 데 필요한 좌표 변환을 함께 들고 있다.
class KoreaDotGrid {
  const KoreaDotGrid({
    required this.dots,
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  final List<KoreaDot> dots;
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  /// 폭 ÷ 높이. 위도 1도와 경도 1도가 실거리로 다르므로(중위도일수록 경도가 짧다)
  /// `cos(중위도)`로 보정한다 — 안 하면 한반도가 실제보다 넓적하게 그려진다.
  double get aspectRatio {
    final midLatRad = (minLat + maxLat) / 2 * (pi / 180);
    final lngSpanMeters = (maxLng - minLng) * cos(midLatRad);
    final latSpan = maxLat - minLat;
    if (latSpan <= 0) return 1;
    return lngSpanMeters / latSpan;
  }

  /// (위도, 경도)를 0~1 정규화 좌표로 — dx: 서→동, dy: **북→남**(화면 좌표계와 맞춘다,
  /// 위도가 클수록 화면 위쪽).
  ///
  /// 격자 바깥 좌표(예: 위경도 오차로 해안선을 살짝 벗어난 방문 지점)도 그대로
  /// 변환한다 — 0~1을 벗어날 수 있으니 호출부가 화면 밖으로 나가는 것까지 신경 쓸
  /// 필요는 없다(캔버스가 알아서 클리핑한다).
  Offset normalize(double lat, double lng) {
    final dx = (lng - minLng) / (maxLng - minLng);
    final dy = 1 - (lat - minLat) / (maxLat - minLat);
    return Offset(dx, dy);
  }
}

/// [rings](각 원소가 `[위도, 경도]` 쌍의 목록인 폴리곤 여러 개) 안에 들어오는 점만 남긴
/// `columns` 칸 격자를 만든다.
///
/// **바운딩 박스로 먼저 거른다.** 격자점마다 53개 폴리곤 전부에 레이 캐스팅을 하면
/// (본토 하나가 꼭짓점 1500개+) 격자 하나 만드는 데 수 초가 걸린다. 폴리곤별
/// 바운딩 박스를 미리 구해두고, 그 박스 안에 든 격자점만 실제 레이 캐스팅을 한다 —
/// 대부분의 (격자점, 폴리곤) 쌍은 박스 비교 네 번으로 끝난다.
KoreaDotGrid buildKoreaDotGrid(List<List<List<double>>> rings, {int columns = 48}) {
  if (rings.isEmpty) {
    return const KoreaDotGrid(dots: [], minLat: 0, maxLat: 0, minLng: 0, maxLng: 0);
  }

  var minLat = double.infinity, maxLat = -double.infinity;
  var minLng = double.infinity, maxLng = -double.infinity;
  final ringBounds = <_RingBounds>[];
  for (final ring in rings) {
    var rMinLat = double.infinity, rMaxLat = -double.infinity;
    var rMinLng = double.infinity, rMaxLng = -double.infinity;
    for (final p in ring) {
      final lat = p[0], lng = p[1];
      if (lat < rMinLat) rMinLat = lat;
      if (lat > rMaxLat) rMaxLat = lat;
      if (lng < rMinLng) rMinLng = lng;
      if (lng > rMaxLng) rMaxLng = lng;
    }
    ringBounds.add(_RingBounds(ring, rMinLat, rMaxLat, rMinLng, rMaxLng));
    if (rMinLat < minLat) minLat = rMinLat;
    if (rMaxLat > maxLat) maxLat = rMaxLat;
    if (rMinLng < minLng) minLng = rMinLng;
    if (rMaxLng > maxLng) maxLng = rMaxLng;
  }

  final midLatRad = (minLat + maxLat) / 2 * (pi / 180);
  final lngSpan = maxLng - minLng;
  final latSpan = maxLat - minLat;
  final lngPerCell = columns > 0 ? lngSpan / columns : lngSpan;
  // 셀이 정사각형에 가깝도록(중위도 보정) 행 수를 경도 칸 크기에 맞춰 잡는다.
  final cellMeters = lngPerCell * cos(midLatRad);
  final rows = cellMeters <= 0 ? 1 : (latSpan / cellMeters).round().clamp(1, 4000);
  final latPerCell = latSpan / rows;

  final dots = <KoreaDot>[];
  for (var row = 0; row <= rows; row++) {
    final lat = minLat + row * latPerCell;
    for (var col = 0; col <= columns; col++) {
      final lng = minLng + col * lngPerCell;
      for (final bounds in ringBounds) {
        if (lat < bounds.minLat || lat > bounds.maxLat || lng < bounds.minLng || lng > bounds.maxLng) {
          continue;
        }
        if (_pointInRing(bounds.ring, lat, lng)) {
          dots.add(KoreaDot(lat, lng));
          break;
        }
      }
    }
  }

  return KoreaDotGrid(dots: dots, minLat: minLat, maxLat: maxLat, minLng: minLng, maxLng: maxLng);
}

class _RingBounds {
  const _RingBounds(this.ring, this.minLat, this.maxLat, this.minLng, this.maxLng);

  final List<List<double>> ring;
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;
}

/// 레이 캐스팅(ray casting) — [fog_overlay_controller.dart]의 `_Landmass._containsPoint`와
/// 같은 판정이다. 여기서는 `NLatLng`가 아니라 `[위도, 경도]` 배열을 받는다 — 이 파일이
/// 지도 플러그인에 의존하지 않게 하기 위해서다(플러그인 없이도 격자 계산을 테스트하려고).
bool _pointInRing(List<List<double>> ring, double lat, double lng) {
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final pi = ring[i], pj = ring[j];
    final intersects = (pi[1] > lng) != (pj[1] > lng) &&
        lat < (pj[0] - pi[0]) * (lng - pi[1]) / (pj[1] - pi[1]) + pi[0];
    if (intersects) inside = !inside;
  }
  return inside;
}
