import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/conquest.dart';
import '../models/spot.dart';
import '../services/spot_service.dart';
import '../theme/app_theme.dart';
import 'spot_detail_screen.dart';

/// 시/도 상세 — [ConquestScreen] 의 배지 하나를 누르면 들어온다.
///
/// **밝혀지지 않은 스팟은 이름만 보여주고 사진·주소는 가린다.** [SpotDetailScreen]이
/// 잠긴 스팟에서 지키는 규칙과 같다 — 이름까지 가리면 갈 곳을 고를 수 없고(시진, 09-14),
/// 사진·주소·소개가 탐험의 보상으로 남는다. 잠긴 스팟은 시/도당 최대 1000개라
/// 슬리버로 게을리 그린다 — 전부 미리 만들면 화면 진입이 느리다.
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

                  final muted = theme.textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted);
                  return CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        sliver: SliverList.list(
                          children: [
                            Text('밝힌 스팟 (${unlocked.length})', style: theme.textTheme.titleMedium),
                            const SizedBox(height: AppSpacing.xs),
                            if (unlocked.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                                child: Text('아직 밝힌 스팟이 없어요.', style: muted),
                              )
                            else
                              ...unlocked.map((s) => _UnlockedSpotTile(spot: s)),
                            const SizedBox(height: AppSpacing.lg),
                            Text('밝혀지지 않은 스팟 (${locked.length})', style: theme.textTheme.titleMedium),
                            const SizedBox(height: AppSpacing.xs),
                            if (locked.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                                child: Text('이 지역 스팟을 전부 밝혔어요 🎉', style: muted),
                              ),
                          ],
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
                        sliver: SliverList.builder(
                          itemCount: locked.length,
                          itemBuilder: (context, i) => _LockedSpotTile(spot: locked[i]),
                        ),
                      ),
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

/// 밝혀지지 않은 스팟 하나 — 이름과 자물쇠만. 누르면 [SpotDetailScreen] 의 잠긴 화면으로
/// 간다(거기서 발자취 남기기까지 할 수 있다). 사진 자리엔 자물쇠를 둬 밝힌 타일과 한눈에
/// 갈린다.
class _LockedSpotTile extends StatelessWidget {
  const _LockedSpotTile({required this.spot});

  final Spot spot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SpotDetailScreen(spot: spot)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
          child: Row(
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: Icon(Icons.lock_outline, size: 18, color: AppColors.inkFaint),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  spot.title,
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}
