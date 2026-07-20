import 'package:geocoding/geocoding.dart';

/// 역지오코딩 결과([Placemark])에서 지도 상단에 보여줄 "현재 지역(시/도)" 문자열을 뽑아낸다.
/// 필드가 비어 있는 경우를 대비해 시/도 → 시/군/구 순으로 대체한다.
String? regionNameFromPlacemark(Placemark placemark) {
  final administrativeArea = placemark.administrativeArea;
  if (administrativeArea != null && administrativeArea.trim().isNotEmpty) {
    return administrativeArea;
  }

  final subAdministrativeArea = placemark.subAdministrativeArea;
  if (subAdministrativeArea != null && subAdministrativeArea.trim().isNotEmpty) {
    return subAdministrativeArea;
  }

  final locality = placemark.locality;
  if (locality != null && locality.trim().isNotEmpty) {
    return locality;
  }

  return null;
}
