import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

/// 근접 알림(#46)이 "이미 인증한 스팟은 알리지 않는다" 조건을 걸기 위해 필요한
/// 최소한의 조회만 담당한다. `GET /api/visits`(#48)의 응답에서 `spotId`만 뽑아낸다.
///
/// 방문 인증 자체를 다루는 풀 서비스(사진 업로드·인증 요청 등)는 #47에서 별도로
/// 만들어지고 있다 — 그쪽이 병합되면 이 클래스는 그 서비스로 흡수/정리될 수 있다.
class VisitedSpotsService {
  VisitedSpotsService(this._apiClient);

  final ApiClient _apiClient;

  Future<Set<int>> fetchVisitedSpotIds() async {
    final response = await _apiClient.dio.get<List<dynamic>>('/api/visits');
    return (response.data ?? [])
        .map((e) => (e as Map<String, dynamic>)['spotId'] as int)
        .toSet();
  }
}

final visitedSpotsServiceProvider = Provider<VisitedSpotsService>((ref) {
  return VisitedSpotsService(ref.watch(apiClientProvider));
});
