import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';

import '../models/footprint.dart';
import 'footprint_service.dart';
import 'spot_marker_controller.dart';

/// 지도 위에 발자취를 스팟과 같은 크기의 **발바닥 핀**으로 그린다(#117).
///
/// 처음엔 작은 마름모(16dp)였는데 실기기에서 «너무 작아서 있는 줄 모른다»(시진, 09-15). 스팟 핀과
/// 같은 크기(38×50dp)의 보라 핀에 흰 발바닥을 넣어, 멀리서는 스팟처럼 눈에 띄고 가까이서는
/// 모양으로 갈린다. 줌을 빼면 스팟과 같은 표([SpotMarkerController.scaleForZoom])로 함께 줄어든다.
///
/// 조회 반경은 **내 위치 1km** 고정이다(서버 상한 `FootprintService.MAX_RADIUS_METERS`). 예전엔
/// 이동 중 50m·해금 스팟 안 150m 였는데, 그러면 바로 옆 골목 글도 안 보여 발자취가 있는지
/// 없는지 알 수 없었다. 1km 면 걸어서 갈 만한 범위의 글이 다 보이고, 서버가 최대 200건으로
/// 끊어 준다.
///
/// 위치가 갱신될 때마다 다시 조회하면 걷는 내내 요청이 쏟아지므로 [_minMoveMeters] 이상 움직였을
/// 때만 다시 불러온다. 보이기는 사용자 토글([setUserVisible], 우측 컨트롤 다섯째 버튼)이 정한다.
/// **숨겨진 동안은 조회하지 않고**, 다시 보이게 되는 순간 마지막 위치로 한 번 채운다.
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

  /// 핀 크기(dp) — 스팟 기본 핀과 같다([SpotMarkerController] 실측 38×50).
  static const iconSize = Size(38, 50);

  /// 발바닥 핀 아이콘. 여러 마커가 같은 이미지를 공유하도록 한 번만 만들어 재사용한다.
  static Future<NOverlayImage> createIcon(BuildContext context) {
    return NOverlayImage.fromWidget(context: context, size: iconSize, widget: const _FootprintPin());
  }

  /// 핀을 탭했을 때 호출된다 — 글귀 팝업 진입점.
  final void Function(Footprint footprint)? onTapped;

  /// 조회 반경 — 서버 상한과 같다.
  static const radiusMeters = 1000.0;

  /// 위치가 이만큼 이상 움직여야 다시 조회한다. 반경 1km 에 200m 면 화면 밖으로 밀려나는
  /// 글이 생기기 전에 갱신되면서도, 걷는 동안 요청이 15m 마다 나가진 않는다.
  static const _minMoveMeters = 200.0;

  /// 발자취 핀 색 — 스팟의 초록(밝힘)·민트(잠김)·주황(찜) 어느 것과도 겹치지 않는 보라.
  static const tint = Color(0xFF8E6CF0);

  final Map<int, NMarker> _markersByFootprintId = {};

  /// 지금 지도에 떠 있는 발자취 원본. 탭 팝업이 최신 좋아요 수를 쓰도록, 마커가 만들어질
  /// 때의 값을 클로저에 가두지 않고 여기서 찾아 쓴다.
  final Map<int, Footprint> _footprintsById = {};

  bool _visible = true;
  double _scale = 1.0;
  bool _loading = false;

  double? _lastFetchLat;
  double? _lastFetchLng;

  /// 마지막으로 받은 위치. 숨겨진 동안에도 계속 기록해두었다가, 다시 보이게 될 때
  /// 이 자리로 한 번 조회한다 — 새 위치 이벤트를 기다리면 제자리에 서 있는 동안
  /// 빈 지도가 된다(위치 스트림이 `distanceFilter: 15`라 움직이지 않으면 오지 않는다).
  double? _lastKnownLat;
  double? _lastKnownLng;

  /// 카메라 줌이 바뀔 때마다 호출한다. 크기를 스팟과 같은 배율로 맞춘다 — 줌으로 숨기지는
  /// 않는다(예전 마름모 때는 17 미만이면 숨겼는데, 핀은 스팟처럼 줄어들면 되고 1km 안 200개는
  /// 스팟과 같은 밀도다. 시진, 09-15).
  void setZoom(double zoom) {
    final scale = (SpotMarkerController.scaleForZoom(zoom) * 50).round() / 50;
    if (scale == _scale) return;
    _scale = scale;
    for (final marker in _markersByFootprintId.values) {
      marker.setSize(_sizeForScale());
    }
  }

  /// 우측 컨트롤 다섯째 버튼 — 발자취 보이기/숨기기. 다시 보이게 되면 마지막 위치로 한 번 채운다.
  void setUserVisible(bool visible) {
    if (_visible == visible) return;
    _visible = visible;
    for (final marker in _markersByFootprintId.values) {
      marker.setIsVisible(visible);
    }
    if (!visible) return;
    final lat = _lastKnownLat;
    final lng = _lastKnownLng;
    if (lat == null || lng == null) return;
    unawaited(_fetchAround(lat: lat, lng: lng));
  }

  /// 새 위치를 반영한다. **숨겨진 동안은 조회하지 않는다** — 받아온 발자취가 곧바로 숨겨져
  /// 요청만 나갔다(PR #130 리뷰). 다시 보이게 되는 순간은 [setUserVisible] 이 채운다.
  Future<void> updatePosition({required double lat, required double lng}) async {
    _lastKnownLat = lat;
    _lastKnownLng = lng;
    if (!_visible) return;
    await _fetchAround(lat: lat, lng: lng);
  }

  Future<void> _fetchAround({required double lat, required double lng}) async {
    final lastLat = _lastFetchLat;
    final lastLng = _lastFetchLng;
    if (lastLat != null && lastLng != null) {
      if (Geolocator.distanceBetween(lastLat, lastLng, lat, lng) < _minMoveMeters) return;
    }

    if (_loading) return;
    _loading = true;
    _lastFetchLat = lat;
    _lastFetchLng = lng;
    try {
      final footprints = await _footprintService.fetchNearby(lat: lat, lng: lng, radiusMeters: radiusMeters);
      await _render(footprints);
    } catch (e) {
      // 실패한 자리를 "조회한 자리"로 남겨두면 200m 를 더 걸어야 다시 시도하게 된다 —
      // 서버가 잠깐 끊기면 그동안 발자취가 통째로 안 보인다(PR #130 리뷰). 되돌려서
      // 다음 위치 갱신이 곧바로 다시 시도하게 한다.
      _lastFetchLat = null;
      _lastFetchLng = null;
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

  /// 배율 → 크기. 스팟은 1.0 에서 SDK 기본 크기(autoSize)를 쓰지만 우리 그림은 크기를 알고
  /// 있으니 늘 직접 준다.
  Size _sizeForScale() => Size(iconSize.width * _scale, iconSize.height * _scale);

  NMarker _toMarker(Footprint footprint) {
    final marker = NMarker(
      id: 'footprint-${footprint.id}',
      position: NLatLng(footprint.lat!, footprint.lng!),
      icon: _icon,
      size: _sizeForScale(),
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

/// 발바닥 핀 — 스팟 기본 핀과 같은 실루엣(둥근 머리 + 아래로 뾰족한 꼬리)에 보라를 칠하고 흰
/// 발바닥([Icons.pets])을 넣는다. 흰 테두리는 안개 위에서 윤곽을 살린다.
class _FootprintPin extends StatelessWidget {
  const _FootprintPin();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      size: FootprintMarkerController.iconSize,
      painter: _PinPainter(FootprintMarkerController.tint),
      child: Padding(
        padding: EdgeInsets.only(top: 6),
        child: Align(alignment: Alignment.topCenter, child: Icon(Icons.pets, color: Colors.white, size: 18)),
      ),
    );
  }
}

class _PinPainter extends CustomPainter {
  const _PinPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final r = w * 0.42; // 머리 반지름
    final cx = w / 2;
    final cy = r + 1.5; // 테두리 여유
    final tipY = size.height - 1.5;
    // 머리(원)와 꼬리(접점 두 개 + 끝점 삼각형)를 합집합으로 — 호 각도를 손으로 맞추다 반이
    // 잘린 모양이 나왔다(실기기, 09-15). 합집합이면 각도 계산이 필요 없다.
    final d = tipY - cy;
    final a = acos(r / d); // 중심에서 본 접점의 벌어진 각(아래 방향 기준)
    final head = Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    final tail = Path()
      ..moveTo(cx, tipY)
      ..lineTo(cx + r * sin(a), cy + r * cos(a))
      ..lineTo(cx, cy)
      ..lineTo(cx - r * sin(a), cy + r * cos(a))
      ..close();
    final path = Path.combine(PathOperation.union, head, tail);
    canvas.drawShadow(path, const Color(0x66000000), 2, false);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_PinPainter old) => old.color != color;
}
