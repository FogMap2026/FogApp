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

  test('길목 글귀는 spotId 없이 좌표만 온다 (#115)', () {
    final footprint = Footprint.fromJson({
      'id': 9,
      'userId': 7,
      'spotId': null,
      'lat': 37.5665,
      'lng': 126.978,
      'content': '여기서 왼쪽 골목이 예뻐요',
      'likeCount': 0,
      'createdAt': '2026-09-05T10:00:00+09:00',
    });

    expect(footprint.spotId, isNull);
    expect(footprint.lat, 37.5665);
    expect(footprint.lng, 126.978);
  });

  test('좌표 없는 예전 글은 lat·lng가 null이다 — 지도에 그릴 수 없다 (#117)', () {
    final footprint = Footprint.fromJson({
      'id': 3,
      'userId': 7,
      'spotId': 42,
      'content': '좌표가 생기기 전에 쓴 글',
      'likeCount': 0,
      'createdAt': '2026-08-12T10:00:00+09:00',
    });

    expect(footprint.lat, isNull);
    expect(footprint.lng, isNull);
  });

  test('정수로 온 좌표도 double로 읽는다', () {
    // 서버가 JSON 으로 37.0 을 37 로 직렬화하면 num→double 변환이 없으면 깨진다.
    final footprint = Footprint.fromJson({
      'id': 4,
      'userId': 7,
      'spotId': null,
      'lat': 37,
      'lng': 127,
      'content': '정수 좌표',
      'likeCount': 0,
      'createdAt': '2026-09-05T10:00:00+09:00',
    });

    expect(footprint.lat, 37.0);
    expect(footprint.lng, 127.0);
  });
}
