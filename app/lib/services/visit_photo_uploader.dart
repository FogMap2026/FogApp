import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 진행 중인 업로드 하나를 나타낸다. 서버는 바이너리를 받지 않고 다운로드 URL만
/// 저장하므로(`VisitCreateRequest` 참고), 인증 API 호출 전 이 업로드가 먼저 끝나야 한다.
class VisitPhotoUpload {
  const VisitPhotoUpload({
    required this.progress,
    required this.downloadUrl,
    required this.cancel,
  });

  /// 0.0~1.0 진행률 스트림.
  final Stream<double> progress;

  /// 업로드 완료 시 다운로드 URL로 완료되는 Future.
  final Future<String> downloadUrl;

  /// 업로드를 취소한다.
  final Future<bool> Function() cancel;
}

/// 방문 인증 사진을 Firebase Storage에 업로드한다(#47).
class VisitPhotoUploader {
  VisitPhotoUploader(this._storage, this._auth);

  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  VisitPhotoUpload upload({required File file, required int spotId}) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('로그인 상태에서만 업로드할 수 있습니다.');
    }

    final ref = _storage
        .ref()
        .child('visit_photos')
        .child(uid)
        .child('$spotId-${DateTime.now().millisecondsSinceEpoch}.jpg');

    final task = ref.putFile(file);

    final progressController = StreamController<double>.broadcast();
    final subscription = task.snapshotEvents.listen((snapshot) {
      if (snapshot.totalBytes > 0) {
        progressController.add(snapshot.bytesTransferred / snapshot.totalBytes);
      }
    });
    task.whenComplete(() {
      subscription.cancel();
      progressController.close();
    });

    final downloadUrl = task.then((_) => ref.getDownloadURL());

    return VisitPhotoUpload(
      progress: progressController.stream,
      downloadUrl: downloadUrl,
      cancel: task.cancel,
    );
  }
}

final visitPhotoUploaderProvider = Provider<VisitPhotoUploader>((ref) {
  return VisitPhotoUploader(FirebaseStorage.instance, FirebaseAuth.instance);
});
