import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../models/spot.dart';
import '../theme/app_theme.dart';
import 'spot_service.dart';

/// 안개 아래 숨겨진 탐험 포인트(스팟)를 지도에 마커로 배치한다(#28).
///
/// 해금 전 스팟은 이름·주소 등 정보를 노출하지 않고, 캡션 없는 어두운 톤 마커로만
/// 표시한다. 방문 인증 후 실제 정보를 드러내는 처리는 Phase 3(안개 걷힘)에서 붙는다.
///
/// 어디를 중심으로 불러올지는 호출부([loadAround])가 정한다 — 기본은 «내 위치»이고,
/// 지도 컨트롤의 📍 버튼이 «화면 중심»으로 바꾼다(`map_screen.dart`). 예전에는
/// 카메라가 멈출 때마다 그 중심으로 불러왔는데, 그러면 지도를 밀 때마다 요청이 나가고
/// 내 주변 스팟이 화면에서 사라졌다.
///
/// 스팟이 밀집한 지역에서는 마커가 겹친다 — 줌을 빼면 마커를 함께 줄여([setZoom])
/// 덜 겹치게 한다. 클러스터링까지는 안 한다.
class SpotMarkerController {
  SpotMarkerController(
    this._mapController,
    this._spotService, {
    this.onSpotsLoaded,
    this.onLoadFailed,
    this.onSpotTapped,
  });

  final NaverMapController _mapController;
  final SpotService _spotService;

  /// 스팟 목록을 새로 불러올 때마다 호출된다. geofencing(#45)이 별도 API 호출 없이
  /// 이 목록을 후보로 재사용할 수 있도록 노출하는 용도.
  final void Function(List<Spot> spots)? onSpotsLoaded;

  /// 스팟 조회가 실패했을 때 호출된다(#146).
  ///
  /// 실패를 삼켜 지도를 계속 쓸 수 있게 하는 것은 그대로 두되, **화면이 그 사실을
  /// 알 수는 있어야 한다.** 이게 없으면 서버가 죽었을 때 [onSpotsLoaded]가 영영
  /// 불리지 않아, 화면은 "아직 로딩 중"과 "서버가 죽음"을 구분하지 못한다.
  final void Function(Object error)? onLoadFailed;

  /// 마커를 탭했을 때 호출된다(#70 발자취 작성 진입점).
  final void Function(Spot spot)? onSpotTapped;

  /// 조회 반경 기본값. 내 위치 기준 3km — 걸어서 갈 만한 거리이고, 서버 기본값
  /// (`SpotController` 의 `radius` 기본 3000)과도 같다.
  static const radiusMeters = 3000.0;

  /// 네이버 기본 마커 아이콘 크기(dp) — 줄일 때의 기준. Galaxy S25(480dpi) 캡처에서
  /// 114×149px 로 실측한 값이다. 배율 1.0 에서는 이 값을 쓰지 않고 [NMarker.autoSize]
  /// 로 둔다 — 그래야 줌 15 이상에서 예전과 픽셀 단위로 같다.
  static const _baseSize = Size(38, 50);

  /// 줌 → 마커 배율. 줌 15(내 위치 줌) 이상은 원래 크기, 10 이하는 50% — 그보다
  /// 작으면 손가락으로 못 누른다. 사이 값은 선형 보간.
  ///
  /// 처음엔 15→12 에서 90·70·50 으로 떨어뜨렸는데 «조금만 빼도 확 작아진다»
  /// (시진, 실기기 09-14). 10 까지 늘이고 양 끝(100·50)은 두되 중간을 조금 더
  /// 낮췄다 — 14 는 아직 동네, 13 은 구, 12 는 시 단위라 12 까지는 마커가 제법 커야
  /// 어디 몰려 있는지 읽히면서도, 밀집 지역에서 서로 덮지는 않는 선이다.
  static const _scaleByZoom = <(double zoom, double scale)>[
    (15, 1.0),
    (14, 0.88),
    (13, 0.76),
    (12, 0.65),
    (11, 0.56),
    (10, 0.5),
  ];

