import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/conquest.dart';
import '../models/visit.dart';
import '../services/conquest_service.dart';
import '../services/visit_service.dart';
import '../theme/app_theme.dart';
import '../widgets/korea_dot_map.dart';
import 'conquest_region_screen.dart';

/// 전국 정복 현황 — 지도 상단 정보 바(지역명·정복률)를 누르면 들어온다.
///
/// 「발자취」 앱의 배지 화면을 참고했다: 한반도를 점으로 깔아 두고 실제 인증한
/// 좌표만 짙게 찍어("[KoreaDotMap]") 얼마나 밝혔는지 한눈에 보여준 뒤, 그 아래
/// 전체 스팟 밝힘 비율과 지역별(시/군/구) 목록을 이어 붙인다. 지역 목록은 정복률
/// API(#51)를 그대로 쓴다 — 지도 상단이 쓰는 것과 같은 데이터·같은 지역 단위다.
class ConquestScreen extends ConsumerStatefulWidget {
  const ConquestScreen({super.key});

  @override
  ConsumerState<ConquestScreen> createState() => _ConquestScreenState();
}

class _ConquestScreenState extends ConsumerState<ConquestScreen> {
  late Future<_ConquestData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /// 정복률 목록(지역별 집계)과 방문 인증 좌표(점 지도용)를 함께 받는다 — 둘 다
  /// 같은 근거(`visits`)에서 나오지만 API가 갈려 있어 따로 부른다.
  Future<_ConquestData> _load() async {
    final results = await Future.wait([
      ref.read(conquestServiceProvider).myConquest(),
      ref.read(visitServiceProvider).myVisits(),
    ]);
    return _ConquestData(
      regions: results[0] as List<ConquestRegion>,
      visits: results[1] as List<Visit>,
    );
  }

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvasSoft,
      appBar: AppBar(title: const Text('정복 현황')),
      body: SafeArea(
        child: FutureBuilder<_ConquestData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('정복 현황을 불러오지 못했어요.', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _retry, child: const Text('다시 시도')),
                  ],
                ),
              );
            }
            return _ConquestBody(data: snapshot.data!);
          },
        ),
      ),
    );
  }
}

class _ConquestData {
  const _ConquestData({required this.regions, required this.visits});

  final List<ConquestRegion> regions;
  final List<Visit> visits;
}

class _ConquestBody extends StatelessWidget {
  const _ConquestBody({required this.data});

  final _ConquestData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final regions = data.regions;
    final totalSpots = regions.fold<int>(0, (sum, r) => sum + r.totalSpots);
    final visitedSpots = regions.fold<int>(0, (sum, r) => sum + r.visitedSpots);
    final percent = totalSpots == 0 ? 0 : (visitedSpots / totalSpots * 100).round();

    // regionName이 "경상북도 경주시" 형태라 첫 토큰이 시/도다 — 그걸로 묶어 헤더를
    // 만든다. 서버가 이름을 못 지은(주소 품질 문제) 그룹은 regionCode로 폴백하므로
    // 그런 그룹은 자기 혼자만의 "헤더"가 된다 — 드물지만 틀린 그룹으로 섞이는 것보다 낫다.
    final grouped = <String, List<ConquestRegion>>{};
    for (final region in regions) {
      final sido = region.regionName.split(' ').first;
      grouped.putIfAbsent(sido, () => []).add(region);
    }
    final sidoNames = grouped.keys.toList()..sort();

    if (totalSpots == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            '아직 정복 데이터가 없어요.\n지도를 탐험하며 스팟을 밝혀보세요.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: KoreaDotMap(visits: data.visits),
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Column(
            children: [
              Text('밝힌 스팟', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted)),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  style: theme.textTheme.headlineMedium,
                  children: [
                    TextSpan(text: '$visitedSpots'),
                    TextSpan(
                      text: ' / $totalSpots',
                      style: const TextStyle(color: AppColors.inkFaint, fontWeight: FontWeight.w400),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text('$percent%', style: theme.textTheme.titleMedium?.copyWith(color: AppColors.primary)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text('지역별 배지', style: theme.textTheme.titleMedium),
        for (final sido in sidoNames) ...[
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xxs),
            child: Text(
              sido,
              style: theme.textTheme.labelLarge?.copyWith(color: AppColors.inkMuted, fontWeight: FontWeight.w600),
            ),
          ),
          ...grouped[sido]!.map((region) => _RegionTile(region: region)),
        ],
      ],
    );
  }
}

class _RegionTile extends StatelessWidget {
  const _RegionTile({required this.region});

  final ConquestRegion region;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (region.rate * 100).round();
    // 시/도 접두어는 바로 위 그룹 헤더가 이미 보여주니, 남는 부분(시/군/구)만 보여준다.
    // 시/군/구를 못 뽑은(regionName == regionCode 폴백) 경우는 자를 게 없으니 그대로 둔다.
    final rest = region.regionName.split(' ').skip(1).join(' ');
    final displayName = rest.isEmpty ? region.regionName : rest;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ConquestRegionScreen(region: region)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 2),
                    Text(
                      '${region.visitedSpots} / ${region.totalSpots}',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ),
              Text('$percent%', style: theme.textTheme.titleSmall?.copyWith(color: AppColors.primary)),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}
