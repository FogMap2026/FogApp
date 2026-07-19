import 'package:flutter/material.dart';

import '../../models/personality.dart';
import '../../services/personality_scorer.dart';
import 'personality_result_screen.dart';

/// 여행 성향 설문 화면(#31). 12문항에 모두 응답하면 채점 후 결과 화면으로 이동한다.
class PersonalityTestScreen extends StatefulWidget {
  const PersonalityTestScreen({super.key});

  @override
  State<PersonalityTestScreen> createState() => _PersonalityTestScreenState();
}

class _PersonalityTestScreenState extends State<PersonalityTestScreen> {
  final Map<String, int> _answers = {};

  bool get _allAnswered => _answers.length == PersonalityScorer.questions.length;

  void _submit() {
    final result = PersonalityScorer.score(_answers);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PersonalityResultScreen(result: result)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const questions = PersonalityScorer.questions;

    return Scaffold(
      appBar: AppBar(title: const Text('여행 성향 테스트')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: questions.length + 1,
        separatorBuilder: (_, __) => const Divider(height: 32),
        itemBuilder: (context, index) {
          if (index == questions.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FilledButton(
                onPressed: _allAnswered ? _submit : null,
                child: const Text('결과 보기'),
              ),
            );
          }

          final question = questions[index];
          return _QuestionTile(
            question: question,
            value: _answers[question.id],
            onChanged: (value) => setState(() => _answers[question.id] = value),
          );
        },
      ),
    );
  }
}

class _QuestionTile extends StatelessWidget {
  const _QuestionTile({
    required this.question,
    required this.value,
    required this.onChanged,
  });

  final PersonalityQuestion question;
  final int? value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question.text, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('전혀 아니다', style: TextStyle(fontSize: 11, color: Colors.grey)),
            Text('매우 그렇다', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (i) {
            final score = i + 1;
            return Column(
              children: [
                Radio<int>(
                  value: score,
                  groupValue: value,
                  onChanged: (v) => onChanged(v!),
                ),
                Text('$score'),
              ],
            );
          }),
        ),
      ],
    );
  }
}
