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

  /// 검색어. 비어 있으면 시/군/구로 접어 보여주고, 있으면 접기를 풀고 이름으로 거른다.
  String _query = '';

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
                  final query = _query.trim();
                  // 검색은 밝힌 것·안 밝힌 것 «둘 다» 거른다. 검색 중이면 시/군/구 접기를
                  // 풀고 이름으로 거른 평평한 목록 — 시/도당 1000개를 스크롤로 훑게 하지
                  // 않는다(시진, 09-14).
                  bool hit(Spot s) => query.isEmpty || s.title.contains(query);
                  final shownUnlocked = unlocked.where(hit).toList();
                  final shownLocked = locked.where(hit).toList();
                  final groups = query.isEmpty ? _groupBySigungu(locked) : const <_SigunguGroup>[];

                  return CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        sliver: SliverList.list(
                          children: [
                            if (spots.isNotEmpty) ...[
                              TextField(
                                onChanged: (v) => setState(() => _query = v),
                                decoration: InputDecoration(
                                  hintText: '스팟 이름으로 찾기',
                                  prefixIcon: const Icon(Icons.search, size: 20),
                                  isDense: true,
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppRadii.sm),
                                    borderSide: const BorderSide(color: AppColors.hairline),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            Text(
                              query.isEmpty ? '밝힌 스팟 (${unlocked.length})' : '밝힌 스팟 (${shownUnlocked.length})',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            if (shownUnlocked.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                                child: Text(query.isEmpty ? '아직 밝힌 스팟이 없어요.' : '맞는 스팟이 없어요.', style: muted),
                              )
                            else
                              ...shownUnlocked.map((s) => _UnlockedSpotTile(spot: s)),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              query.isEmpty ? '밝혀지지 않은 스팟 (${locked.length})' : '밝혀지지 않은 스팟 (${shownLocked.length})',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            if (shownLocked.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                                child: Text(query.isEmpty ? '이 지역 스팟을 전부 밝혔어요 🎉' : '맞는 스팟이 없어요.', style: muted),
                              ),
                          ],
                        ),
                      ),
                      if (query.isNotEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
                          sliver: SliverList.builder(
                            itemCount: shownLocked.length,
                            itemBuilder: (context, i) => _LockedSpotTile(spot: shownLocked[i]),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
                          sliver: SliverList.builder(
                            itemCount: groups.length,
                            itemBuilder: (context, i) => _SigunguTile(group: groups[i]),
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

/// 잠긴 스팟을 시/군/구로 묶는다. `addr1`(「경상북도 경주시 …」)의 둘째 토큰이 시/군/구다.
/// 주소가 비었거나 시/도만 있으면 「주소 없음」으로 맨 뒤에 둔다. 그룹은 이름순,
/// 그룹 안은 스팟 이름순.
List<_SigunguGroup> _groupBySigungu(List<Spot> spots) {
  const noAddress = '주소 없음';
  final byName = <String, List<Spot>>{};
  for (final spot in spots) {
    final tokens = (spot.addr1 ?? '').trim().split(' ').where((t) => t.isNotEmpty).toList();
    final name = tokens.length >= 2 ? tokens[1] : noAddress;
    byName.putIfAbsent(name, () => []).add(spot);
  }
  final groups = [
    for (final e in byName.entries)
      _SigunguGroup(name: e.key, spots: e.value..sort((a, b) => a.title.compareTo(b.title))),
  ]..sort((a, b) {
      if (a.name == noAddress) return 1;
      if (b.name == noAddress) return -1;
      return a.name.compareTo(b.name);
    });
  return groups;
}

class _SigunguGroup {
  const _SigunguGroup({required this.name, required this.spots});

  final String name;
  final List<Spot> spots;
}

/// 시/군/구 하나 — 접혀 있고 누르면 그 안의 잠긴 스팟이 펼쳐진다. 자식은 펼칠 때만
/// 만들어지므로(`ExpansionTile` 기본) 1000개를 한 번에 그리지 않는다.
class _SigunguTile extends StatelessWidget {
  const _SigunguTile({required this.group});

  final _SigunguGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Theme(
        // ExpansionTile 이 펼쳐질 때 넣는 위아래 구분선을 뺀다 — 카드 안에서는 군더더기다.
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          // 펼침 애니메이션을 끈다 — 스팟 100개가 «주르륵» 늘어나는 게 어색하다(시진, 09-14).
          // 누르면 바로 펼쳐지고 바로 접힌다.
          expansionAnimationStyle: AnimationStyle.noAnimation,
          title: Text(group.name, style: theme.textTheme.bodyLarge),
          subtitle:
              Text('${group.spots.length}곳', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.inkMuted)),
          childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.xs, 0, AppSpacing.xs, AppSpacing.xs),
          children: [for (final spot in group.spots) _LockedSpotTile(spot: spot)],
        ),
      ),
    );
  }
}
