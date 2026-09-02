import 'package:flutter/material.dart';

import '../models/personality.dart';

/// 성향 축 하나를 막대로 보여준다(5-3). 성향 결과 화면(#31)과 프로필이 함께 쓴다 —
/// 같은 표현을 두 화면에서 따로 만들지 않기 위해 여기 하나로 둔다.
///
/// [pole](축의 극 문자, 예: 'P')은 방금 채점한 결과에서만 있다. 서버에서 다시
/// 조회한 값([PersonalityScoreParser]가 축별 점수만 뽑아 내려줌)은 점수뿐이라
/// 없어도 되게 했다.
class PersonalityAxisBar extends StatelessWidget {
  const PersonalityAxisBar({required this.axis, required this.score, this.pole, super.key});

  final PersonalityAxis axis;
  final int score;
  final String? pole;

  @override
  Widget build(BuildContext context) {
    final suffix = pole != null ? ' — $pole ($score점)' : ' ($score점)';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${_axisLabel(axis)}$suffix'),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: score / 100),
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
