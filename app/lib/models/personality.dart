/// 여행 성향 축(docs/personality-test-design.md 2장).
/// 0=첫 번째 극, 100=두 번째 극에 가까움.
enum PersonalityAxis { spontaneity, restVsRoam, extraversion }

/// 성향 설문 문항 하나.
/// [reverseScored]가 true면 응답을 6-응답으로 변환해 합산한다(설계 문서 4.1).
class PersonalityQuestion {
  const PersonalityQuestion({
    required this.id,
    required this.axis,
    required this.text,
    required this.reverseScored,
  });

  final String id;
  final PersonalityAxis axis;
  final String text;
  final bool reverseScored;
}

/// 축 하나의 채점 결과.
class AxisResult {
  const AxisResult({required this.score, required this.pole});

  /// 0~100 정규화 점수.
  final int score;

  /// 축의 극 문자(예: 'S'/'P', 'R'/'T', 'E'/'I').
  final String pole;
}

/// 성향 테스트 전체 결과. `personality_type`/`personality_scores` 저장 포맷과 1:1 대응한다.
class PersonalityResult {
  const PersonalityResult({
    required this.type,
    required this.axisResults,
    required this.answeredAt,
  });

  /// 세 축의 극을 이어붙인 유형 코드(예: "PRI").
  final String type;

  final Map<PersonalityAxis, AxisResult> axisResults;
  final DateTime answeredAt;

  /// `users.personality_scores` JSONB 저장 포맷(설계 문서 4.3).
  Map<String, dynamic> toScoresJson() {
    return {
      'version': 1,
      'axes': {
        for (final axis in PersonalityAxis.values)
          _axisKey(axis): {
            'score': axisResults[axis]!.score,
            'pole': axisResults[axis]!.pole,
          },
      },
      'answeredAt': answeredAt.toIso8601String(),
    };
  }

  static String _axisKey(PersonalityAxis axis) {
    switch (axis) {
      case PersonalityAxis.spontaneity:
        return 'spontaneity';
      case PersonalityAxis.restVsRoam:
        return 'restVsRoam';
      case PersonalityAxis.extraversion:
        return 'extraversion';
    }
  }
}
