import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

/// 진행 중인 사진 업로드 하나를 나타낸다.
class VisitPhotoUpload {
  const VisitPhotoUpload({
    required this.progress,
    required this.photoUrl,
    required this.cancel,
  });

  /// 0.0~1.0 업로드 진행률 스트림.
  final Stream<double> progress;

  /// 업로드 완료 시 서버가 돌려준 `photoUrl`(상대 경로)로 완료되는 Future.
  /// 이 값을 그대로 `VisitService.verify`의 photoUrl로 넘겨야 한다 — 가공하면
  /// 서버의 출처 검증에서 거부된다.
  final Future<String> photoUrl;

  /// 업로드를 취소한다.
  final void Function() cancel;
}

/// 방문 인증 사진을 서버에 직접 업로드한다(#48, 팀 결정 B안).
///
/// Firebase Storage는 무료(Spark) 요금제에서 버킷 생성이 막혀 쓸 수 없다 — 로그인
/// (Firebase Auth)·푸시(FCM)는 그대로 두고 사진만 서버가 보관한다. 업로드는
/// `POST /api/visits/photo`(multipart)로 하며, 다른 API와 마찬가지로 [ApiClient]의
/// 인터셉터가 Firebase ID 토큰을 자동으로 실어 보낸다.
class VisitPhotoService {
  VisitPhotoService(this._apiClient);

  final ApiClient _apiClient;

  VisitPhotoUpload upload({required File file, required int spotId}) {
    final progressController = StreamController<double>.broadcast();
    final cancelToken = CancelToken();

    final photoUrl = _send(file, spotId, progressController, cancelToken)
        .whenComplete(progressController.close);

    return VisitPhotoUpload(
      progress: progressController.stream,
      photoUrl: photoUrl,
      cancel: cancelToken.cancel,
    );
  }

  Future<String> _send(
    File file,
    int spotId,
    StreamController<double> progressController,
    CancelToken cancelToken,
  ) async {
    final multipartFile = await MultipartFile.fromFile(file.path, filename: 'photo.jpg');
    final formData = FormData.fromMap({'spotId': spotId, 'file': multipartFile});

    final response = await _apiClient.dio.post<Map<String, dynamic>>(
      '/api/visits/photo',
      data: formData,
      cancelToken: cancelToken,
      onSendProgress: (sent, total) {
        if (total > 0) progressController.add(sent / total);
      },
    );
    return response.data!['photoUrl'] as String;
  }
}

final visitPhotoServiceProvider = Provider<VisitPhotoService>((ref) {
  return VisitPhotoService(ref.watch(apiClientProvider));
});