  /// 지금 마커에 적용된 배율. 0.02 단위로 끊어 핀치 줌 중에 매 프레임 갱신하지 않는다.
  double _scale = 1.0;

  /// 해금 전 스팟 마커에 입히는 톤. 이름/캡션 없이 "여기 무언가 있다" 정도만 알려준다.
  static const _hiddenTint = Color(0xFF3A4454);

  /// 찜한 스팟 마커의 톤 — 기본 마커와 한눈에 갈리는 주황. 잠김 여부와 무관하게 이 색이다:
  /// 「가 볼 곳」이라는 표시가 「밝혔나」보다 먼저 읽혀야 한다.
  static const _favoriteTint = AppColors.accentOrange;

  /// 찜한 스팟(`FavoriteSpots`). 조회 결과와 무관하게 **항상** 지도에 둔다 — 내 위치
  /// 3km 밖이어도, 📍 로 다른 곳을 보고 있어도. 마지막 조회 결과([_loaded])와 합쳐 그린다.
  final Map<int, Spot> _favorites = {};

  /// 마지막 조회 결과. 찜이 바뀌었을 때 다시 조회하지 않고 이것과 합쳐 다시 그린다.
  List<Spot> _loaded = const [];

  bool _loading = false;

  /// 지금 지도에 떠 있는 스팟 마커와, 그릴 때 쓴 해금 여부.
  ///
  /// 예전에는 불러올 때마다 `clearOverlays(type: marker)`로 전부 지우고 다시 그렸지만,
  /// 발자취도 같은 marker 레이어를 쓰게 되면서(#117) 그러면 **발자취 마커까지 함께
  /// 지워진다.** 이제 사라진 스팟만 골라 지운다 — 화면을 조금 움직였을 때 대부분의
  /// 마커가 그대로 남으므로 다시 그리는 비용도 줄어든다.
  final Map<int, NMarker> _markersBySpotId = {};

  /// 마커를 그릴 때 쓴 모양 키(`잠김·찜`). 어느 쪽이든 바뀌면 다시 그린다.
  final Map<int, String> _styleBySpotId = {};

  /// 조회 중에 새 요청이 오면 여기 둔다 — 버리지 않고 끝난 뒤 «마지막 것»만 실행한다.
  ///
  /// 지도가 준비되며 임시로 한 번 부르고, 곧바로 첫 측위가 내 위치로 다시 부른다.
  /// 앞 요청이 아직 서버를 기다리는 중이면 뒤 요청이 겹치는데, 그걸 버리면 **내 주변
  /// 스팟이 영영 안 뜬다** — 호출부는 「이미 불러왔다」고 믿고 300m 걸을 때까지 다시
  /// 부르지 않기 때문이다. 카메라가 멈출 때마다 부르던 시절엔 하나쯤 버려도 다음
  /// 호출이 메웠지만, 이제는 그 다음 호출이 없다.
  ({NLatLng center, double radius})? _pending;

  /// [center] 주변 [radius] 안 스팟을 다시 불러와 마커를 갱신한다.
  Future<void> loadAround(NLatLng center, {double radius = radiusMeters}) async {
    if (_loading) {
      _pending = (center: center, radius: radius);
      return;
    }
    _loading = true;
    try {
      final spots = await _spotService.fetchNearby(
        lat: center.latitude,
        lng: center.longitude,
        radiusMeters: radius,
      );
      onSpotsLoaded?.call(spots);
      _loaded = spots;
      await _syncMarkers();
    } catch (e) {
      // 실패를 삼켜 지도 자체는 계속 쓸 수 있게 두되(#117·#130과 같은 원칙),
      // 화면에는 알린다 — 아무에게도 안 알리는 것이 #146이었다.
      debugPrint('[SpotMarker] 스팟 로드 실패: $e');
      onLoadFailed?.call(e);
    } finally {
      _loading = false;
    }
    final pending = _pending;
    if (pending != null) {
      _pending = null;
      await loadAround(pending.center, radius: pending.radius);
    }
  }

