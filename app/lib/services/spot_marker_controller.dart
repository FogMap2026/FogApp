import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../models/spot.dart';
import 'spot_service.dart';

/// 안개 아래 숨겨진 탐험 포인트(스팟)를 지도에 마커로 배치한다(#28).
///
/// 해금 전 스팟은 이름·주소 등 정보를 노출하지 않고, 캡션 없는 어두운 톤 마커로만
/// 표시한다. 방문 인증 후 실제 정보를 드러내는 처리는 Phase 3(안개 걷힘)에서 붙는다.
///
/// 지도 중심이 바뀔 때마다(카메라 idle) 다시 불러오는 단순한 뷰포트 로딩이다.
/// 스팟이 매우 밀집한 지역에서 마커 수가 많아지면 클러스터링이 필요할 수 있다 —
/// 지금은 반경([_radiusMeters])으로 요청량을 제한하는 선에서 대응한다.
class SpotMarkerController {
  SpotMarkerController(this._mapController, this._spotService, {this.onSpotsLoaded, this.onSpotTapped});

  final NaverMapController _mapController;
  final SpotService _spotService;

  /// 스팟 목록을 새로 불러올 때마다 호출된다. geofencing(#45)이 별도 API 호출 없이
  /// 이 목록을 후보로 재사용할 수 있도록 노출하는 용도.
  final void Function(List<Spot> spots)? onSpotsLoaded;

  /// 마커를 탭했을 때 호출된다(#70 발자취 작성 진입점).
  final void Function(Spot spot)? onSpotTapped;

  static const _radiusMeters = 5000.0;

  /// 해금 전 스팟 마커에 입히는 톤. 이름/캡션 없이 "여기 무언가 있다" 정도만 알려준다.
  static const _hiddenTint = Color(0xFF3A4454);

  bool _loading = false;

  /// 지금 지도에 떠 있는 스팟 마커와, 그릴 때 쓴 해금 여부.
  ///
  /// 예전에는 불러올 때마다 `clearOverlays(type: marker)`로 전부 지우고 다시 그렸지만,
  /// 발자취도 같은 marker 레이어를 쓰게 되면서(#117) 그러면 **발자취 마커까지 함께
  /// 지워진다.** 이제 사라진 스팟만 골라 지운다 — 화면을 조금 움직였을 때 대부분의
  /// 마커가 그대로 남으므로 다시 그리는 비용도 줄어든다.
  final Map<int, NMarker> _markersBySpotId = {};
  final Map<int, bool> _unlockedBySpotId = {};

  /// [center] 주변 스팟을 다시 불러와 마커를 갱신한다.
  Future<void> loadAround(NLatLng center) async {
    if (_loading) return;
    _loading = true;
    try {
      final spots = await _spotService.fetchNearby(
        lat: center.latitude,
        lng: center.longitude,
        radiusMeters: _radiusMeters,
      );
      onSpotsLoaded?.call(spots);
      await _syncMarkers(spots);
    } catch (e) {
      debugPrint('[SpotMarker] 스팟 로드 실패: $e');
    } finally {
      _loading = false;
    }
  }

  /// 반경을 벗어난 스팟의 마커는 지우고, 새로 들어온 스팟만 그린다.
  /// 해금 여부가 바뀐 스팟(방문 인증 직후)은 톤이 달라져야 하므로 다시 그린다.
  Future<void> _syncMarkers(List<Spot> spots) async {
    final next = {for (final spot in spots) spot.id: spot};

    for (final id in _markersBySpotId.keys.toList()) {
      final spot = next[id];
      if (spot != null && spot.unlocked == _unlockedBySpotId[id]) continue;
      final marker = _markersBySpotId.remove(id);
      _unlockedBySpotId.remove(id);
      if (marker != null) await _mapController.deleteOverlay(marker.info);
    }

    final added = <NMarker>{};
    for (final entry in next.entries) {
      if (_markersBySpotId.containsKey(entry.key)) continue;
      final marker = _toMarker(entry.value);
      _markersBySpotId[entry.key] = marker;
      _unlockedBySpotId[entry.key] = entry.value.unlocked;
      added.add(marker);
    }
    if (added.isNotEmpty) {
      await _mapController.addOverlayAll(added);
    }
  }

  NMarker _toMarker(Spot spot) {
    final marker = NMarker(
      id: 'spot-${spot.id}',
      position: NLatLng(spot.lat, spot.lng),
      // unlocked 스팟은 Phase 3에서 실제 정보를 담은 마커로 대체될 예정이라
      // 지금은 항상 숨김 톤으로 그린다 (서버도 현재 unlocked=false만 내려준다).
      iconTintColor: spot.unlocked ? Colors.transparent : _hiddenTint,
    );
    final onTapped = onSpotTapped;
    if (onTapped != null) {
      marker.setOnTapListener((_) => onTapped(spot));
    }
    return marker;
  }

  void dispose() {
    // 발자취 마커(#117)도 같은 레이어에 있으므로 타입 단위로 지우지 않는다.
    for (final marker in _markersBySpotId.values) {
      _mapController.deleteOverlay(marker.info);
    }
    _markersBySpotId.clear();
    _unlockedBySpotId.clear();
  }
}
