import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/match.dart';
import '../models/match_candidate.dart';
import 'api_client.dart';

/// 매칭(동행) API(#37, 5-1, 5-2) 클라이언트.
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

  /// 내 매칭 전체(#94). 보낸 것·받은 것이 섞여 오며, 각 항목의 `direction`으로 구분한다.
  Future<List<Match>> listForUser() async {
    final response = await _apiClient.dio.get<List<dynamic>>('/api/matches');
    return (response.data ?? []).map((e) => Match.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 받은 요청을 수락·거절한다(#94). [status]는 서버 값 그대로 소문자
  /// (`accepted`/`rejected`)를 받는다 — 요청 대상자만 할 수 있고, 아니면 서버가 403을 준다.
  Future<void> updateStatus({required int matchId, required String status}) async {
    await _apiClient.dio.patch<Map<String, dynamic>>(
      '/api/matches/$matchId/status',
      data: {'status': status},
    );
  }

  /// 매칭을 취소한다(#94). 요청자·대상자 둘 중 한쪽만 할 수 있다.
  Future<void> cancel(int matchId) {
    return _apiClient.dio.delete<void>('/api/matches/$matchId');
  }
}

final matchServiceProvider = Provider<MatchService>((ref) {
  return MatchService(ref.watch(apiClientProvider));
});
