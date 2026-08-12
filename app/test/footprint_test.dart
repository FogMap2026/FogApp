import 'package:flutter_test/flutter_test.dart';
import 'package:fogapp/models/footprint.dart';

void main() {
  test('Footprint.fromJson이 서버 응답 필드를 그대로 매핑한다', () {
    final footprint = Footprint.fromJson({
      'id': 1,
      'userId': 7,
      'spotId': 42,
      'content': '여기 정말 좋았어요',
      'photoUrl': null,
      'likeCount': 3,
      'createdAt': '2026-08-12T10:00:00+09:00',
      'updatedAt': '2026-08-12T10:00:00+09:00',
    });

    expect(footprint.id, 1);
    expect(footprint.userId, 7);
    expect(footprint.spotId, 42);
    expect(footprint.content, '여기 정말 좋았어요');
    expect(footprint.photoUrl, isNull);
    expect(footprint.likeCount, 3);
  });

  test('photoUrl이 있으면 그대로 채워진다', () {
    final footprint = Footprint.fromJson({
      'id': 1,
      'userId': 7,
      'spotId': 42,
      'content': '사진도 남겨요',
      'photoUrl': '/api/visits/photos/uid/42/1.jpg',
      'likeCount': 0,
      'createdAt': '2026-08-12T10:00:00+09:00',
      'updatedAt': '2026-08-12T10:00:00+09:00',
    });

    expect(footprint.photoUrl, '/api/visits/photos/uid/42/1.jpg');
  });
}
