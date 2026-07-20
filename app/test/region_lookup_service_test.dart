import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:fogapp/services/region_lookup_service.dart';

void main() {
  test('administrativeArea가 있으면 그대로 사용한다', () {
    const placemark = Placemark(administrativeArea: '경상북도', locality: '경주시');
    expect(regionNameFromPlacemark(placemark), '경상북도');
  });

  test('administrativeArea가 비어있으면 subAdministrativeArea로 대체한다', () {
    const placemark = Placemark(administrativeArea: '', subAdministrativeArea: '경주시');
    expect(regionNameFromPlacemark(placemark), '경주시');
  });

  test('administrativeArea·subAdministrativeArea가 모두 없으면 locality로 대체한다', () {
    const placemark = Placemark(locality: '경주시');
    expect(regionNameFromPlacemark(placemark), '경주시');
  });

  test('모든 필드가 비어있으면 null을 반환한다', () {
    const placemark = Placemark();
    expect(regionNameFromPlacemark(placemark), isNull);
  });
}
