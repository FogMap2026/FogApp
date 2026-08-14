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
}

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService(ref.watch(apiClientProvider));
});
