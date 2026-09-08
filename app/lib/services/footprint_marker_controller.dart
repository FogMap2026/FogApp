import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';

import '../models/footprint.dart';
import 'footprint_service.dart';

/// 지도 위에 발자취를 작은 마름모로 그린다(#117).
///
/// 스팟은 기본 핀 마커([SpotMarkerController])라 형태가 확실히 구분된다 —
/// 발자취는 스팟보다 훨씬 많아질 것이라(docs/footprint-redesign.md 4-1) 겹쳐 보여도
/// 스팟이 묻히지 않아야 한다.
///
/// **크기는 화면 기준(dp)이다.** 미터 단위 오버레이(`NCircleOverlay`)로 그리면 줌아웃할수록
/// 화면에서 작아져, 임계 줌 근처에서는 지름이 몇 dp밖에 안 돼 보이지도 탭되지도 않는다
/// (PR #130 리뷰). 아이콘을 dp로 고정하면 어느 줌에서 보이든 항상 같은 크기로 탭할 수 있고,
/// 줌 임계값은 "얼마나 촘촘하게 뜨는가"만 정하는 값이 된다.
///
/// 조회 반경은 이동 중 50m, 해금된 스팟의 안개 걷힘 반경(150m — fog_overlay_controller.dart의
/// `radiusMeters`와 같은 값) 안에서는 150m로 넓어진다(문서 3-2·3-3) — 호출부가
/// [updatePosition]의 `insideUnlockedSpot`으로 알려준다.
///
/// 위치가 갱신될 때마다 다시 조회하면 걷는 내내 요청이 쏟아지므로([SpotGeofenceController]와
/// 달리 이 컨트롤러는 실제 네트워크 호출을 한다), 일정 거리 이상 움직였을 때만(또는 반경
/// 모드가 바뀌었을 때만) 다시 불러온다.
class FootprintMarkerController {
  FootprintMarkerController(
    this._mapController,
    this._footprintService, {
    required NOverlayImage icon,
    this.onTapped,
  }) : _icon = icon;

  final NaverMapController _mapController;
  final FootprintService _footprintService;
  final NOverlayImage _icon;

  /// 도형을 탭했을 때 호출된다 — 글귀 팝업 진입점.
  final void Function(Footprint footprint)? onTapped;

  /// 이동 중 조회 반경(문서 3-2).
  static const _nearbyRadiusMeters = 50.0;

  /// 해금된 스팟 안에서의 조회 반경 — 안개 걷힘 반경과 같은 값이어야 한다(문서 3-3).
  static const _insideSpotRadiusMeters = 150.0;

  /// 위치가 이만큼 이상 움직여야 다시 조회한다.
  static const _minMoveMeters = 15.0;

  /// 이 줌보다 낮으면(멀리서 보면) 숨긴다. 아이콘이 dp 고정이라 이제 크기 문제가 아니라
  /// **밀도 문제**만 남는다 — 위도 37.5에서 줌 17이면 조회 반경 50m가 화면에서 지름
  /// 200px쯤 되어 도형 몇 개가 서로 떨어져 보이고, 한 단계만 낮아져도 절반으로 뭉친다.
  /// 실제 밀도를 보고 조정할 튜닝값이다(문서 4-1).
  static const _minVisibleZoom = 17.0;

  /// 아이콘 크기(dp). 마름모 자체는 이보다 작게 그리고 남는 여백은 투명하게 둔다 —
  /// 보이기는 작게, 탭 영역은 손가락에 맞게 확보하기 위함이다(PR #130 리뷰).
  static const iconSize = Size(36, 36);

  /// 발자취 도형 아이콘을 만든다. 여러 마커가 같은 이미지를 공유하도록 한 번만 만들어
  /// 재사용한다(`NOverlayImage` 문서 권장).
  static Future<NOverlayImage> createIcon(BuildContext context) {
    return NOverlayImage.fromWidget(
      context: context,
      size: iconSize,
      widget: const _FootprintDiamond(),
    );
  }

  final Map<int, NMarker> _markersByFootprintId = {};

  /// 지금 지도에 떠 있는 발자취 원본. 탭 팝업이 최신 좋아요 수를 쓰도록, 마커가 만들어질
  /// 때의 값을 클로저에 가두지 않고 여기서 찾아 쓴다.
  final Map<int, Footprint> _footprintsById = {};

