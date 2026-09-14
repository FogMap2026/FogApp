// 좌표가 같은 스팟의 마커를 벌리는 규칙 — 포개져 하나만 보이던 것(인천애뜰·한복사랑, 09-15).
import 'package:flutter_test/flutter_test.dart';
import 'package:fogapp/models/spot.dart';
import 'package:fogapp/services/spot_marker_controller.dart';
import 'package:geolocator/geolocator.dart';

Spot _spot(int id, {double lat = 37.4551, double lng = 126.7061}) =>
    Spot(id: id, contentId: 'c$id', title: '스팟 $id', lat: lat, lng: lng, unlocked: false);

void main() {
  test('좌표가 같은 둘은 6m 반지름 원 위 마주 보는 자리로 — 12m 떨어진다', () {
    final positions = SpotMarkerController.spreadOverlapping([_spot(2), _spot(1)]);
    expect(positions.keys, unorderedEquals([1, 2]));
    final a = positions[1]!;
    final b = positions[2]!;
    final apart = Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);
    expect(apart, closeTo(12, 0.5));
    // 원래 자리에서 각각 6m.
    expect(Geolocator.distanceBetween(a.latitude, a.longitude, 37.4551, 126.7061), closeTo(6, 0.3));
  });

  test('혼자인 스팟은 건드리지 않는다', () {
    final positions = SpotMarkerController.spreadOverlapping([_spot(1), _spot(2, lat: 37.46)]);
    expect(positions, isEmpty);
  });

  test('조회 순서가 달라도 같은 스팟은 같은 자리다', () {
    final first = SpotMarkerController.spreadOverlapping([_spot(1), _spot(2), _spot(3)]);
    final second = SpotMarkerController.spreadOverlapping([_spot(3), _spot(1), _spot(2)]);
    expect(first[1], second[1]);
    expect(first[3], second[3]);
  });
}
