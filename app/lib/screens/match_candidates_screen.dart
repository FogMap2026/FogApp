import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/match_candidate.dart';
import '../services/match_service.dart';
import '../services/profile_service.dart';
import 'social/personality_test_screen.dart';

enum _LoadState { loading, needsPersonalityTest, ready, error }

/// 동행 추천 화면(5-1). 성향이 비슷한 사용자를 추천받아 동행을 요청한다.
///
/// `GET /api/matches/candidates`는 "성향 테스트 안 함"과 "후보 0명"을 구분해
/// 내려주지 않는다(둘 다 빈 목록) — 그래서 후보 조회 전에 내 프로필의
/// `personalityType`을 먼저 확인해 두 상태를 나눈다.
class MatchCandidatesScreen extends ConsumerStatefulWidget {
  const MatchCandidatesScreen({super.key});

  @override
  ConsumerState<MatchCandidatesScreen> createState() => _MatchCandidatesScreenState();
}

class _MatchCandidatesScreenState extends ConsumerState<MatchCandidatesScreen> {
  _LoadState _state = _LoadState.loading;
  List<MatchCandidate> _candidates = const [];
  final Set<int> _requestedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);
    try {
      final profile = await ref.read(profileServiceProvider).me();
      if (profile.personalityType == null) {
        if (mounted) setState(() => _state = _LoadState.needsPersonalityTest);
        return;
      }
      final candidates = await ref.read(matchServiceProvider).candidates();
      if (mounted) {
        setState(() {
          _candidates = candidates;
          _state = _LoadState.ready;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _state = _LoadState.error);
    }
  }

  Future<void> _openPersonalityTest() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PersonalityTestScreen()),
    );
    if (mounted) _load();
  }

  Future<void> _requestMatch(MatchCandidate candidate) async {
    try {
      await ref.read(matchServiceProvider).request(addresseeId: candidate.userId);
      if (mounted) {
        setState(() => _requestedIds.add(candidate.userId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${candidate.nickname}님에게 동행을 요청했어요.')),
        );
      }
    } on DioException catch (e) {
      final responseData = e.response?.data;
      final serverMessage = e.response?.statusCode == 400 && responseData is Map
          ? responseData['message'] as String?
          : null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(serverMessage ?? '요청을 보내지 못했어요.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('요청을 보내지 못했어요.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('동행 추천')),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_state) {
      case _LoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case _LoadState.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('추천 후보를 불러오지 못했어요.'),
              const SizedBox(height: 8),
              TextButton(onPressed: _load, child: const Text('다시 시도')),
            ],
          ),
        );
      case _LoadState.needsPersonalityTest:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('성향 테스트를 하면 동행을 추천받을 수 있어요.', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _openPersonalityTest, child: const Text('성향 테스트 하러 가기')),
              ],
            ),
          ),
        );
      case _LoadState.ready:
        if (_candidates.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('아직 추천할 동행이 없어요. 나중에 다시 확인해보세요.', textAlign: TextAlign.center),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _candidates.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final candidate = _candidates[index];
            return _CandidateCard(
              candidate: candidate,
              requested: _requestedIds.contains(candidate.userId),
              onRequest: () => _requestMatch(candidate),
            );
          },
        );
    }
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.candidate, required this.requested, required this.onRequest});

  final MatchCandidate candidate;
  final bool requested;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.person_outline, color: Colors.black45),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(candidate.nickname, style: theme.textTheme.titleSmall),
                  Text(
                    _similarityLabel(candidate.similarity),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: requested ? null : onRequest,
              child: Text(requested ? '요청 보냄' : '동행 요청'),
            ),
          ],
        ),
      ),
    );
  }

  /// 유사도(0~1)를 숫자 그대로 보여주지 않고 구간별 문구로 바꾼다 — 소수점 값이
  /// 실제보다 더 정밀한 판단처럼 보이는 걸 피하기 위해서다(이슈 #93 논의).
  String _similarityLabel(double similarity) {
    if (similarity >= 0.8) return '잘 맞아요';
    if (similarity >= 0.5) return '비슷해요';
    return '다를 수 있어요';
  }
}
