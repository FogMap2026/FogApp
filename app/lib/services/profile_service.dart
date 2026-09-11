import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile.dart';
import 'api_client.dart';

/// 내 프로필 API(#4) 클라이언트. `GET /api/profile`은 본인 것만 내려준다.
class ProfileService {
  ProfileService(this._apiClient);

  final ApiClient _apiClient;

  Future<Profile> me() async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>('/api/profile');
    return Profile.fromJson(response.data!);
  }

  /// 개인정보·위치정보 수집 동의를 기록한다(#152). 서버가 둘 다 `true`만 받는다 —
  /// 이 앱은 위치 기반이라 부분 동의로는 핵심 기능이 성립하지 않는다.
  Future<Profile> consent() async {
    final response = await _apiClient.dio.patch<Map<String, dynamic>>(
      '/api/profile/consent',
      data: {'privacy': true, 'location': true},
    );
    return Profile.fromJson(response.data!);
  }

  /// 회원 탈퇴(#182). 계정과 관련 정보를 **즉시** 파기한다.
  ///
  /// ⛔ **되돌릴 수 없다.** 서버가 `users` 한 행을 지우면 방문 인증·발자취·동행·좋아요가
  /// 전부 따라가고(`ON DELETE CASCADE`), 인증 사진과 Firebase 계정도 함께 지워진다.
  /// 호출부는 반드시 사용자 확인을 먼저 받아야 한다.
  ///
  /// 지운 뒤에는 토큰이 가리키는 계정이 없으므로 **곧바로 로그아웃해야 한다** —
  /// 안 그러면 다음 요청이 전부 실패하며 화면이 «깨진 것»처럼 보인다.
  Future<void> withdraw() async {
    await _apiClient.dio.delete<void>('/api/profile');
  }
}

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService(ref.watch(apiClientProvider));
});