  bool _visible = true;
  bool _loading = false;

  double? _lastFetchLat;
  double? _lastFetchLng;
  double? _lastFetchRadius;

  /// 카메라 줌이 바뀔 때마다 호출한다. 다시 조회하지 않고 보이기/숨기기만 전환한다 —
  /// 줌은 서버에 새로 물을 이유가 없는, 순수한 표시 여부 문제다.
  void setZoom(double zoom) {
    final visible = zoom >= _minVisibleZoom;
    if (visible == _visible) return;
    _visible = visible;
    for (final marker in _markersByFootprintId.values) {
      marker.setIsVisible(visible);
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
      // 실패한 자리를 "조회한 자리"로 남겨두면 15m를 더 걸어야 다시 시도하게 된다 —
      // 서버가 잠깐 끊기면 그동안 발자취가 통째로 안 보인다(PR #130 리뷰). 되돌려서
      // 다음 위치 갱신이 곧바로 다시 시도하게 한다.
      _lastFetchLat = null;
      _lastFetchLng = null;
      _lastFetchRadius = null;
      debugPrint('[FootprintMarker] 발자취 로드 실패: $e');
    } finally {
      _loading = false;
    }
  }

  Future<void> _render(List<Footprint> footprints) async {
    final next = <int, Footprint>{
      for (final footprint in footprints)
        // 좌표 없는 예전 글은 지도에 띄우지 않는다 — 모델 문서 참고.
        if (footprint.lat != null && footprint.lng != null) footprint.id: footprint,
    };

    _footprintsById
      ..clear()
      ..addAll(next);

    // 스팟 마커와 같은 marker 레이어를 쓰므로 `clearOverlays(type: marker)`로 지울 수 없다
    // (스팟까지 함께 지워진다). 사라진 것만 골라 지운다.
    for (final id in _markersByFootprintId.keys.toList()) {
      if (next.containsKey(id)) continue;
      final marker = _markersByFootprintId.remove(id);
      if (marker != null) await _mapController.deleteOverlay(marker.info);
    }

    // 같은 자리에 여러 개가 겹칠 때 묶어 보여줄지는 아직 정해지지 않았다(이슈 #117
    // "정해야 할 것") — 지금은 각각 따로 그린다.
    final added = <NMarker>{};
    for (final entry in next.entries) {
      if (_markersByFootprintId.containsKey(entry.key)) continue;
      final marker = _toMarker(entry.value);
      _markersByFootprintId[entry.key] = marker;
      added.add(marker);
    }

    if (added.isEmpty) return;
    await _mapController.addOverlayAll(added);
    // 숨김 상태는 지도에 올라간 뒤에 적용한다 — 추가 전에 걸면 SDK가 반영하지 못할 수 있다.
    if (!_visible) {
      for (final marker in added) {
        marker.setIsVisible(false);
      }
    }
  }

  NMarker _toMarker(Footprint footprint) {
    final marker = NMarker(
      id: 'footprint-${footprint.id}',
      position: NLatLng(footprint.lat!, footprint.lng!),
      icon: _icon,
      size: iconSize,
      // 핀이 아니라 대칭 도형이므로 좌표에 정중앙을 맞춘다(기본값은 핀 끝 기준).
      anchor: const NPoint(0.5, 0.5),
    );
    final onTap = onTapped;
    if (onTap != null) {
      marker.setOnTapListener((_) {
        final latest = _footprintsById[footprint.id];
        if (latest != null) onTap(latest);
      });
    }
    return marker;
  }

  void dispose() {
    for (final marker in _markersByFootprintId.values) {
      _mapController.deleteOverlay(marker.info);
    }
    _markersByFootprintId.clear();
    _footprintsById.clear();
  }
}

/// 발자취 도형. 스팟의 핀과 형태가 겹치지 않도록 마름모로 그리고, 안개 낀 지도 위에서
/// 눈에 띄도록 따뜻한 톤에 흰 테두리를 둘렀다.
///
/// 바깥 여백은 투명하게 남는다 — 도형은 작게 보이되 탭 영역은 [FootprintMarkerController.iconSize]
/// 전체가 된다.
class _FootprintDiamond extends StatelessWidget {
  const _FootprintDiamond();

  static const _color = Color(0xFFF2B84B);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.rotate(
        angle: pi / 4,
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: _color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1)),
            ],
          ),
        ),
      ),
    );
  }
}
