import 'dart:async';
import 'dart:ui' show Size;

import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';

import 'location_permission_gate.dart';
import 'smooth_location.dart';

/// 배터리를 고려한 실시간 위치 추적기(#29).
///
/// flutter_naver_map의 기본 트래커([NDefaultMyLocationTracker])는 위치 갱신
/// 주기·정확도를 Dart 쪽에서 설정할 방법이 없다(네이티브 코드에 고정되어 있음).
/// 이미 의존성으로 들어와 있는 `geolocator`로 직접 구현해 다음을 명시적으로 제어한다.
///
/// - 정확도: [LocationAccuracy.high] (배터리 소모가 큰 `best`/`bestForNavigation` 대신)
/// - 갱신 조건: **두 가지를 나눈다.**
///   - 안개·걸어온 자리·근접 판정([locationSettings]) — 15m 이상 움직였을 때만. 제자리에서
///     불필요한 갱신·서버 저장을 막는다.
///   - 화면의 내 위치 표시([markerLocationSettings]) — 거리 제한 없이 받는 대로. 15m 마다
///     받으면 캐릭터가 **15m 씩 순간이동**한다(사용자 제보, 09-17). 받은 점 사이는
///     [SmoothLocation] 이 채워 미끄러지듯 움직이게 한다.
/// - 방향(heading)은 GPS가 아니라 나침반 센서(`flutter_compass`)를 사용한다 — GPS
///   이동 방향은 실제로 움직여야만 갱신되어, 제자리에서 기기를 돌렸을 때 화살표가
///   반응하지 않는 문제가 있다.
///
/// 포그라운드/백그라운드 전환 시 스트림 구독을 멈추고 재개하는 것은 상위 클래스
/// [NMyLocationTracker]가 기본으로 처리한다. `MapScreen`은 여기에 더해 백그라운드
/// 진입 시 추적 모드 자체를 끄는 더 적극적인 절전 처리를 별도로 수행한다.
class FogLocationTracker extends NMyLocationTracker {
  /// geofencing(#45) 등 다른 위치 구독자도 같은 배터리 절충안을 쓰도록 공개해둔다 —
  /// 독립된 GPS 스트림을 또 만들 때 서로 다른 정확도/주기를 쓰지 않게 하기 위함.
  static const locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 15,
  );

  /// 화면의 내 위치 표시 전용 — **거리 제한 없이** 받는 대로(≈1초에 한 번).
  ///
  /// 🔴 이 값을 [locationSettings] 와 합치지 말 것. 합치면 안개 궤적·`journey_points` 서버
  /// 저장·근접 재계산이 1초마다 돌아 서버 행과 배터리가 함께 늘어난다. 여기서 촘촘히 받는 점은
  /// **화면에만** 쓴다.
  static const markerLocationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
  );

  /// 받은 점 사이를 채우는 간격 — 60fps 까지 갈 이유는 없다. 15fps 면 사람 눈에 이어져 보이고
  /// 오버레이 갱신도 초당 15번이면 충분하다.
  static const markerTickInterval = Duration(milliseconds: 66);

  @override
  Future<NLatLng?> startLocationService() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    final permission = await LocationPermissionGate.request();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: locationSettings.accuracy,
    );
    return NLatLng(position.latitude, position.longitude);
  }

  /// 내 위치 오버레이에 흘려보내는 좌표.
  ///
  /// GPS 점을 그대로 주면 받은 순간에만 «툭» 옮겨진다. 점은 [markerLocationSettings] 로 촘촘히
  /// 받고, 그 사이는 [SmoothLocation] 이 [markerTickInterval] 마다 채운 좌표로 메운다 —
  /// 목표에 닿으면 타이머를 멈춰(`settledAt`) 서 있는 동안은 아무것도 돌지 않는다.
  @override
  Stream<NLatLng> get locationStream {
    final smooth = SmoothLocation();
    StreamSubscription<Position>? fixes;
    Timer? ticker;
    late StreamController<NLatLng> controller;

    void emit() {
      final now = DateTime.now();
      final position = smooth.positionAt(now);
      if (position != null && !controller.isClosed) controller.add(position);
      if (smooth.settledAt(now)) {
        ticker?.cancel();
        ticker = null;
      }
    }

    controller = StreamController<NLatLng>(
      onListen: () {
        fixes = Geolocator.getPositionStream(locationSettings: markerLocationSettings).listen(
          (p) {
            smooth.onFix(NLatLng(p.latitude, p.longitude), at: DateTime.now());
            ticker ??= Timer.periodic(markerTickInterval, (_) => emit());
            emit();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        ticker?.cancel();
        ticker = null;
        await fixes?.cancel();
        fixes = null;
      },
    );
    return controller.stream;
  }

  /// 나침반(자기장 센서) 기반 heading. GPS 이동 방향(`Position.heading`)은 실제로
  /// 이동해야만 값이 바뀌어 "제자리에서 폰만 돌렸을 때" 화살표가 반응하지 않는
  /// 문제가 있어, 기기를 돌리는 즉시 반응하는 나침반 값을 사용한다.
  @override
  Stream<double> get headingStream =>
      (FlutterCompass.events ?? const Stream.empty())
          .map((event) => event.heading)
          .where((heading) => heading != null)
          .cast<double>();

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
