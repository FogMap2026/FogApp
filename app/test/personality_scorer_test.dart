import 'package:flutter_test/flutter_test.dart';
import 'package:fogapp/models/personality.dart';
import 'package:fogapp/services/personality_scorer.dart';

void main() {
  Map<String, int> uniformAnswers(int value) {
    return {for (final q in PersonalityScorer.questions) q.id: value};
  }

  test('모든 문항에 중간값(3)으로 답하면 각 축 점수는 정확히 50이다', () {
    final result = PersonalityScorer.score(uniformAnswers(3));

    for (final axis in PersonalityAxis.values) {
      expect(result.axisResults[axis]!.score, 50);
    }
  });

  test('가장 외향적인 응답은 외향형(E)·0점으로 분류된다', () {
    final answers = {
      ...uniformAnswers(3),
      'E1': 5, // 역채점(외향 진술) 강하게 동의
      'E2': 1, // 정방향(내향 진술) 강하게 반대
      'E3': 5, // 역채점(외향 진술) 강하게 동의
      'E4': 1, // 정방향(내향 진술) 강하게 반대
    };

    final result = PersonalityScorer.score(answers);

    expect(result.axisResults[PersonalityAxis.extraversion]!.score, 0);
    expect(result.axisResults[PersonalityAxis.extraversion]!.pole, 'E');
  });

  test('가장 계획적인 응답은 계획형(P)·100점으로 분류된다', () {
    final answers = {
      ...uniformAnswers(3),
      'S1': 5, // 정방향(계획) 강하게 동의
      'S2': 1, // 역채점(즉흥) 강하게 반대
      'S3': 5,
      'S4': 1,
    };

    final result = PersonalityScorer.score(answers);

    expect(result.axisResults[PersonalityAxis.spontaneity]!.score, 100);
    expect(result.axisResults[PersonalityAxis.spontaneity]!.pole, 'P');
  });

  test('세 축의 극을 이어붙여 유형 코드를 만든다', () {
    final answers = {
      ...uniformAnswers(3),
      'S1': 5, 'S2': 1, 'S3': 5, 'S4': 1, // P
      'R1': 5, 'R2': 1, 'R3': 5, 'R4': 1, // T
      'E1': 1, 'E2': 5, 'E3': 1, 'E4': 5, // I
    };

    final result = PersonalityScorer.score(answers);

    expect(result.type, 'PTI');
  });

  test('문항 응답이 누락되면 예외를 던진다', () {
    final incomplete = {
      for (final q in PersonalityScorer.questions.skip(1)) q.id: 3,
    };

    expect(() => PersonalityScorer.score(incomplete), throwsArgumentError);
  });

  test('응답 범위(1~5)를 벗어나면 예외를 던진다', () {
    final invalid = {...uniformAnswers(3), 'S1': 6};

    expect(() => PersonalityScorer.score(invalid), throwsArgumentError);
  });
}
