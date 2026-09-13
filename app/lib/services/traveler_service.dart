import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/nearby_traveler.dart';
import 'api_client.dart';

/// 주변 여행자 익명 표시(#133, 6-3) API 클라이언트.
///
/// **opt-in이다.** [share]를 호출한 적이 없으면(또는 [stopSharing] 이후에는)
/// 서버에 내 행 자체가 없다 — 별도로 "공유 꺼짐" 상태를 조회할 API가 없는 이유다.
/// 토글 상태는 화면(세션)이 들고, 서버는 "행이 있다/없다"로만 진실을 가진다.
class TravelerService {
  TravelerService(this._apiClient);

  final ApiClient _apiClient;

  /// 현재 위치를 게시한다. 서버가 가장 가까운 스팟으로 환산해 그 id만 저장한다 —
  /// 좌표 자체는 이 요청을 벗어나면 서버 어디에도 남지 않는다.
  ///
  /// 주변에 스팟이 하나도 없으면 서버가 404를 돌려준다 — 호출부가 조용히 무시해도
  /// 된다(표시할 스팟이 없는 곳에서는 공유할 것도 없다).
  Future<void> share({required double lat, required double lng}) {
    return _apiClient.dio.post<void>(
      '/api/travelers/position',
      data: {'lat': lat, 'lng': lng},
    );
  }

  /// 공유를 끈다. 서버에서 내 위치 행이 지워진다.
  Future<void> stopSharing() {
    return _apiClient.dio.delete<void>('/api/travelers/position');
  }

  /// 반경 내 익명 여행자 목록. 30분 이내 갱신분·본인은 서버가 이미 걸러서 내려준다.
  Future<List<NearbyTraveler>> fetchNearby({
    required double lat,
    required double lng,
    required double radiusMeters,
  }) async {
    final response = await _apiClient.dio.get<List<dynamic>>(
      '/api/travelers/nearby',
      queryParameters: {'lat': lat, 'lng': lng, 'radiusMeters': radiusMeters},
    );
    return (response.data ?? [])
        .map((e) => NearbyTraveler.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final travelerServiceProvider = Provider<TravelerService>((ref) {
  return TravelerService(ref.watch(apiClientProvider));
});
