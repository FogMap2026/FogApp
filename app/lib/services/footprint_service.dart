import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

/// 발자취 작성 API(#23) 클라이언트. 조회·좋아요는 이 스코프(#70)에 없다 — #71/#72에서 붙는다.
class FootprintService {
  FootprintService(this._apiClient);

  final ApiClient _apiClient;

  /// 스팟에 발자취를 남긴다. 사진은 아직 붙이지 않는다 — 발자취 전용 업로드
  /// 엔드포인트가 없어(#70 이슈 참고) 텍스트만으로 시작한다.
  Future<void> create({required int spotId, required String content}) async {
    await _apiClient.dio.post<Map<String, dynamic>>(
      '/api/footprints',
      data: {'spotId': spotId, 'content': content},
    );
  }
}

final footprintServiceProvider = Provider<FootprintService>((ref) {
  return FootprintService(ref.watch(apiClientProvider));
});
