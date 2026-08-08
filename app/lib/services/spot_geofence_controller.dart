import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/spot.dart';

/// 스팟 반경 진입 이벤트. [SpotGeofenceController.onEnter]로 노출된다.
class GeofenceEnterEvent {
  const GeofenceEnterEvent({required this.spot, required this.distanceMeters});

  final Spot spot;
  final double distanceMeters;
}

/// 스팟 반경 geofencing (#45).
///
/// 현재 위치와 주변 스팟 후보 목록을 대조해 인증 가능 반경 진입/이탈을 판정한다.
/// 판정 결과는 [onEnter]/[onExit] 스트림으로 노출되어 화면(알림 #46, 안개 걷힘 #49)이
/// 구독할 수 있다.
///
/// 후보 스팟 목록은 별도로 다시 조회하지 않고 [updateCandidates]로 외부에서
/// 주입받는다 — 이미 [SpotMarkerController]가 카메라 idle마다 불러오는 목록을
/// 재사용해 불필요한 API 호출을 피한다.
class SpotGeofenceController {
  SpotGeofenceController({
    this.enterRadiusMeters = 100,
    this.exitRadiusMeters = 130,
  }) : assert(
          exitRadiusMeters >= enterRadiusMeters,
          'exitRadiusMeters는 히스테리시스를 위해 enterRadiusMeters 이상이어야 한다',
        );

  /// 인증 가능 반경(진입 판정 기준). 제안값 100m — 팀 합의 필요(#45 To-do).
  final double enterRadiusMeters;

  /// 이탈 판정 반경. [enterRadiusMeters]보다 크게 잡아, 경계에서 위치가 미세하게
  /// 흔들릴 때 진입/이탈이 반복 발생(flapping)하지 않도록 하는 히스테리시스 여유값이다.
  final double exitRadiusMeters;

  List<Spot> _candidates = const [];
  final Set<int> _insideSpotIds = {};

  final _enterController = StreamController<GeofenceEnterEvent>.broadcast();
  final _exitController = StreamController<Spot>.broadcast();

  /// 반경에 새로 진입한 스팟(진입한 스팟 + 거리). 알림(#46)이 구독해 안내를 띄운다.
  Stream<GeofenceEnterEvent> get onEnter => _enterController.stream;

  /// 반경에서 벗어난 스팟.
  Stream<Spot> get onExit => _exitController.stream;

  /// 현재 반경 안에 있는 스팟 id 목록.
  Set<int> get insideSpotIds => Set.unmodifiable(_insideSpotIds);

  /// 주변 스팟 후보 목록을 갱신한다. 후보에서 빠진 스팟은 이탈 이벤트 없이 조용히
  /// 추적을 멈춘다(뷰포트 밖으로 나간 것뿐, 실제로 반경을 벗어났다고 볼 수 없으므로).
  void updateCandidates(List<Spot> spots) {
    _candidates = spots;
    final stillCandidateIds = spots.map((s) => s.id).toSet();
    _insideSpotIds.removeWhere((id) => !stillCandidateIds.contains(id));
  }

  /// 새 위치를 반영해 후보 스팟들과의 거리를 재계산하고 진입/이탈을 판정한다.
  void updatePosition({required double lat, required double lng}) {
    for (final spot in _candidates) {
      final distance = Geolocator.distanceBetween(lat, lng, spot.lat, spot.lng);
      final wasInside = _insideSpotIds.contains(spot.id);

      if (!wasInside && distance <= enterRadiusMeters) {
        _insideSpotIds.add(spot.id);
        _enterController.add(GeofenceEnterEvent(spot: spot, distanceMeters: distance));
      } else if (wasInside && distance > exitRadiusMeters) {
        _insideSpotIds.remove(spot.id);
        _exitController.add(spot);
      }
    }
  }

  void dispose() {
    _enterController.close();
    _exitController.close();
  }
}
