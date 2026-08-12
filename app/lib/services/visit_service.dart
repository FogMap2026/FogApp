import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/visit.dart';
import 'api_client.dart';

/// 인증 실패 사유. UI가 사용자에게 보여줄 메시지를 분기하는 데 쓴다.
enum VisitVerifyFailureReason { outOfRadius, alreadyVisited, network, unknown }

class VisitVerifyException implements Exception {
  const VisitVerifyException(this.reason, this.message);

  final VisitVerifyFailureReason reason;
  final String message;

  @override
  String toString() => message;
}

/// `POST /api/visits`(#48) 응답 상태 코드를 사람이 읽을 메시지로 변환한다.
/// (422=반경 밖, 409=이미 인증, VisitService.verify 참고)
VisitVerifyException mapVisitVerifyError(DioException error) {
  final status = error.response?.statusCode;
  if (status == 422) {
    return const VisitVerifyException(
      VisitVerifyFailureReason.outOfRadius,
      '스팟 반경 밖에서는 인증할 수 없어요. 조금 더 가까이 가주세요.',
    );
  }
  if (status == 409) {
    return const VisitVerifyException(
      VisitVerifyFailureReason.alreadyVisited,
      '이미 인증한 스팟이에요.',
    );
  }
  switch (error.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
      return const VisitVerifyException(
        VisitVerifyFailureReason.network,
        '네트워크 연결을 확인해주세요.',
      );
    default:
      return const VisitVerifyException(
        VisitVerifyFailureReason.unknown,
        '알 수 없는 오류가 발생했어요. 다시 시도해주세요.',
      );
  }
}

/// 방문 인증 API(#48) 클라이언트.
class VisitService {
  VisitService(this._apiClient);

  final ApiClient _apiClient;

  /// 방문을 인증한다. [photoUrl]은 Storage에 이미 업로드된 사진의 다운로드 URL이어야 한다
  /// (서버는 바이너리를 받지 않는다 — VisitCreateRequest 참고).
  Future<Visit> verify({
    required int spotId,
    required String photoUrl,
    required double lat,
    required double lng,
  }) async {
    try {
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/visits',
        data: {'spotId': spotId, 'photoUrl': photoUrl, 'lat': lat, 'lng': lng},
      );
      return Visit.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapVisitVerifyError(e);
    }
  }

  /// 내 인증 목록(최신순).
  Future<List<Visit>> myVisits() async {
    final response = await _apiClient.dio.get<List<dynamic>>('/api/visits');
    return (response.data ?? [])
        .map((e) => Visit.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final visitServiceProvider = Provider<VisitService>((ref) {
  return VisitService(ref.watch(apiClientProvider));
});
