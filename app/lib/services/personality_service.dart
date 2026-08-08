import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/personality.dart';
import 'api_client.dart';

/// 성향 테스트 결과를 서버 프로필에 저장한다.
///
/// ⚠️ 서버 쪽 `PATCH /api/profile/personality`는 아직 배포되지 않았다(#4/#31 병합 대기).
/// 엔드포인트가 준비되기 전까지 이 호출은 404로 실패하며, 화면은 이를 사용자에게
/// 일반 오류 메시지로 안내한다(로그인 화면과 동일한 에러 처리 패턴).
class PersonalityService {
  PersonalityService(this._apiClient);

  final ApiClient _apiClient;

  Future<void> saveResult(PersonalityResult result) async {
    await _apiClient.dio.patch(
      '/api/profile/personality',
      data: {
        'personalityType': result.type,
        'personalityScores': result.toScoresJson(),
      },
    );
  }
}

final personalityServiceProvider = Provider<PersonalityService>((ref) {
  return PersonalityService(ref.watch(apiClientProvider));
});
