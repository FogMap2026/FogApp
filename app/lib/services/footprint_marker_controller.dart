import 'package:flutter/material.dart' show Color, Colors, debugPrint;
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';

import '../models/footprint.dart';
import 'footprint_service.dart';

/// 지도 위에 발자취를 작은 도형(원)으로 그린다(#117).
///
/// [SpotMarkerController]의 마커(핀 모양)와 형태가 확실히 달라야 하므로 원(circle)
/// 오버레이를 쓴다 — 발자취는 스팟보다 훨씬 많아질 것이라(docs/footprint-redesign.md 4-1)
/// 겹쳐 보여도 스팟 마커가 묻히지 않도록 형태로 구분한다.
///
/// 조회 반경은 이동 중 50m, 해금된 스팟의 안개 걷힘 반경(150m — fog_overlay_controller.dart의
/// `radiusMeters`와 같은 값) 안에서는 150m로 넓어진다(문서 3-2·3-3) — 호출부가
/// [updatePosition]의 `insideUnlockedSpot`으로 알려준다.
///
/// 좌표가 이동할 때마다 다시 조회하면 걷는 내내 요청이 쏟아지므로([SpotGeofenceController]와
/// 달리 이 컨트롤러는 실제 네트워크 호출을 하기 때문에 스로틀이 필요하다), 일정 거리
/// 이상 움직였을 때만(또는 반경 모드가 바뀌었을 때만) 실제로 다시 불러온다.
class FootprintMarkerController {
  FootprintMarkerController(this._mapController, this._footprintService, {this.onTapped});

  final NaverMapController _mapController;
  final FootprintService _footprintService;

  /// 도형을 탭했을 때 호출된다 — 글귀 팝업 진입점.
  final void Function(Footprint footprint)? onTapped;

  /// 이동 중 조회 반경(문서 3-2).
  static const _nearbyRadiusMeters = 50.0;

  /// 해금된 스팟 안에서의 조회 반경 — 안개 걷힘 반경과 같은 값이어야 한다(문서 3-3).
  static const _insideSpotRadiusMeters = 150.0;

  /// 위치가 이만큼 이상 움직여야 다시 조회한다.
  static const _minMoveMeters = 15.0;

  /// 이 줌보다 낮으면(멀리서 보면) 숨긴다. "확대하면 보인다"가 규칙이고 숫자는
  /// 실제 밀도를 보고 조정할 튜닝값이다(문서 4-1, 이슈 #117 열어둔 결정).
  static const _minVisibleZoom = 15.0;

  /// 발자취 도형 반경(미터) — 걸어서 지나가며 보는 눈높이에서 "점"처럼 보이는 정도.
  static const _dotRadiusMeters = 6.0;

  /// 스팟의 숨김 톤([SpotMarkerController._hiddenTint], 짙은 청회색)과 뚜렷이 다른
  /// 따뜻한 톤 — 안개 낀 지도 위에서 "발견"으로 눈에 띄도록 한다.
  static const _dotColor = Color(0xFFF2B84B);
  static const _dotOutlineColor = Colors.white;

  Map<int, NCircleOverlay> _overlaysByFootprintId = {};
  bool _visible = true;
  bool _loading = false;

  double? _lastFetchLat;
  double? _lastFetchLng;
  double? _lastFetchRadius;

  /// 카메라 줌이 바뀔 때마다 호출한다. 다시 조회하지 않고 보이기/숨기기만 전환한다 —
  /// 줌 자체는 서버에 새로 물을 이유가 없는, 순수한 표시 여부 문제다.
  void setZoom(double zoom) {
    final visible = zoom >= _minVisibleZoom;
    if (visible == _visible) return;
    _visible = visible;
    for (final overlay in _overlaysByFootprintId.values) {
      overlay.setIsVisible(visible);
    }
  }

  /// 새 위치를 반영한다. 일정 거리 이상 움직였거나 조회 반경 모드가 바뀌었을 때만
  /// (예: 해금된 스팟 반경 진입/이탈) 실제로 서버에 다시 묻는다.
  Future<void> updatePosition({
    required double lat,
    required double lng,
    required bool insideUnlockedSpot,
  }) async {
    final radius = insideUnlockedSpot ? _insideSpotRadiusMeters : _nearbyRadiusMeters;

    final lastLat = _lastFetchLat;
    final lastLng = _lastFetchLng;
    final radiusChanged = radius != _lastFetchRadius;
    if (!radiusChanged && lastLat != null && lastLng != null) {
      final moved = Geolocator.distanceBetween(lastLat, lastLng, lat, lng);
      if (moved < _minMoveMeters) return;
    }

    if (_loading) return;
    _loading = true;
    _lastFetchLat = lat;
    _lastFetchLng = lng;
    _lastFetchRadius = radius;
    try {
      final footprints = await _footprintService.fetchNearby(lat: lat, lng: lng, radiusMeters: radius);
      await _render(footprints);
    } catch (e) {
      // 발자취는 지도 위 보조 표시라 실패해도 지도 자체는 계속 동작해야 한다
      // (SpotMarkerController와 같은 원칙) — 다음 위치 갱신에서 다시 시도된다.
      debugPrint('[FootprintMarker] 발자취 로드 실패: $e');
    } finally {
      _loading = false;
    }
  }

  Future<void> _render(List<Footprint> footprints) async {
    final overlays = <NCircleOverlay>{};
    final byId = <int, NCircleOverlay>{};
    for (final footprint in footprints) {
      final lat = footprint.lat;
      final lng = footprint.lng;
      if (lat == null || lng == null) continue; // 좌표 없는 예전 글 — 모델 문서 참고.

      final overlay = NCircleOverlay(
        id: 'footprint-${footprint.id}',
        center: NLatLng(lat, lng),
        radius: _dotRadiusMeters,
        color: _dotColor,
        outlineColor: _dotOutlineColor,
        outlineWidth: 2,
      );
      overlay.setIsVisible(_visible);
      final onTap = onTapped;
      if (onTap != null) {
        overlay.setOnTapListener((_) => onTap(footprint));
      }
      overlays.add(overlay);
      byId[footprint.id] = overlay;
    }

    // 같은 자리에 여러 개가 겹칠 때 묶어 보여줄지는 아직 정해지지 않았다(이슈 #117
    // "정해야 할 것") — 지금은 각각 따로 그린다.

    await _mapController.clearOverlays(type: NOverlayType.circleOverlay);
    if (overlays.isNotEmpty) {
      await _mapController.addOverlayAll(overlays);
    }
    _overlaysByFootprintId = byId;
  }

  void dispose() {
    _mapController.clearOverlays(type: NOverlayType.circleOverlay);
    _overlaysByFootprintId.clear();
  }
}
