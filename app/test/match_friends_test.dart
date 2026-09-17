import 'package:flutter_test/flutter_test.dart';
import 'package:fogapp/models/chat_message.dart';
import 'package:fogapp/models/match.dart';

/// 친구 = 수락된 매칭. 친구 목록·친구 요청 탭이 같은 `GET /api/matches` 를 어떻게 나누는지.
void main() {
  Match match({
    required int id,
    required int counterpartId,
    required String status,
    String direction = 'SENT',
    String createdAt = '2026-09-15T10:00:00Z',
  }) =>
      Match(
        id: id,
        requesterId: direction == 'SENT' ? 1 : counterpartId,
        addresseeId: direction == 'SENT' ? counterpartId : 1,
        status: status,
        direction: direction,
        counterpartId: counterpartId,
        createdAt: DateTime.parse(createdAt),
      );

  test('수락된 것만 친구다', () {
    final friends = Match.friendsOf([
      match(id: 1, counterpartId: 10, status: 'accepted'),
      match(id: 2, counterpartId: 11, status: 'pending'),
      match(id: 3, counterpartId: 12, status: 'rejected'),
    ]);
    expect(friends.map((m) => m.id), [1]);
  });

  test('서로 요청해 둘 다 수락되면 친구는 한 명 — 먼저 맺은 매칭(같은 대화방)을 쓴다', () {
    final friends = Match.friendsOf([
      match(id: 7, counterpartId: 10, status: 'accepted', direction: 'RECEIVED', createdAt: '2026-09-15T12:00:00Z'),
      match(id: 5, counterpartId: 10, status: 'accepted', createdAt: '2026-09-15T09:00:00Z'),
    ]);
    expect(friends.map((m) => m.id), [5]);
  });

  test('이미 친구인 상대와의 대기 요청은 친구 요청 탭에 남기지 않는다', () {
    final requests = Match.requestsOf([
      match(id: 1, counterpartId: 10, status: 'accepted'),
      match(id: 2, counterpartId: 10, status: 'pending', direction: 'RECEIVED'),
      match(id: 3, counterpartId: 11, status: 'pending', direction: 'RECEIVED'),
    ]);
    expect(requests.map((m) => m.id), [3]);
  });

  test('메시지 파싱 — mine 은 서버가 계산한 값 그대로', () {
    final message = ChatMessage.fromJson({
      'id': 3,
      'matchId': 5,
      'mine': true,
      'content': '안녕',
      'createdAt': '2026-09-15T10:00:00Z',
    });
    expect(message.mine, isTrue);
    expect(message.content, '안녕');
  });
}
