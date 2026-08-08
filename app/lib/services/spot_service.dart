import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/spot.dart';
import 'api_client.dart';

/// 스팟 조회 API(#7) 클라이언트. `GET /api/spots`, `GET /api/spots/nearby`를 감싼다.
class SpotService {
  SpotService(this._apiClient);

  final ApiClient _apiClient;

  /// 현재 위치/지도 중심 반경 [radiusMeters] 안의 스팟을 가까운 순으로 가져온다.
  /// 서버는 최대 20km까지만 허용한다.
  Future<List<Spot>> fetchNearby({
    required double lat,
    required double lng,
    double radiusMeters = 5000,
  }) async {
    final response = await _apiClient.dio.get<List<dynamic>>(
      '/api/spots/nearby',
      queryParameters: {'lat': lat, 'lng': lng, 'radius': radiusMeters},
    );
    return (response.data ?? [])
        .map((e) => Spot.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 지역 코드별 페이징 조회.
  Future<List<Spot>> fetchByRegion(String areaCode, {int page = 0, int size = 50}) async {
    final response = await _apiClient.dio.get<Map<String, dynamic>>(
      '/api/spots',
      queryParameters: {'region': areaCode, 'page': page, 'size': size},
    );
    final content = (response.data?['content'] as List<dynamic>?) ?? [];
    return content.map((e) => Spot.fromJson(e as Map<String, dynamic>)).toList();
  }
}

final spotServiceProvider = Provider<SpotService>((ref) {
  return SpotService(ref.watch(apiClientProvider));
});
