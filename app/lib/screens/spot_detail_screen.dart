import 'package:flutter/material.dart';

import '../models/spot.dart';
import 'footprint_create_screen.dart';

/// 스팟 상세 화면(#50). 마커를 탭하면 열린다 — 발자취 작성(#70) 진입점도 여기 있다.
///
/// 해금 여부(`unlocked`)로 레이아웃만 나눈다. 서버가 해금 전에는 `overview` 자체를
/// 내려주지 않으므로(`Spot` 모델 문서 참고) 클라이언트가 따로 가릴 정보가 없다.
class SpotDetailScreen extends StatefulWidget {
  const SpotDetailScreen({required this.spot, super.key});

  final Spot spot;

  @override
  State<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends State<SpotDetailScreen> {
  bool _overviewExpanded = false;

  Future<void> _openFootprintWrite() async {
    final written = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => FootprintCreateScreen(spot: widget.spot)),
    );
    if (written == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('발자취를 남겼어요.')));
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
            ],
          ),
        ),
      ),
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
