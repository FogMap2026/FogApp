import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../models/footprint.dart';
import 'footprint_nearby_policy.dart';
import 'footprint_service.dart';

/// 길목에 남은 발자취를 지도에 그린다(#117).
///
/// 언제·얼마나 넓게 부를지는 [FootprintNearbyPolicy]가 정하고, 이 클래스는 그 판정을
/// 받아 실제로 그리기만 한다.
///
/// ## 왜 마커가 아니라 원(circle)인가
///
/// 두 가지 이유가 겹친다.
///
/// 1. **형태가 달라야 한다.** 탐험의 주역은 스팟이고 발자취는 길 위의 발견이라,
///    한눈에 구별되지 않으면 지도가 읽히지 않는다.
/// 2. **[SpotMarkerController]와 충돌하지 않는다.** 그쪽은 카메라가 멈출 때마다
///    `clearOverlays(type: NOverlayType.marker)`로 마커를 통째로 지운다. 발자취를
///    [NMarker]로 그리면 스팟을 다시 불러올 때마다 같이 지워진다 — 오버레이 종류를
///    나눠 두면 서로를 건드릴 수 없다.
///
/// [NCircleOverlay]의 반경은 화면 픽셀이 아니라 **미터**라 줌아웃하면 저절로 작아진다.
/// 줌 임계([FootprintNearbyPolicy.minZoom])로 숨기는 것과 방향이 같아 서로 어긋나지 않는다.
class FootprintMarkerController {
  FootprintMarkerController(
    this._mapController,
    this._footprintService, {
    FootprintNearbyPolicy? policy,
    this.onFootprintTapped,
    this.onStateChanged,
  }) : policy = policy ?? FootprintNearbyPolicy();

  final NaverMapController _mapController;
  final FootprintService _footprintService;

  final FootprintNearbyPolicy policy;

  /// 발자취 도형을 탭했을 때 호출된다 — 화면이 글귀 팝업을 띄운다.
  final void Function(Footprint footprint)? onFootprintTapped;

  /// 조회 상태([loading]·[lastError])가 바뀔 때마다 호출된다 — 화면이 로딩·실패
  /// 표시를 갱신하는 데 쓴다.
  final VoidCallback? onStateChanged;

  /// 지도에 그리는 발자취 한 점의 반경(m). 픽셀이 아니라 지리적 크기라, 탭할 수 있을
  /// 만큼은 크고 길을 덮지는 않을 만큼 작은 값으로 잡았다.
  static const _dotRadiusMeters = 6.0;

  static const _fillColor = Color(0xCC7C4DFF);
  static const _outlineColor = Color(0xFFFFFFFF);

  bool _loading = false;

  /// 줌을 알기 전에는 그리지 않는다. 지도는 전국 뷰(zoom 6.7)로 시작하므로 기본값을
  /// true로 두면 첫 카메라 이벤트가 오기 전에 전국 축척에서 한 번 조회·렌더하게 된다.
  bool _visible = false;

  /// 조회가 진행 중인지. 화면이 로딩 표시에 쓴다(#117).
  bool get loading => _loading;

  /// 마지막 조회가 실패했으면 그 원인, 성공했으면 null. 화면이 안내에 쓴다(#117).
  Object? _lastError;
  Object? get lastError => _lastError;

  void _setState({bool? loading, Object? error, bool clearError = false}) {
    if (loading != null) _loading = loading;
    if (clearError) {
      _lastError = null;
    } else if (error != null) {
      _lastError = error;
    }
    onStateChanged?.call();
  }

  /// 카메라 줌이 바뀌었을 때 호출한다. 임계 아래로 내려가면 그려둔 것을 지우고,
  /// 다시 올라오면 [refresh]가 채운다.
  Future<void> updateZoom(double zoom) async {
    final visible = policy.visibleAt(zoom);
    if (visible == _visible) return;
    _visible = visible;
    if (!visible) {
      await _clear();
    } else {
      // 숨어 있는 동안 기준점이 남아 있으면 다시 보일 때 아무것도 안 그려진다.
      policy.reset();
    }
  }

  /// 현재 위치를 반영해 필요하면 발자취를 다시 불러와 그린다.
  ///
  /// 줌 임계 아래이거나 아직 충분히 움직이지 않았으면 아무것도 하지 않는다 —
  /// 위치 스트림이 초당 여러 번 불러도 안전하다.
  Future<void> refresh({
    required double lat,
    required double lng,
    required bool insideUnlockedSpot,
  }) async {
    if (!_visible || _loading) return;

    final radius = policy.radiusFor(insideUnlockedSpot: insideUnlockedSpot);
    if (!policy.shouldRefetch(lat: lat, lng: lng, radiusMeters: radius)) return;

    _setState(loading: true);
    try {
      final footprints = await _footprintService.listNearby(
        lat: lat,
        lng: lng,
        radiusMeters: radius,
      );
      // 기준점은 성공했을 때만 옮긴다 — 실패한 자리에서 다시 시도할 수 있어야 한다.
      policy.markFetched(lat: lat, lng: lng, radiusMeters: radius);
      _setState(clearError: true);
      // 조회 도중 줌이 임계 아래로 내려갔을 수 있다. 그 경우 그리지 않는다.
      if (_visible) await _draw(footprints);
    } catch (e) {
      _setState(error: e);
      debugPrint('[FootprintMarker] 주변 발자취 로드 실패: $e');
    } finally {
      _setState(loading: false);
    }
  }

  /// 발자취를 새로 남긴 직후처럼, 움직이지 않았어도 다시 그려야 할 때 쓴다.
  Future<void> forceRefresh({
    required double lat,
    required double lng,
    required bool insideUnlockedSpot,
  }) {
    policy.reset();
    return refresh(lat: lat, lng: lng, insideUnlockedSpot: insideUnlockedSpot);
  }

  Future<void> _draw(List<Footprint> footprints) async {
    await _clear();
    final overlays = <NCircleOverlay>{};
    for (final footprint in footprints) {
      final lat = footprint.lat;
      final lng = footprint.lng;
      // 좌표 없는 예전 글은 지도에 자리가 없다 — 목록에서만 보인다.
      if (lat == null || lng == null) continue;
      final overlay = NCircleOverlay(
        id: 'footprint-${footprint.id}',
        center: NLatLng(lat, lng),
        radius: _dotRadiusMeters,
        color: _fillColor,
        outlineColor: _outlineColor,
        outlineWidth: 1,
      );
      final onTapped = onFootprintTapped;
      if (onTapped != null) {
        overlay.setOnTapListener((_) => onTapped(footprint));
      }
      overlays.add(overlay);
    }
    if (overlays.isNotEmpty) {
      await _mapController.addOverlayAll(overlays);
    }
  }

  Future<void> _clear() {
    return _mapController.clearOverlays(type: NOverlayType.circleOverlay);
  }

  void dispose() {
    _mapController.clearOverlays(type: NOverlayType.circleOverlay);
  }
}
