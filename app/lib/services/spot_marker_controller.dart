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
  SpotMarkerController(this._mapController, this._spotService, {this.onSpotsLoaded, this.onSpotTap});

  final NaverMapController _mapController;
  final SpotService _spotService;

  /// 스팟 목록을 새로 불러올 때마다 호출된다. geofencing(#45)이 별도 API 호출 없이
  /// 이 목록을 후보로 재사용할 수 있도록 노출하는 용도.
  final void Function(List<Spot> spots)? onSpotsLoaded;

  /// 마커를 탭했을 때 호출된다(#70) — 스팟 상세 진입점.
  final void Function(Spot spot)? onSpotTap;

  static const _radiusMeters = 5000.0;

  /// 해금 전 스팟 마커에 입히는 톤. 이름/캡션 없이 "여기 무언가 있다" 정도만 알려준다.
  static const _hiddenTint = Color(0xFF3A4454);

  bool _loading = false;

  /// 마커 id(`spot-{id}`) → 스팟. 탭 리스너가 [NMarker]만 받으므로, id로 원본 스팟을
  /// 다시 찾기 위해 마지막으로 불러온 목록을 들고 있는다.
  final Map<String, Spot> _spotsByMarkerId = {};

  /// [center] 주변 스팟을 다시 불러와 마커를 교체한다.
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
      _spotsByMarkerId
        ..clear()
        ..addEntries(spots.map((spot) => MapEntry('spot-${spot.id}', spot)));
      final markers = spots.map(_toMarker).toSet();
      await _mapController.clearOverlays(type: NOverlayType.marker);
      if (markers.isNotEmpty) {
        await _mapController.addOverlayAll(markers);
      }
    } catch (e) {
      debugPrint('[SpotMarker] 스팟 로드 실패: $e');
    } finally {
      _loading = false;
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
    marker.setOnTapListener((overlay) {
      final tapped = _spotsByMarkerId[overlay.info.id];
      if (tapped != null) onSpotTap?.call(tapped);
    });
    return marker;
  }

  void dispose() {
    _mapController.clearOverlays(type: NOverlayType.marker);
  }
}
