import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/personality.dart';
import '../../services/personality_service.dart';

/// 성향 테스트 결과 화면(#31). 유형 코드·축별 점수를 보여주고 서버 저장을 시도한다.
class PersonalityResultScreen extends ConsumerStatefulWidget {
  const PersonalityResultScreen({super.key, required this.result});

  final PersonalityResult result;

  @override
  ConsumerState<PersonalityResultScreen> createState() => _PersonalityResultScreenState();
}

class _PersonalityResultScreenState extends ConsumerState<PersonalityResultScreen> {
  bool _isSaving = false;
  bool _saved = false;
  String? _errorMessage;

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await ref.read(personalityServiceProvider).saveResult(widget.result);
      if (mounted) setState(() => _saved = true);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = '결과 저장에 실패했습니다. 나중에 다시 시도해주세요.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;

    return Scaffold(
      appBar: const AppBar(title: Text('내 여행 성향')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              result.type,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 24),
            for (final axis in PersonalityAxis.values) ...[
              _AxisBar(axis: axis, axisResult: result.axisResults[axis]!),
              const SizedBox(height: 16),
            ],
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton(
              onPressed: _isSaving || _saved ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_saved ? '저장됨' : '결과 저장'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AxisBar extends StatelessWidget {
  const _AxisBar({super.key, required this.axis, required this.axisResult});

  final PersonalityAxis axis;
  final AxisResult axisResult;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${_axisLabel(axis)} — ${axisResult.pole} (${axisResult.score}점)'),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: axisResult.score / 100),
      ],
    );
  }

  String _axisLabel(PersonalityAxis axis) {
    switch (axis) {
      case PersonalityAxis.spontaneity:
        return '즉흥성 ↔ 계획성';
      case PersonalityAxis.restVsRoam:
        return '휴양 ↔ 관광';
      case PersonalityAxis.extraversion:
        return '외향 ↔ 내향';
    }
  }
}
