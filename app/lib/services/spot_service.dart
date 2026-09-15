import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/spot.dart';
import '../models/spot_coord.dart';
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
    return (response.data ?? []).map((e) => Spot.fromJson(e as Map<String, dynamic>)).toList();
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

  /// 전국 스팟의 id·좌표(안개 구역용, #223). 기기 캐시 → `GET /api/spots/coords` → (구 서버면)
  /// 시/도별 페이지 조회 순으로 시도한다.
  ///
  /// 캐시는 앱 캐시 디렉터리의 파일이다 — 스팟은 수집 배치 때만 바뀌므로 한 번 받으면 오래
  /// 쓴다. 시스템이 캐시를 비우면 다시 받으면 그만이다(1~2초). 페이지 폴백은 17개 시/도 ×
  /// 200건씩 60여 번 왕복(75초)이라 마지막 수단이고, 전부 성공했을 때만 캐시한다 —
  /// 빠진 시/도가 영영 빈 땅으로 남지 않게.
  Future<List<SpotCoord>> fetchAllCoords() async {
    final file = File('${Directory.systemTemp.path}/spot_coords_v1.json');
    if (await file.exists()) {
      try {
        final raw = jsonDecode(await file.readAsString()) as List<dynamic>;
        return [for (final row in raw) SpotCoord.fromCompact(row as List<dynamic>)];
      } catch (e) {
        debugPrint('[SpotService] 좌표 캐시 손상, 다시 받는다: $e');
      }
    }
    List<SpotCoord> coords;
    try {
      final response = await _apiClient.dio.get<List<dynamic>>('/api/spots/coords');
      coords = [for (final e in response.data ?? const []) SpotCoord.fromJson(e as Map<String, dynamic>)];
    } on DioException catch (e) {
      // 구 서버(404 — /error 재디스패치 때문에 401 로도 온다, #221)면 페이지 조회로.
      debugPrint('[SpotService] /api/spots/coords 실패(${e.response?.statusCode}) — 시/도별 조회로 폴백');
      coords = await _fetchAllCoordsByRegion();
    }
    if (coords.isNotEmpty) {
      await file.writeAsString(jsonEncode([for (final c in coords) c.toCompact()]));
    }
    return coords;
  }

  /// 관광공사 시/도 코드 — 탐험 현황 배지와 같은 코드 체계.
  static const _areaCodes = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '31',
    '32',
    '33',
    '34',
    '35',
    '36',
    '37',
    '38',
    '39',
  ];

  Future<List<SpotCoord>> _fetchAllCoordsByRegion() async {
    final all = <SpotCoord>[];
    for (final code in _areaCodes) {
      const pageSize = 200;
      var page = 0;
      while (true) {
        final response = await _apiClient.dio.get<Map<String, dynamic>>(
          '/api/spots',
          queryParameters: {'region': code, 'page': page, 'size': pageSize},
        );
        final data = response.data ?? const <String, dynamic>{};
        for (final e in data['content'] as List<dynamic>? ?? const []) {
          final spot = Spot.fromJson(e as Map<String, dynamic>);
          all.add(SpotCoord(id: spot.id, lat: spot.lat, lng: spot.lng));
        }
        page++;
        if (page >= (data['totalPages'] as int? ?? 1)) break;
      }
    }
    return all;
  }
}

final spotServiceProvider = Provider<SpotService>((ref) {
  return SpotService(ref.watch(apiClientProvider));
});
