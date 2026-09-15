import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/footprint.dart';
import '../models/spot.dart';
import '../services/favorite_spot_store.dart';
import '../services/footprint_service.dart';
import '../theme/app_theme.dart';
import '../widgets/footprint_card.dart';
import 'footprint_create_screen.dart';

/// 스팟 상세 화면(#50). 마커를 탭하면 열린다 — 발자취 작성(#70)·조회(#71) 진입점도 여기 있다.
///
/// 해금 여부(`unlocked`)로 나뉘는 건 스팟 정보(사진·주소·소개)다 — **이름은 잠긴
/// 스팟에서도 보여준다.** 이름까지 가리면 「잠긴 스팟」이라는 글자만 남아 어디를 눌렀는지
/// 알 길이 없고, 갈 곳을 고를 수도 없다(시진, 09-14). 사진·주소·소개가 탐험의 보상이다.
/// 발자취 **보기**는 잠긴 스팟에서도 된다(#70 결정). **남기기는 인증한 스팟에서만** —
/// 가 보지도 않은 곳에 글이 쌓이면 발자취가 「거기 있었다」는 증거가 아니게 된다
/// (시진, 09-14; #70 의 「독립」 결정을 여기서 좁힌다). 길목 글귀(지도의 발자취 남기기,
/// 스팟 없음)는 이 화면 밖이라 그대로다.
class SpotDetailScreen extends ConsumerStatefulWidget {
  const SpotDetailScreen({required this.spot, super.key});

  final Spot spot;

  @override
  ConsumerState<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends ConsumerState<SpotDetailScreen> {
  bool _overviewExpanded = false;
  late Future<List<Footprint>> _footprintsFuture;

  @override
  void initState() {
    super.initState();
    _footprintsFuture = _loadFootprints();
  }

  Future<List<Footprint>> _loadFootprints() {
    return ref.read(footprintServiceProvider).listBySpot(widget.spot.id);
  }

  void _refreshFootprints() {
    setState(() {
      _footprintsFuture = _loadFootprints();
    });
  }

  Future<void> _openFootprintWrite() async {
    final written = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => FootprintCreateScreen(spot: widget.spot)),
    );
    if (written == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('발자취를 남겼어요.')));
      _refreshFootprints();
    }
  }

  @override
  Widget build(BuildContext context) {
    final spot = widget.spot;
    final favorite = ref.watch(favoriteSpotsProvider.select((list) => list.any((s) => s.id == spot.id)));
    return Scaffold(
      appBar: AppBar(
        title: Text(spot.title),
        actions: [
          // 찜 — 켜면 지도에 항상 뜨고(내 주변 3km 밖이어도) 주황 마커로 갈린다.
          // 잠긴 스팟도 찜할 수 있다: 「가 볼 곳」 표시가 이 기능의 목적이다.
          IconButton(
            onPressed: () => ref.read(favoriteSpotsProvider.notifier).toggle(spot),
            icon: Icon(favorite ? Icons.bookmark : Icons.bookmark_border),
            color: favorite ? AppColors.accentOrange : null,
            tooltip: favorite ? '찜 해제' : '찜',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (spot.unlocked) ..._buildUnlocked(context, spot) else ..._buildLocked(context, spot),
              const SizedBox(height: 24),
              if (spot.unlocked)
                FilledButton.icon(
                  onPressed: _openFootprintWrite,
                  icon: const Icon(Icons.edit_note_outlined),
                  label: const Text('발자취 남기기'),
                )
              else
                Text(
                  '방문 인증을 하면 이 스팟에 발자취를 남길 수 있어요.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              const SizedBox(height: 24),
              Text('발자취', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _buildFootprintList(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFootprintList(BuildContext context) {
    return FutureBuilder<List<Footprint>>(
      future: _footprintsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: [
                  Text('발자취를 불러오지 못했어요.', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _refreshFootprints, child: const Text('다시 시도')),
                ],
              ),
            ),
          );
        }
        final footprints = snapshot.data!;
        if (footprints.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                widget.spot.unlocked ? '첫 발자취를 남겨보세요' : '아직 발자취가 없어요',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          );
        }
        return Column(
          children: [for (final footprint in footprints) FootprintCard(footprint: footprint)],
        );
      },
    );
  }

  List<Widget> _buildLocked(BuildContext context, Spot spot) {
    final theme = Theme.of(context);
    return [
      const SizedBox(height: 40),
      const Center(child: Icon(Icons.lock_outline, size: 72, color: AppColors.inkFaint)),
      const SizedBox(height: 16),
      Center(child: Text(spot.title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center)),
      const SizedBox(height: 8),
      Center(
        child: Text('아직 밝혀지지 않은 곳이에요', style: theme.textTheme.titleMedium),
      ),
      const SizedBox(height: 4),
      Center(
        child: Text(
          '현장에서 방문 인증을 하면 소개가 열려요.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ),
    ];
  }

  List<Widget> _buildUnlocked(BuildContext context, Spot spot) {
    final theme = Theme.of(context);
    final overview = spot.overview;
    // 정확한 줄바꿈 오버플로 여부를 재려면 TextPainter가 필요하지만, 접기/펼치기
    // 버튼을 보여줄지 정하는 데는 길이 기준 정도로 충분하다.
    final needsToggle = (overview?.length ?? 0) > 120;
    final address = [spot.addr1, spot.addr2].whereType<String>().where((s) => s.isNotEmpty).join(' ');

    return [
      _SpotImage(url: spot.firstImage),
      const SizedBox(height: 16),
      Text(spot.title, style: theme.textTheme.headlineSmall),
      if (address.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(address, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
      if (overview != null && overview.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(
          overview,
          maxLines: _overviewExpanded ? null : 4,
          overflow: _overviewExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        if (needsToggle)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _overviewExpanded = !_overviewExpanded),
              child: Text(_overviewExpanded ? '접기' : '더 보기'),
            ),
          ),
      ],
    ];
  }
}

/// 대표 이미지. 없거나 로드에 실패하면 자리표시 아이콘으로 대체한다(#50) —
/// 관광공사 데이터의 `firstImage`가 비어 있는 경우가 많아 필요하다.
class _SpotImage extends StatelessWidget {
  const _SpotImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final placeholderColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    final imageUrl = url;
    if (imageUrl == null || imageUrl.isEmpty) {
      return _placeholder(placeholderColor, Icons.photo_outlined);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(placeholderColor, Icons.broken_image_outlined),
      ),
    );
  }

  Widget _placeholder(Color color, IconData icon) {
    return Container(
      height: 180,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Center(child: Icon(icon, size: 48, color: AppColors.hairline)),
    );
  }
}
