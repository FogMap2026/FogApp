import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/footprint.dart';
import 'api_client.dart';

/// 발자취 API(#1-8, #23) 클라이언트.
class FootprintService {
  FootprintService(this._apiClient);

  final ApiClient _apiClient;

  /// 발자취를 남긴다. 작성자는 서버가 인증 토큰에서 얻으므로 요청에 담지 않는다.
  Future<Footprint> create({required int spotId, required String content}) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/api/footprints',
      data: {'spotId': spotId, 'content': content},
    );
    return Footprint.fromJson(response.data!);
  }
}

final footprintServiceProvider = Provider<FootprintService>((ref) {
  return FootprintService(ref.watch(apiClientProvider));
});
