import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/conquest.dart';
import '../models/spot.dart';
import '../services/spot_service.dart';
import '../theme/app_theme.dart';
import 'spot_detail_screen.dart';

/// 시/도 상세 — [ConquestScreen] 의 배지 하나를 누르면 들어온다.
///
/// **밝혀지지 않은 스팟은 이름·사진을 보여주지 않는다.** [SpotDetailScreen]이 잠긴
/// 스팟에서 지키는 규칙과 같다 — 서버가 `overview`만 가리는 게 아니라, 앱도 "탐험의
/// 보상"이 스포일러 없이 유지되도록 이름까지 감춘다. 이 화면이 값을 갖고 있어도
/// (서버는 title·addr를 잠긴 스팟에도 내려준다) 화면에 옮기지 않는다.
class ConquestRegionScreen extends ConsumerStatefulWidget {
  const ConquestRegionScreen({required this.sido, super.key});

  final ConquestSido sido;

  @override
  ConsumerState<ConquestRegionScreen> createState() => _ConquestRegionScreenState();
}

class _ConquestRegionScreenState extends ConsumerState<ConquestRegionScreen> {
  late Future<List<Spot>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /// 서버 `GET /api/spots?region=` 이 시/도(`areaCode`) 단위로 걸러 준다 — 배지가
  /// 시/도라서 그대로 맞는다. 통합된 시/도는 코드가 여럿이라([ConquestSido.areaCodes])
  /// 전부 받아 잇는다. 페이지를 끝까지 받는다(밝힌/안 밝힌 개수를 세므로 일부만
  /// 받으면 숫자가 틀린다).
  Future<List<Spot>> _load() async {
    final service = ref.read(spotServiceProvider);
    final all = <Spot>[];
    for (final code in widget.sido.areaCodes) {
      all.addAll(await service.fetchAllByRegion(code));
    }
    return all;
  }

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final sido = widget.sido;
    final theme = Theme.of(context);
    final percent = (sido.rate * 100).round();

    return Scaffold(
      backgroundColor: AppColors.canvasSoft,
      appBar: AppBar(title: Text(sido.sidoName.isEmpty ? '지역 ${sido.areaCodes.join('·')}' : sido.sidoName)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${sido.visitedSpots} / ${sido.totalSpots} 스팟 밝힘', style: theme.textTheme.titleSmall),
                      Text('$percent%', style: theme.textTheme.titleSmall?.copyWith(color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.xs),
                    child: LinearProgressIndicator(
                      value: sido.rate,
                      minHeight: 6,
                      backgroundColor: AppColors.hairline,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Spot>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('스팟 목록을 불러오지 못했어요.', style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 8),
                          TextButton(onPressed: _retry, child: const Text('다시 시도')),
                        ],
                      ),
                    );
                  }
                  final spots = snapshot.data ?? const <Spot>[];
                  final unlocked = spots.where((s) => s.unlocked).toList();
                  final locked = spots.where((s) => !s.unlocked).toList();

                  return ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      Text('밝힌 스팟 (${unlocked.length})', style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      if (unlocked.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                          child: Text(
                            '아직 밝힌 스팟이 없어요.',
                            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
                          ),
                        )
                      else
                        ...unlocked.map((s) => _UnlockedSpotTile(spot: s)),
                      const SizedBox(height: AppSpacing.lg),
                      Text('밝혀지지 않은 스팟 (${locked.length})', style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      if (locked.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                          child: Text(
                            '이 지역 스팟을 전부 밝혔어요 🎉',
                            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
                          ),
                        )
                      else
                        _LockedSpotGrid(count: locked.length),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnlockedSpotTile extends StatelessWidget {
  const _UnlockedSpotTile({required this.spot});

  final Spot spot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final address = [spot.addr1, spot.addr2].whereType<String>().where((s) => s.isNotEmpty).join(' ');
    final image = spot.firstImage;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: spot)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: (image == null || image.isEmpty)
                      ? const _ImagePlaceholder(icon: Icons.photo_outlined)
                      : Image.network(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const _ImagePlaceholder(icon: Icons.broken_image_outlined),
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(spot.title, style: theme.textTheme.bodyLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (address.isNotEmpty)
                      Text(
                        address,
                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.canvasSoft,
      child: Icon(icon, color: AppColors.inkFaint, size: 20),
    );
  }
}

/// 밝혀지지 않은 스팟들 — [ConquestRegionScreen]의 문서 주석에 적은 이유로 이름·사진을
/// 보여주지 않고, 몇 개가 남았는지만 물음표 타일로 알려준다. 탭해도 아무 일도 하지
/// 않는다 — 잠긴 스팟은 [SpotDetailScreen]도 정보 없이 "밝혀지지 않았다"는 안내만
/// 보여주므로, 여기서 굳이 그 화면을 또 열게 할 이유가 없다.
class _LockedSpotGrid extends StatelessWidget {
  const _LockedSpotGrid({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: AppSpacing.xs,
        crossAxisSpacing: AppSpacing.xs,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(color: AppColors.hairline),
        ),
        child: const Icon(Icons.help_outline, color: AppColors.inkFaint, size: 20),
      ),
    );
  }
}
