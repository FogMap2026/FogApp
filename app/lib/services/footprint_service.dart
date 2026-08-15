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

  /// 스팟의 발자취 목록(#71). 최신순으로 내려온다. 페이지네이션은 서버에 아직 없다.
  Future<List<Footprint>> listBySpot(int spotId) async {
    final response = await _apiClient.dio.get<List<dynamic>>(
      '/api/footprints',
      queryParameters: {'spotId': spotId},
    );
    return (response.data ?? [])
        .map((e) => Footprint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 좋아요(#72). 서버가 멱등 처리하므로 이미 누른 상태에서 다시 호출해도 에러 없이 무시된다.
  Future<void> like(int footprintId) {
    return _apiClient.dio.post<void>('/api/footprints/$footprintId/likes');
  }

  /// 좋아요 취소(#72). 서버가 멱등 처리하므로 안 누른 상태에서 호출해도 에러 없이 무시된다.
  Future<void> unlike(int footprintId) {
    return _apiClient.dio.delete<void>('/api/footprints/$footprintId/likes');
  }

  /// 내 발자취 모아보기(#73). 최신순으로 내려온다.
  Future<List<Footprint>> listByUser(int userId) async {
    final response = await _apiClient.dio.get<List<dynamic>>(
      '/api/footprints',
      queryParameters: {'userId': userId},
    );
    return (response.data ?? [])
        .map((e) => Footprint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 발자취를 수정한다(#73). 본인 것만 가능 — 서버가 소유자를 검증한다.
  ///
  /// [photoUrl]은 서버가 무조건 덮어쓰므로(부분 수정이 아니다), 사진을 바꾸지 않을
  /// 거면 원래 값을 그대로 넘겨야 한다 — 비우면 기존 사진이 지워진다.
  Future<Footprint> update({required int footprintId, required String content, String? photoUrl}) async {
    final response = await _apiClient.dio.patch<Map<String, dynamic>>(
      '/api/footprints/$footprintId',
      data: {'content': content, 'photoUrl': photoUrl},
    );
    return Footprint.fromJson(response.data!);
  }

  /// 발자취를 삭제한다(#73). 본인 것만 가능 — 서버가 소유자를 검증한다.
  Future<void> delete(int footprintId) {
    return _apiClient.dio.delete<void>('/api/footprints/$footprintId');
  }
}

final footprintServiceProvider = Provider<FootprintService>((ref) {
  return FootprintService(ref.watch(apiClientProvider));
});
