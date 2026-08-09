import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/conquest.dart';
import 'api_client.dart';

/// 정복률 API(#51) 클라이언트.
class ConquestService {
  ConquestService(this._apiClient);

  final ApiClient _apiClient;

  /// 내 지역별(시/군/구) 정복률 전체 목록.
  Future<List<ConquestRegion>> myConquest() async {
    final response = await _apiClient.dio.get<List<dynamic>>('/api/conquest');
    return (response.data ?? [])
        .map((e) => ConquestRegion.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final conquestServiceProvider = Provider<ConquestService>((ref) {
  return ConquestService(ref.watch(apiClientProvider));
});