  /// 찜 목록이 바뀌었다. 조회 없이 마지막 결과와 합쳐 다시 그린다.
  Future<void> setFavorites(List<Spot> favorites) async {
    _favorites
      ..clear()
      ..addEntries(favorites.map((s) => MapEntry(s.id, s)));
    await _syncMarkers();
  }

  /// 반경을 벗어난 스팟의 마커는 지우고, 새로 들어온 스팟만 그린다. 찜한 스팟은 조회
  /// 결과에 없어도 남긴다. 모양(잠김·찜)이 바뀐 스팟은 톤이 달라져야 하므로 다시 그린다.
  ///
  /// 같은 스팟이 조회 결과와 찜 양쪽에 있으면 **조회 결과가 앞선다** — 서버가 준 최신
  /// 잠김 여부를 쓴다. 찜 저장본은 찜한 시점의 것이다.
  Future<void> _syncMarkers() async {
    final next = <int, Spot>{..._favorites, for (final spot in _loaded) spot.id: spot};
    String styleOf(Spot spot) => '${spot.unlocked}-${_favorites.containsKey(spot.id)}';

    for (final id in _markersBySpotId.keys.toList()) {
      final spot = next[id];
      if (spot != null && styleOf(spot) == _styleBySpotId[id]) continue;
      final marker = _markersBySpotId.remove(id);
      _styleBySpotId.remove(id);
      if (marker != null) await _mapController.deleteOverlay(marker.info);
    }

    // 좌표가 완전히 같은 스팟(같은 장소의 행사·시설이 따로 등록된 것 — 전국 247쌍)은 마커가
    // 포개져 하나만 보이고, 어느 쪽을 눌러도 위에 있는 것만 열린다. 조금씩 벌려 둘 다 보이게.
    final positions = spreadOverlapping(next.values);
    for (final entry in _markersBySpotId.entries) {
      final position = positions[entry.key];
      if (position != null && position != entry.value.position) entry.value.setPosition(position);
    }

    final added = <NMarker>{};
    for (final entry in next.entries) {
      if (_markersBySpotId.containsKey(entry.key)) continue;
      final marker = _toMarker(
        entry.value,
        favorite: _favorites.containsKey(entry.key),
        position: positions[entry.key] ?? NLatLng(entry.value.lat, entry.value.lng),
      );
      _markersBySpotId[entry.key] = marker;
      _styleBySpotId[entry.key] = styleOf(entry.value);
      added.add(marker);
    }
    if (added.isNotEmpty) {
      await _mapController.addOverlayAll(added);
    }
  }

  /// 줌에 맞춰 마커 크기를 바꾼다. 줌을 빼면 같은 화면에 스팟이 많아져 겹치는데,
  /// 마커를 함께 줄이면 «어디에 몰려 있는지»는 보이면서 서로 덮지는 않는다.
  ///
  /// 카메라가 멈추기 전(핀치 중)에도 부르지만 배율이 0.05 이상 바뀔 때만 실제로
  /// 마커를 건드린다 — 마커 수십 개에 매 프레임 `setSize` 를 보내지 않기 위해서다.
  void setZoom(double zoom) {
    // 0.02 단위로 끊는다. ⚠️ 배율 전체를 50배 해서 반올림할 것 — 배율이 0 이 되면
    // SDK 는 「기본 크기」(NMarker.autoSize) 로 읽어 안 줄어든 것처럼 보인다.
    final scale = (scaleForZoom(zoom) * 50).round() / 50;
    if (scale == _scale) return;
    _scale = scale;
    for (final marker in _markersBySpotId.values) {
      marker.setSize(_sizeForScale());
    }
  }

