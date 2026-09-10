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
}

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService(ref.watch(apiClientProvider));
});
