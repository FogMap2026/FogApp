import 'package:flutter_test/flutter_test.dart';
import 'package:fogapp/models/match_candidate.dart';

/// 동행 추천 후보 파싱(5-1).
///
/// **여기가 깨지면 증상이 엉뚱한 곳에 나온다.** `MatchCandidatesScreen`은 파싱 예외를
/// 화면 단위로 잡아 "추천 후보를 불러오지 못했어요"로 보여주므로, 사용자에게는
/// **서버 장애처럼** 보인다 — 실제로는 후보 한 명의 닉네임이 null인 것뿐이다.
void main() {
  test('닉네임이 null이어도 파싱된다 — 서버가 그대로 내려준다', () {
    // 서버 MatchCandidate 는 User.nickname 을 그대로 담는데, 가입 직후 닉네임을
    // 정하지 않은 사용자가 실제로 있다. non-nullable 로 캐스팅하면 여기서 터진다.
    final candidate = MatchCandidate.fromJson({
      'userId': 7,
      'nickname': null,
      'similarity': 0.87,
    });

    expect(candidate.userId, 7);
    expect(candidate.nickname, isNull);
    expect(candidate.similarity, 0.87);
  });

  test('닉네임이 null이면 대체 문구를 쓴다', () {
    final candidate = MatchCandidate.fromJson({
      'userId': 7,
      'nickname': null,
      'similarity': 0.5,
    });

    // 발자취(Footprint.authorLabel)와 같은 문구여야 한다 — 화면마다 다르게 부르면 안 된다.
    expect(candidate.nicknameLabel, '이름 없는 여행자');
  });

  test('닉네임이 빈 문자열이어도 대체 문구를 쓴다', () {
    final candidate = MatchCandidate.fromJson({
      'userId': 7,
      'nickname': '',
      'similarity': 0.5,
    });

    expect(candidate.nicknameLabel, '이름 없는 여행자');
  });

  test('닉네임이 있으면 그대로 쓴다', () {
    final candidate = MatchCandidate.fromJson({
      'userId': 3,
      'nickname': '앨리스',
      'similarity': 0.42,
    });

    expect(candidate.nicknameLabel, '앨리스');
  });
}
