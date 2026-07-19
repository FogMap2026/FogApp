import '../models/personality.dart';

/// docs/personality-test-design.md 3장·4장을 그대로 구현한 문항 뱅크 + 채점 로직.
class PersonalityScorer {
  PersonalityScorer._();

  static const List<PersonalityQuestion> questions = [
    PersonalityQuestion(
      id: 'S1',
      axis: PersonalityAxis.spontaneity,
      text: '여행 전에 일정을 시간 단위로 미리 짜 놓는 편이다',
      reverseScored: false,
    ),
    PersonalityQuestion(
      id: 'S2',
      axis: PersonalityAxis.spontaneity,
      text: '숙소나 교통은 출발 직전에 정해도 괜찮다',
      reverseScored: true,
    ),
    PersonalityQuestion(
      id: 'S3',
      axis: PersonalityAxis.spontaneity,
      text: '예상 밖의 일정 변경이 생기면 스트레스를 받는다',
      reverseScored: false,
    ),
    PersonalityQuestion(
      id: 'S4',
      axis: PersonalityAxis.spontaneity,
      text: '여행 중 마음에 드는 곳이 있으면 계획 없이 더 머문다',
      reverseScored: true,
    ),
    PersonalityQuestion(
      id: 'R1',
      axis: PersonalityAxis.restVsRoam,
      text: '여행지에서 최대한 많은 장소를 둘러보고 싶다',
      reverseScored: false,
    ),
    PersonalityQuestion(
      id: 'R2',
      axis: PersonalityAxis.restVsRoam,
      text: '숙소나 자연 속에서 느긋하게 쉬는 것이 여행의 목적이다',
      reverseScored: true,
    ),
    PersonalityQuestion(
      id: 'R3',
      axis: PersonalityAxis.restVsRoam,
      text: '하루에 방문할 스팟 개수가 많을수록 만족도가 높다',
      reverseScored: false,
    ),
    PersonalityQuestion(
      id: 'R4',
      axis: PersonalityAxis.restVsRoam,
      text: '일정이 비어 있어도 굳이 채우려 하지 않는다',
      reverseScored: true,
    ),
    PersonalityQuestion(
      id: 'E1',
      axis: PersonalityAxis.extraversion,
      text: '여행 중 만난 낯선 사람과 대화를 먼저 시작하는 편이다',
      reverseScored: true,
    ),
    PersonalityQuestion(
      id: 'E2',
      axis: PersonalityAxis.extraversion,
      text: '혼자 조용히 둘러보는 시간이 꼭 필요하다',
      reverseScored: false,
    ),
    PersonalityQuestion(
      id: 'E3',
      axis: PersonalityAxis.extraversion,
      text: '동행이 많을수록 여행이 즐겁다',
      reverseScored: true,
    ),
    PersonalityQuestion(
      id: 'E4',
      axis: PersonalityAxis.extraversion,
      text: '사람이 많은 장소보다 한적한 장소를 선호한다',
      reverseScored: false,
    ),
  ];

  /// [answers]: 문항 id -> 응답(1~5). 12문항 모두 응답이 있어야 한다.
  static PersonalityResult score(Map<String, int> answers) {
    final axisResults = <PersonalityAxis, AxisResult>{};

    for (final axis in PersonalityAxis.values) {
      var rawTotal = 0;
      for (final question in questions.where((q) => q.axis == axis)) {
        final answer = answers[question.id];
        if (answer == null || answer < 1 || answer > 5) {
          throw ArgumentError('문항 ${question.id}에 대한 응답(1~5)이 필요합니다.');
        }
        rawTotal += question.reverseScored ? (6 - answer) : answer;
      }

      final normalized = ((rawTotal - 4) / 16 * 100).round();
      axisResults[axis] = AxisResult(score: normalized, pole: _poleFor(axis, normalized));
    }

    final type = PersonalityAxis.values.map((axis) => axisResults[axis]!.pole).join();
    return PersonalityResult(type: type, axisResults: axisResults, answeredAt: DateTime.now());
  }

  static String _poleFor(PersonalityAxis axis, int score) {
    final aboveMid = score > 50;
    switch (axis) {
      case PersonalityAxis.spontaneity:
        return aboveMid ? 'P' : 'S';
      case PersonalityAxis.restVsRoam:
        return aboveMid ? 'T' : 'R';
      case PersonalityAxis.extraversion:
        return aboveMid ? 'I' : 'E';
    }
  }
}
