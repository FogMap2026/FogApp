import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/footprint.dart';
import 'fog_regions.dart';
import 'footprint_service.dart';
import 'profile_service.dart';

/// 지도 화면이 만든 안개 구역([FogRegions]). 다른 화면(스팟 상세)이 «여기가 어느 구역인가»를
/// 물을 수 있게 provider 로 둔다 — 지도가 아직 못 만들었으면 null.
final fogRegionsProvider = StateProvider<FogRegions?>((ref) => null);

/// 「발자취는 구역당 하나」 규칙(시진, 09-15)의 판정.
///
/// 발자취는 «내가 거기 있었다»는 표시라 한 구역에 여럿 쌓이면 표시가 아니라 게시판이 된다.
/// 구역은 안개와 같은 보로노이 구역이다 — 스팟 하나에 구역 하나, 빈 땅은 1.5km 격자.
/// 남기려는 자리의 구역에 내 발자취가 이미 있으면 [FootprintRegionTaken] 을 돌려주고, 호출부가
/// 안내를 띄운다. 구역이 아직 없으면(좌표 받는 중) 막지 않는다 — 판정을 못 하는 것이지
/// 규칙을 어긴 것이 아니다.
///
/// 서버는 아직 이 규칙을 모른다(횟수·좌표만 본다). 앱이 먼저 막고, 서버 쪽은 후속이다.
class FootprintRegionGate {
  FootprintRegionGate(this._regions, this._footprints, this._profiles);

  final FogRegions? _regions;
  final FootprintService _footprints;
  final ProfileService _profiles;

  Future<FootprintRegionCheck> check({required double lat, required double lng}) async {
    final regions = _regions;
    if (regions == null) return const FootprintRegionFree();
    final here = regions.nearest(lat, lng);
    if (here == null) return const FootprintRegionFree();

    final me = await _profiles.me();
    final mine = await _footprints.listByUser(me.id);
    for (final f in mine) {
      final flat = f.lat;
      final flng = f.lng;
      if (flat == null || flng == null) continue;
      if (regions.nearest(flat, flng)?.index == here.index) return FootprintRegionTaken(f);
    }
    return const FootprintRegionFree();
  }
}

sealed class FootprintRegionCheck {
  const FootprintRegionCheck();
}

class FootprintRegionFree extends FootprintRegionCheck {
  const FootprintRegionFree();
}

/// 이 구역에 이미 남긴 내 발자취.
class FootprintRegionTaken extends FootprintRegionCheck {
  const FootprintRegionTaken(this.existing);

  final Footprint existing;
}

final footprintRegionGateProvider = Provider<FootprintRegionGate>((ref) {
  return FootprintRegionGate(
    ref.watch(fogRegionsProvider),
    ref.watch(footprintServiceProvider),
    ref.watch(profileServiceProvider),
  );
});
