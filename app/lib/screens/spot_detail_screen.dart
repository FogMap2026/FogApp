import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/footprint.dart';
import '../models/spot.dart';
import '../services/footprint_service.dart';
import '../widgets/footprint_card.dart';
import 'footprint_create_screen.dart';

/// 스팟 상세 화면(#50). 마커를 탭하면 열린다 — 발자취 작성(#70)·조회(#71) 진입점도 여기 있다.
///
/// 해금 여부(`unlocked`)로 나뉘는 건 스팟 정보(이름·주소·소개)뿐이다. 발자취는
/// 방문 인증과 독립적이라(#70 결정) 잠긴 스팟에서도 목록을 그대로 보여준다.
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
    setState(() => _footprintsFuture = _loadFootprints());
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
    return Scaffold(
      appBar: AppBar(title: Text(spot.unlocked ? spot.title : '잠긴 스팟')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (spot.unlocked) ..._buildUnlocked(context, spot) else ..._buildLocked(context),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _openFootprintWrite,
                icon: const Icon(Icons.edit_note_outlined),
                label: const Text('발자취 남기기'),
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
                '첫 발자취를 남겨보세요',
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

  List<Widget> _buildLocked(BuildContext context) {
    final theme = Theme.of(context);
    return [
      const SizedBox(height: 40),
      const Center(child: Icon(Icons.help_outline, size: 72, color: Colors.black38)),
      const SizedBox(height: 16),
      Center(
        child: Text('아직 밝혀지지 않은 곳이에요', style: theme.textTheme.titleMedium),
      ),
      const SizedBox(height: 4),
      Center(
        child: Text(
          '현장에서 방문 인증을 하면 이름과 소개가 열려요.',
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
      child: Center(child: Icon(icon, size: 48, color: Colors.black26)),
    );
  }
}
