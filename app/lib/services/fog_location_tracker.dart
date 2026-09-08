import 'dart:ui' show Size;

import 'package:flutter_naver_map/flutter_naver_map.dart';

import 'location_service.dart';

/// 지도 SDK가 요구하는 위치 추적기 인터페이스를 [LocationService]에 연결하는 **어댑터**(#29).
///
/// flutter_naver_map의 기본 트래커([NDefaultMyLocationTracker])는 갱신 주기·정확도를
/// Dart 쪽에서 설정할 방법이 없어(네이티브에 고정) 직접 구현한다. 다만 **GPS 구독은 여기서
/// 열지 않는다** — 앱 전체가 [LocationService] 하나를 공유한다(#135). 예전에는 이 클래스가
/// 자체 스트림을 열어서, `MapScreen`의 근접 감지용 구독과 합쳐 GPS가 두 개 돌았다.
///
/// 방향(heading)은 GPS가 아니라 나침반을 쓴다 — 이유는 [LocationService.headings] 참고.
/// SDK가 [NMyLocationTracker.onHeadingChanged] 기본 구현에서 위치 오버레이의 bearing으로
/// 반영하므로(캐릭터 아이콘 회전, #131) 여기서는 흘려보내기만 하면 된다.
class FogLocationTracker extends NMyLocationTracker {
  FogLocationTracker(this._locationService);

  final LocationService _locationService;

  @override
  Future<NLatLng?> startLocationService() async {
    final started = await _locationService.start();
    if (!started) return null;

    // 스트림 첫 값은 15m를 움직여야 올 수도 있어(`distanceFilter`), 초기 표시는
    // 이미 알고 있는 값이나 즉석 측정으로 채운다.
    final position = _locationService.lastKnown ?? await _locationService.currentPosition();
    return position == null ? null : NLatLng(position.latitude, position.longitude);
  }

  @override
  Stream<NLatLng> get locationStream =>
      _locationService.positions.map((p) => NLatLng(p.latitude, p.longitude));

  @override
  Stream<double> get headingStream => _locationService.headings;

  NOverlayImage? _characterIcon;
  Size? _characterIconSize;

  /// 내 위치에 쓸 캐릭터 아이콘을 등록한다(#131).
  ///
  /// **화면이 위치 오버레이에 한 번 세팅하고 마는 방식으로는 유지되지 않는다.**
  /// [onChangeTrackingMode] 의 기본 구현이 트래킹 모드가 바뀔 때마다
  /// `setIcon(NLocationOverlay.defaultIcon)` 으로 되돌리기 때문이다 — 그래서 아이콘
  /// 관리를 위치 소스 쪽 책임으로 여기 모은다(PR #161 리뷰).
  void setCharacterIcon(NOverlayImage icon, Size size) {
    _characterIcon = icon;
    _characterIconSize = size;
  }

  /// 트래킹 모드가 바뀔 때마다 호출된다(`none ↔ follow` 등). 기본 구현이 아이콘을
  /// 되돌리므로, [super] 로 subIcon·표시 여부는 그대로 위임하고 아이콘만 다시 덮는다.
  ///
  /// 이 경로를 타는 곳이 여럿이다 — 최초 권한 허용 직후(`setLocationTrackingMode(follow)`)와
  /// 앱을 백그라운드로 보냈다 돌아올 때마다. 한 곳에서 처리하지 않으면 그때마다
  /// 기본 파란 점으로 돌아간다.
  ///
  /// ⚠️ **[LocationService] 로 위치 소스를 옮겨도 이 오버라이드는 남아야 한다**(#166 리뷰).
  /// 스트림을 어디서 받든 아이콘을 되돌리는 것은 SDK 쪽 동작이라 그대로다.
  @override
  void onChangeTrackingMode(NLocationOverlay locationOverlay, NLocationTrackingMode mode) {
    super.onChangeTrackingMode(locationOverlay, mode);

    final icon = _characterIcon;
    final size = _characterIconSize;
    if (icon == null || size == null) return;
    locationOverlay
      ..setIcon(icon)
      ..setIconSize(size);
  }
}
