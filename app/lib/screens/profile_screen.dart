import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/footprint.dart';
import '../models/personality.dart';
import '../models/profile.dart';
import '../services/footprint_service.dart';
import '../services/profile_service.dart';
import '../widgets/footprint_card.dart';
import '../widgets/personality_axis_bar.dart';
import 'social/personality_test_screen.dart';

/// 프로필 화면(#73, 5-3) — 앱의 첫 프로필 화면. "내 성향"과 "내 발자취 모아보기"를 담는다.
///
/// 나중에 붙을 것들(정복률 요약 #51, 내 인증 목록 #48, 매칭 Phase 5)은
/// 서버 API가 이미 있으니 화면만 늘리면 된다 — 이번 스코프에서는 넣지 않는다.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late Future<Profile> _profileFuture;
  Future<List<Footprint>>? _footprintsFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<Profile> _loadProfile() async {
    final profile = await ref.read(profileServiceProvider).me();
    if (mounted) {
      setState(() => _footprintsFuture = ref.read(footprintServiceProvider).listByUser(profile.id));
    }
    return profile;
  }

  void _refreshFootprints(int userId) {
    setState(() => _footprintsFuture = ref.read(footprintServiceProvider).listByUser(userId));
  }

  /// 성향 테스트(#31) 화면에 다녀온 뒤 프로필을 다시 불러온다. 저장했는지 여부를
  /// 이 화면으로 돌려주는 경로가 없어서, 안 바뀌었어도 그냥 한 번 더 조회한다 —
  /// 조회는 가벼운 작업이라 낭비가 크지 않다.
  Future<void> _openPersonalityTest() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PersonalityTestScreen()),
    );
    if (mounted) setState(() => _profileFuture = _loadProfile());
  }

  Future<void> _editFootprint(Footprint footprint, int userId) async {
    final controller = TextEditingController(text: footprint.content);
    final newContent = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('발자취 수정'),
        content: TextField(controller: controller, maxLines: 5, maxLength: 1000, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (newContent == null || newContent.isEmpty || !mounted) return;

    try {
      await ref.read(footprintServiceProvider).update(
            footprintId: footprint.id,
            content: newContent,
            photoUrl: footprint.photoUrl,
          );
      if (mounted) _refreshFootprints(userId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('수정하지 못했어요.')));
      }
    }
  }

  Future<void> _deleteFootprint(Footprint footprint, int userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('발자취를 삭제할까요?'),
        content: const Text('삭제하면 되돌릴 수 없어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('삭제')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(footprintServiceProvider).delete(footprint.id);
      if (mounted) _refreshFootprints(userId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('삭제하지 못했어요.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 프로필')),
      body: SafeArea(
        child: FutureBuilder<Profile>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('프로필을 불러오지 못했어요.'),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => setState(() => _profileFuture = _loadProfile()),
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              );
            }
            final profile = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ProfileHeader(profile: profile),
                const SizedBox(height: 24),
                _PersonalitySection(profile: profile, onRetakeTest: _openPersonalityTest),
                const SizedBox(height: 24),
                Text('내 발자취', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _buildFootprintList(profile.id),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFootprintList(int userId) {
    final future = _footprintsFuture;
    if (future == null) return const SizedBox.shrink();

    return FutureBuilder<List<Footprint>>(
      future: future,
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
                  const Text('발자취를 불러오지 못했어요.'),
                  const SizedBox(height: 8),
                  TextButton(onPressed: () => _refreshFootprints(userId), child: const Text('다시 시도')),
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
                '아직 남긴 발자취가 없어요',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final footprint in footprints)
              FootprintCard(
                footprint: footprint,
                onEdit: () => _editFootprint(footprint, userId),
                onDelete: () => _deleteFootprint(footprint, userId),
              ),
          ],
        );
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = profile.profileImageUrl;
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          backgroundImage: (imageUrl != null && imageUrl.isNotEmpty) ? NetworkImage(imageUrl) : null,
          onBackgroundImageError: (imageUrl != null && imageUrl.isNotEmpty) ? (_, __) {} : null,
          child: (imageUrl == null || imageUrl.isEmpty)
              ? const Icon(Icons.person_outline, size: 28, color: Colors.black45)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (profile.nickname != null && profile.nickname!.isNotEmpty) ? profile.nickname! : '이름 없는 여행자',
                style: theme.textTheme.titleMedium,
              ),
              Text(
                profile.email,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 내 성향 표시(5-3). 테스트를 안 했으면([Profile.personalityType]이 null) 유도 안내를,
/// 했으면 유형명 + 축별 점수를 보여준다.
class _PersonalitySection extends StatelessWidget {
  const _PersonalitySection({required this.profile, required this.onRetakeTest});

  final Profile profile;
  final VoidCallback onRetakeTest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = profile.personalityType;

    if (type == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('아직 성향 테스트를 하지 않았어요', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                '테스트를 하면 나에게 맞는 여행 스타일을 알 수 있어요.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(onPressed: onRetakeTest, child: const Text('성향 테스트 하러 가기')),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('내 여행 성향: $type', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            for (final axis in PersonalityAxis.values)
              if (profile.personalityScores[axis] != null) ...[
                PersonalityAxisBar(axis: axis, score: profile.personalityScores[axis]!),
                const SizedBox(height: 12),
              ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onRetakeTest, child: const Text('다시 테스트하기')),
            ),
          ],
        ),
      ),
    );
  }
}
