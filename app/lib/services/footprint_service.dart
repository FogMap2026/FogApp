import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/footprint.dart';
import 'api_client.dart';

/// 발자취 API(#1-8, #23) 클라이언트.
class FootprintService {
  FootprintService(this._apiClient);

  final ApiClient _apiClient;

  /// 발자취를 남긴다. 작성자는 서버가 인증 토큰에서 얻으므로 요청에 담지 않는다.
  ///
  /// [spotId]는 스팟 상세에서 쓸 때만 넘긴다(#70) — 길목 글귀(#114)는 스팟이 없으니
  /// null로 둔다. [lat]·[lng]는 길목 글귀의 좌표(#115)로, 스팟 글은 넘기지 않아도 된다.
  ///
  /// 남은 발자취 횟수가 없으면 서버가 429를 돌려준다(#116) — 호출부가 처리해야 한다.
  Future<Footprint> create({int? spotId, required String content, double? lat, double? lng}) async {
    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/api/footprints',
      data: {'spotId': spotId, 'content': content, 'lat': lat, 'lng': lng},
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

  /// 내 주변 발자취(#115, #117). 걷다가 지도에서 발견하는 흐름이 쓴다.
  ///
  /// [radiusMeters]는 앱이 정한다 — 이동 중 50m, 해금된 스팟 안에서는 150m
  /// ([FootprintNearbyPolicy] 참고). 서버가 1,000m 상한과 최대 200건을 강제하므로
  /// 그보다 큰 값을 넘기면 400이 돌아온다.
  Future<List<Footprint>> listNearby({
    required double lat,
    required double lng,
    required double radiusMeters,
  }) async {
    final response = await _apiClient.dio.get<List<dynamic>>(
      '/api/footprints/nearby',
      queryParameters: {'lat': lat, 'lng': lng, 'radius': radiusMeters},
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
