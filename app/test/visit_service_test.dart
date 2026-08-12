import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogapp/services/visit_service.dart';

DioException _errorWithStatus(int statusCode) {
  final requestOptions = RequestOptions(path: '/api/visits');
  return DioException(
    requestOptions: requestOptions,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: requestOptions, statusCode: statusCode),
  );
}

DioException _errorWithType(DioExceptionType type) {
  return DioException(requestOptions: RequestOptions(path: '/api/visits'), type: type);
}

void main() {
  test('422는 반경 밖 실패로 분류된다', () {
    final result = mapVisitVerifyError(_errorWithStatus(422));
    expect(result.reason, VisitVerifyFailureReason.outOfRadius);
  });

  test('409는 이미 인증한 스팟 실패로 분류된다', () {
    final result = mapVisitVerifyError(_errorWithStatus(409));
    expect(result.reason, VisitVerifyFailureReason.alreadyVisited);
  });

  test('연결 오류는 네트워크 실패로 분류된다', () {
    final result = mapVisitVerifyError(_errorWithType(DioExceptionType.connectionError));
    expect(result.reason, VisitVerifyFailureReason.network);
  });

  test('그 외 오류는 알 수 없음으로 분류된다', () {
    final result = mapVisitVerifyError(_errorWithStatus(500));
    expect(result.reason, VisitVerifyFailureReason.unknown);
  });
}
