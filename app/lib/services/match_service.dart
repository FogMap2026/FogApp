import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/match_candidate.dart';
import 'api_client.dart';

/// 매칭(동행) API(#37, 5-1) 클라이언트. 후보 추천·요청 보내기만 다룬다 —
/// 요청 목록·수락/거절은 #94에서 별도로 붙는다.
class MatchService {
  MatchService(this._apiClient);

  final ApiClient _apiClient;

  /// 성향이 비슷한 순으로 최대 [limit]명을 추천받는다. 성향 테스트를 안 했거나
  /// 후보가 없으면 빈 목록이 온다 — 두 경우를 구분하려면 호출부가 프로필의
  /// `personalityType`을 먼저 봐야 한다(서버가 이유를 구분해 내려주지 않는다).
  Future<List<MatchCandidate>> candidates({int limit = 10}) async {
    final response = await _apiClient.dio.get<List<dynamic>>(
      '/api/matches/candidates',
      queryParameters: {'limit': limit},
    );
    return (response.data ?? [])
        .map((e) => MatchCandidate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 동행 요청을 보낸다. 이미 요청한 상대면 서버가 400을 돌려준다.
  Future<void> request({required int addresseeId}) async {
    await _apiClient.dio.post<Map<String, dynamic>>(
      '/api/matches',
      data: {'addresseeId': addresseeId},
    );
  }
}

final matchServiceProvider = Provider<MatchService>((ref) {
  return MatchService(ref.watch(apiClientProvider));
});
