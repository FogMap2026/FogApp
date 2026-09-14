import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/visit.dart';
import '../services/korea_dot_grid.dart';
import '../theme/app_theme.dart';

/// 전국 정복 현황을 「발자취」 앱처럼 점 지도로 보여준다(정복 현황 화면).
///
/// **옅은 점 = 국토 전체.** [kr_boundary.json](안개 오버레이가 예전에 쓰던 국경
/// 데이터)이 감싸는 영역에 격자를 깔아 국토 실루엣을 만든다 — 지역 경계가 아니라
/// 그냥 배경이라 방문 여부와 무관하게 항상 같은 자리에 같은 색으로 찍힌다.
///
/// **짙은 점 = [visits].** 화면 상단 정복률과 같은 근거(방문 인증 좌표,
/// `VisitService.myVisits()`)를 실제 위경도 그대로 겹쳐 찍는다 — 임의로 몇 %를
/// 어둡게 칠하는 연출이 아니라, 정말 그 자리를 밝힌 것이다.
class KoreaDotMap extends StatelessWidget {
  const KoreaDotMap({required this.visits, super.key});

  /// 방문 인증 목록 — 각 인증의 (lat, lng)을 짙은 점으로 찍는다.
  final List<Visit> visits;

  /// 격자 계산 결과 캐시 — 국경 데이터는 앱 실행 중 바뀌지 않으므로 화면을 몇 번을
  /// 열어도 한 번만 계산한다. 계산 자체가 본토 폴리곤(꼭짓점 1500개+) 때문에 가볍지
  /// 않아서(수십~수백 ms), 매번 다시 하면 화면을 열 때마다 버벅인다.
  static Future<KoreaDotGrid>? _cachedGrid;

  static Future<KoreaDotGrid> _loadGrid() {
    return _cachedGrid ??= _buildGrid();
  }

  static Future<KoreaDotGrid> _buildGrid() async {
    final raw = await rootBundle.loadString('assets/geo/kr_boundary.json');
    final rings = (jsonDecode(raw) as List)
        .cast<List>()
        .map((ring) => ring.cast<List>().map((p) => [(p[0] as num).toDouble(), (p[1] as num).toDouble()]).toList())
        .toList();
    return buildKoreaDotGrid(rings, columns: _gridColumns);
  }

  /// [buildKoreaDotGrid]에 준 것과 같은 값이어야 한다 — 점 크기 계산([_KoreaDotPainter])이
  /// 이 칸 수를 기준으로 화면 폭을 나누기 때문이다.
  static const _gridColumns = 48;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<KoreaDotGrid>(
      future: _loadGrid(),
      builder: (context, snapshot) {
        final grid = snapshot.data;
        // 로딩 중(첫 화면 진입)에도 비율이 확 바뀌지 않게 최종 비율에 가까운 값을 미리 잡아둔다.
        return AspectRatio(
          aspectRatio: grid?.aspectRatio ?? 1.35,
          child: grid == null
              ? const Center(child: CircularProgressIndicator())
              : CustomPaint(
                  painter: _KoreaDotPainter(grid: grid, visits: visits),
                ),
        );
      },
    );
  }
}

class _KoreaDotPainter extends CustomPainter {
  _KoreaDotPainter({required this.grid, required this.visits});

  final KoreaDotGrid grid;
  final List<Visit> visits;

  @override
  void paint(Canvas canvas, Size size) {
    // 점 크기는 격자 칸 수 대비 화면 폭에 비례한다 — 화면 크기가 달라져도 점 사이
    // 간격과 크기의 비율이 유지된다.
    final dotRadius = (size.width / KoreaDotMap._gridColumns) * 0.32;

    final fogPaint = Paint()..color = AppColors.inkFaint;
    for (final dot in grid.dots) {
      final p = grid.normalize(dot.lat, dot.lng);
      canvas.drawCircle(Offset(p.dx * size.width, p.dy * size.height), dotRadius, fogPaint);
    }

    if (visits.isEmpty) return;
    final visitedPaint = Paint()..color = AppColors.secondary;
    final visitedRadius = dotRadius * 1.9;
    for (final visit in visits) {
      final p = grid.normalize(visit.lat, visit.lng);
      canvas.drawCircle(Offset(p.dx * size.width, p.dy * size.height), visitedRadius, visitedPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _KoreaDotPainter oldDelegate) =>
      !identical(oldDelegate.grid, grid) || oldDelegate.visits != visits;
}
