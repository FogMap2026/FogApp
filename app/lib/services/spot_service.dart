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

  /// [areaCode] 안에서도 [sigunguCode]로 좁힌 스팟 전체 — 정복 현황 화면(지역 상세)이
  /// "이 시/군/구의 스팟" 목록을 보여주는 데 쓴다.
  ///
  /// 서버 `GET /api/spots?region=`은 시/도(`areaCode`) 단위까지만 거른다 — 시/군/구로
  /// 더 좁히는 파라미터가 없다. 그래서 시/도 전체를 최대 페이지 크기(200,
  /// `SpotQueryService.MAX_PAGE_SIZE`)로 받아와 여기서 `sigunguCode`로 다시 거른다.
  ///
  /// [expectedCount](정복률 API의 `totalSpots` — 이 시/군/구의 전체 스팟 수)만큼
  /// 모이면 더 받지 않는다. 서울처럼 시/도 전체 스팟이 수천 개라도, 원하는 시/군/구
  /// 분량만 모이면 나머지 페이지는 볼 필요가 없다.
  Future<List<Spot>> fetchBySigungu({
    required String areaCode,
    required String? sigunguCode,
    int? expectedCount,
  }) async {
    const pageSize = 200;
    final matched = <Spot>[];
    var page = 0;
    while (true) {
      final response = await _apiClient.dio.get<Map<String, dynamic>>(
        '/api/spots',
        queryParameters: {'region': areaCode, 'page': page, 'size': pageSize},
      );
      final data = response.data ?? const <String, dynamic>{};
      final content = (data['content'] as List<dynamic>? ?? [])
          .map((e) => Spot.fromJson(e as Map<String, dynamic>))
          .toList();
      matched.addAll(content.where((s) => _normalizedSigunguCode(s.sigunguCode) == sigunguCode));

      final totalPages = data['totalPages'] as int? ?? 1;
      page++;
      if (page >= totalPages) break;
      if (expectedCount != null && matched.length >= expectedCount) break;
    }
    return matched;
  }
}

/// 빈 문자열도 "코드 없음"으로 다룬다 — [splitRegionCode]가 빈 시/군/구 코드를
/// `null`로 맞추는 것과 짝이 맞아야 비교가 성립한다.
String? _normalizedSigunguCode(String? code) => (code == null || code.isEmpty) ? null : code;

final spotServiceProvider = Provider<SpotService>((ref) {
  return SpotService(ref.watch(apiClientProvider));
});