  /// [_scaleByZoom] 을 선형 보간한다. 표 밖(15 초과 / 12 미만)은 양 끝 값.
  ///
  /// 순수 함수로 두어 지도 없이 검증한다(`spot_marker_scale_test.dart`).
  static double scaleForZoom(double zoom) {
    const table = _scaleByZoom;
    if (zoom >= table.first.$1) return table.first.$2;
    if (zoom <= table.last.$1) return table.last.$2;
    for (var i = 0; i < table.length - 1; i++) {
      final (hi, hiScale) = table[i];
      final (lo, loScale) = table[i + 1];
      if (zoom <= hi && zoom >= lo) {
        return loScale + (hiScale - loScale) * (zoom - lo) / (hi - lo);
      }
    }
    return table.last.$2;
  }

  Size _sizeForScale() => sizeForScale(_scale);

  /// 배율 → 마커 크기. 발자취 마커([FootprintMarkerController])도 같은 표를 써서 함께 줄어든다.
  static Size sizeForScale(double scale) =>
      scale >= 1.0 ? NMarker.autoSize : Size(_baseSize.width * scale, _baseSize.height * scale);

  /// 좌표가 같은 스팟끼리 벌린 자리. [spreadMeters] 반지름 원 위에 id 순으로 고르게 놓는다 —
  /// 같은 무리면 조회 순서와 무관하게 늘 같은 자리다. 혼자인 스팟은 목록에 없다.
  ///
  /// 순수 함수라 지도 없이 검증한다(`spot_marker_spread_test.dart`).
  static Map<int, NLatLng> spreadOverlapping(Iterable<Spot> spots, {double spreadMeters = 6}) {
    final groups = <String, List<Spot>>{};
    for (final spot in spots) {
      groups.putIfAbsent('${spot.lat.toStringAsFixed(6)},${spot.lng.toStringAsFixed(6)}', () => []).add(spot);
    }
    final out = <int, NLatLng>{};
    for (final group in groups.values) {
      if (group.length < 2) continue;
      group.sort((a, b) => a.id.compareTo(b.id));
      final mPerLng = 111320 * cos(group.first.lat * pi / 180);
      for (var i = 0; i < group.length; i++) {
        final angle = -pi / 2 + 2 * pi * i / group.length; // 첫 스팟은 위쪽부터
        final spot = group[i];
        out[spot.id] = NLatLng(
          spot.lat + spreadMeters * sin(angle) / 111320,
          spot.lng + spreadMeters * cos(angle) / mPerLng,
        );
      }
    }
    return out;
  }

  /// 마커 전부를 감추거나 보인다 — 「스팟 숨기기」 토글. 조회·동기화는 그대로 돌고 그리기만
  /// 끈다: 새로 만드는 마커도 이 값을 따른다([_toMarker]).
  void setVisible(bool visible) {
    if (_visible == visible) return;
    _visible = visible;
    for (final marker in _markersBySpotId.values) {
      marker.setIsVisible(visible);
    }
  }

  bool _visible = true;

  NMarker _toMarker(Spot spot, {required bool favorite, required NLatLng position}) {
    final marker = NMarker(
      id: 'spot-${spot.id}',
      position: position,
      size: _sizeForScale(),
      // 찜이 먼저, 그다음 잠김. unlocked 스팟은 Phase 3에서 실제 정보를 담은 마커로
      // 대체될 예정이라 지금은 숨김 톤으로 그린다 (서버도 현재 unlocked=false만 내려준다).
      iconTintColor: favorite
          ? _favoriteTint
          : spot.unlocked
              ? Colors.transparent
              : _hiddenTint,
    );
    final onTapped = onSpotTapped;
    if (onTapped != null) {
      marker.setOnTapListener((_) => onTapped(spot));
    }
    if (!_visible) marker.setIsVisible(false);
    return marker;
  }

  void dispose() {
    // 발자취 마커(#117)도 같은 레이어에 있으므로 타입 단위로 지우지 않는다.
    for (final marker in _markersBySpotId.values) {
      _mapController.deleteOverlay(marker.info);
    }
    _markersBySpotId.clear();
    _styleBySpotId.clear();
  }
}
