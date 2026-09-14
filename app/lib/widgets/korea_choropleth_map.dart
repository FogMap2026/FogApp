import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/conquest.dart';
import '../theme/app_theme.dart';

/// 전국 시/도 경계 지도 — 시/도마다 탐험률에 따라 색을 칠한다(단계구분도).
///
/// 배지 목록([ConquestScreen])과 같은 단위·같은 숫자다: 배지가 「경기도 3%」면 지도의
/// 경기도도 3% 색이다. 경계는 통계청 2013 시/도([_assetPath]) — 그 뒤 통합된 시/도는
/// 옛 폴리곤 둘을 같은 배지 색으로 칠한다([matchSidoForProvince]).
///
/// 배지에 없는 시/도(정복률 API 에 스팟이 하나도 없는 곳)는 빈 회색으로 남긴다.
class KoreaChoroplethMap extends StatefulWidget {
  const KoreaChoroplethMap({required this.sidos, super.key});

  final List<ConquestSido> sidos;

  @override
  State<KoreaChoroplethMap> createState() => _KoreaChoroplethMapState();
}

class _KoreaChoroplethMapState extends State<KoreaChoroplethMap> {
  static const _assetPath = 'assets/geo/kr_provinces.json';

  /// 앱 세션 동안 한 번만 읽는다 — 화면을 나갔다 들어와도 다시 파싱하지 않는다.
  static Future<List<_Province>>? _cached;

  @override
  Widget build(BuildContext context) {
    _cached ??= _load();
    return AspectRatio(
      // 위도 33~38.6 · 경도 125~130 을 중위도 보정하면 가로:세로 ≈ 0.8.
      aspectRatio: 0.8,
      child: FutureBuilder<List<_Province>>(
        future: _cached,
        builder: (context, snapshot) {
          final provinces = snapshot.data;
          if (provinces == null) return const SizedBox.shrink();
          return CustomPaint(painter: _ChoroplethPainter(provinces, widget.sidos));
        },
      ),
    );
  }

  static Future<List<_Province>> _load() async {
    final raw = await rootBundle.loadString(_assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return [
      for (final p in json['provinces'] as List)
        _Province(
          name: p['name'] as String,
          rings: [
            for (final ring in p['rings'] as List)
              [for (final c in ring as List) Offset((c[0] as num).toDouble(), (c[1] as num).toDouble())],
          ],
        ),
    ];
  }
}

class _Province {
  const _Province({required this.name, required this.rings});

  final String name;

  /// 경도(x)·위도(y) 좌표. 섬이 있는 시/도는 고리가 여럿이다.
  final List<List<Offset>> rings;
}

class _ChoroplethPainter extends CustomPainter {
  _ChoroplethPainter(this.provinces, this.sidos);

  final List<_Province> provinces;
  final List<ConquestSido> sidos;

  /// 0% — 아직 아무것도 안 밝힌 시/도. 배지의 0% 와 같은 «비어 있음».
  static const _empty = AppColors.hairline;

  @override
  void paint(Canvas canvas, Size size) {
    // 전체 바운딩 박스 → 화면. 경도는 중위도 cos 로 보정해 실제 비율에 가깝게.
    var minLng = double.infinity, maxLng = -double.infinity, minLat = double.infinity, maxLat = -double.infinity;
    for (final p in provinces) {
      for (final ring in p.rings) {
        for (final c in ring) {
          minLng = min(minLng, c.dx);
          maxLng = max(maxLng, c.dx);
          minLat = min(minLat, c.dy);
          maxLat = max(maxLat, c.dy);
        }
      }
    }
    final midLat = (minLat + maxLat) / 2;
    final lngScale = cos(midLat * pi / 180);
    final geoW = (maxLng - minLng) * lngScale;
    final geoH = maxLat - minLat;
    final scale = min(size.width / geoW, size.height / geoH);
    final drawW = geoW * scale;
    final drawH = geoH * scale;
    final ox = (size.width - drawW) / 2;
    final oy = (size.height - drawH) / 2;
    Offset project(Offset c) => Offset(ox + (c.dx - minLng) * lngScale * scale, oy + (maxLat - c.dy) * scale);

    // 경계선은 흰색 — 반투명 검정도 써봤지만 회색 시/도가 칙칙해 보여 흰색으로 돌렸다
    // (시진, 09-14). 0.5px 는 다도해처럼 작은 섬이 촘촘한 곳에서 선이 번져 덩어리로
    // 보이지 않는 굵기다.
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = AppColors.surface;

    for (final province in provinces) {
      final sido = matchSidoForProvince(sidos, province.name);
      final fill = Paint()..color = sido == null ? _empty : colorForRate(sido.rate);
      final path = Path();
      for (final ring in province.rings) {
        if (ring.isEmpty) continue;
        path.moveTo(project(ring.first).dx, project(ring.first).dy);
        for (final c in ring.skip(1)) {
          final q = project(c);
          path.lineTo(q.dx, q.dy);
        }
        path.close();
      }
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
  }

  /// 탐험률 → 색. 0% 는 빈 회색, 그 위로는 앱 파란색이 짙어진다.
  ///
  /// 제곱근 곡선이다 — 낮은 구간을 벌린다. 선형이면 5% 와 30% 가 거의 같은 색이었다
  /// (실기기, 09-14). 실제 값은 대부분 한 자리 % 에 몰리므로(시/도당 스팟 1000개)
  /// 그 구간이 제일 잘 갈려야 한다: 5% → 0.34, 30% → 0.62, 60% → 0.81, 100% → 1.
  /// 바닥 0.15 는 1% 도 0% 와 구분되게 하는 값이다.
  static Color colorForRate(double rate) {
    if (rate <= 0) return _empty;
    final t = 0.15 + 0.85 * sqrt(rate.clamp(0.0, 1.0));
    return Color.lerp(_empty, AppColors.primary, t)!;
  }

  @override
  bool shouldRepaint(_ChoroplethPainter old) => old.provinces != provinces || old.sidos != sidos;
}
