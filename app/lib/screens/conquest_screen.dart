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
/// 전체 스팟 밝힘 비율과 **시/도별 배지 17개**를 이어 붙인다.
///
/// 배지 단위가 시/도인 이유: 정복률 API(#51)는 시/군/구로 내려주는데 그대로 늘어놓으면
/// 전국 250개 안팎이고, 내가 밝힌 곳은 한두 개라 나머지 0% 타일을 한없이 스크롤하게
/// 된다 — 「모아 놓고 하나씩 채우는」 배지의 맛이 사라진다. 지도 상단 바가 보여주는
/// 지역도 시/도라, 여기 「경기도 3%」가 그 바의 숫자와 같은 것을 가리킨다
/// ([aggregateBySido] — 시/군/구 비율의 평균이 아니라 합산 후 나눈 값).
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
      appBar: AppBar(title: const Text('탐험 현황')),
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
                    Text('탐험 현황을 불러오지 못했어요.', style: Theme.of(context).textTheme.bodyMedium),
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

    // 시/도로 합산한다. 이름을 못 만든 시/도(주소 품질 문제로 서버가 코드로 폴백)는
    // 이름이 비므로 코드를 대신 보여준다 — 드물지만 다른 시/도에 섞이는 것보다 낫다.
    final sidos = aggregateBySido(regions)..sort((a, b) => _badgeLabel(a).compareTo(_badgeLabel(b)));

    if (totalSpots == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            '아직 탐험 기록이 없어요.\n지도를 돌아다니며 스팟을 밝혀보세요.',
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
        const SizedBox(height: AppSpacing.xs),
        ...sidos.map((sido) => _SidoTile(sido: sido)),
      ],
    );
  }
}

/// 배지에 쓸 시/도 이름. 서버가 이름을 못 만든 시/도는 코드라도 보여준다.
String _badgeLabel(ConquestSido sido) => sido.sidoName.isEmpty ? '지역 ${sido.areaCodes.join('·')}' : sido.sidoName;

class _SidoTile extends StatelessWidget {
  const _SidoTile({required this.sido});

  final ConquestSido sido;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (sido.rate * 100).round();
    final displayName = _badgeLabel(sido);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ConquestRegionScreen(sido: sido)),
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
                      '${sido.visitedSpots} / ${sido.totalSpots}',
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
