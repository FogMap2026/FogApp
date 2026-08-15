import 'dart:io';

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/spot.dart';
import '../services/visit_photo_service.dart';
import '../services/visit_service.dart';

enum _Stage { capturing, preview, uploading, success, error }

/// 스팟 반경 안에서 사진을 찍어 방문을 인증하는 화면(#47).
///
/// 갤러리 선택은 허용하지 않는다 — 현장 촬영만 인증으로 인정한다. 근접 감지(#45)가
/// 반경 진입을 알리면 `MapScreen`이 이 화면을 띄운다. 스팟 상세 화면(3-6, #50)이
/// 아직 없어, 해금 후 상세 정보로 이어지는 흐름은 이후 붙는다.
class VisitVerifyScreen extends ConsumerStatefulWidget {
  const VisitVerifyScreen({
    required this.spot,
    required this.currentLat,
    required this.currentLng,
    super.key,
  });

  final Spot spot;
  final double currentLat;
  final double currentLng;

  @override
  ConsumerState<VisitVerifyScreen> createState() => _VisitVerifyScreenState();
}

class _VisitVerifyScreenState extends ConsumerState<VisitVerifyScreen> {
  CameraController? _controller;
  _Stage _stage = _Stage.capturing;
  String? _cameraError;
  XFile? _capturedPhoto;
  double _uploadProgress = 0;
  String? _errorMessage;
  void Function()? _cancelUpload;

  @override
  void initState() {
    super.initState();
    // 위치 권한과 카메라 권한 요청 시점이 겹치지 않도록, 이 화면에 들어온 뒤에만 요청한다
    // (LocationPermissionGate와 같은 취지 — #26).
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    setState(() => _cameraError = null);
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _cameraError = '사용 가능한 카메라가 없습니다.');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      // 서버가 사진을 5MB 미만으로만 받으므로(#48, VisitPhotoStorage), high 대신
      // medium으로 원본 용량 자체를 줄인다(별도 압축 라이브러리 없이 제한을 안정적으로 지킴).
      final controller = CameraController(back, ResolutionPreset.medium, enableAudio: false);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = e.code == 'CameraAccessDenied'
            ? '카메라 권한이 필요합니다. 설정에서 허용해주세요.'
            : '카메라를 여는 중 문제가 발생했습니다.';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      final photo = await controller.takePicture();
      if (!mounted) return;
      setState(() {
        _capturedPhoto = photo;
        _stage = _Stage.preview;
      });
    } on CameraException {
      if (mounted) setState(() => _cameraError = '촬영에 실패했습니다. 다시 시도해주세요.');
    }
  }

  void _retake() {
    setState(() {
      _capturedPhoto = null;
      _stage = _Stage.capturing;
    });
  }

  Future<void> _confirmAndUpload() async {
    final photo = _capturedPhoto;
    if (photo == null) return;

    setState(() {
      _stage = _Stage.uploading;
      _uploadProgress = 0;
    });

    final photoService = ref.read(visitPhotoServiceProvider);
    final upload = photoService.upload(file: File(photo.path), spotId: widget.spot.id);
    _cancelUpload = upload.cancel;
    upload.progress.listen((p) {
      if (mounted) setState(() => _uploadProgress = p);
    });

    try {
      final photoUrl = await upload.photoUrl;
      final visitService = ref.read(visitServiceProvider);
      await visitService.verify(
        spotId: widget.spot.id,
        photoUrl: photoUrl,
        lat: widget.currentLat,
        lng: widget.currentLng,
      );
      if (!mounted) return;
      setState(() => _stage = _Stage.success);
    } on DioException catch (e) {
      // 사용자가 취소한 경우 _cancelUploadPressed가 이미 화면을 되돌려놨다 —
      // 여기서 에러 화면으로 덮어쓰면 안 된다.
      if (e.type == DioExceptionType.cancel) return;
      if (!mounted) return;
      final statusCode = e.response?.statusCode;
      // 이미 인증한 스팟은 사진 업로드 자체가 막힌다(#76) — "다시 시도"로는 해결되지
      // 않으니 별도 메시지로 안내한다. VisitService.verify()의 같은 케이스
      // (VisitVerifyException)와 문구를 맞췄다.
      if (statusCode == 409) {
        setState(() {
          _errorMessage = '이미 인증한 스팟이에요.';
          _stage = _Stage.error;
        });
        return;
      }
      // 형식·용량 문제(400)는 서버가 이미 구체적인 한국어 메시지를 내려준다
      // (예: "사진 용량은 5MB 이하만 업로드할 수 있습니다.") — 그대로 보여준다.
      final responseData = e.response?.data;
      final serverMessage = statusCode == 400 && responseData is Map
          ? responseData['message'] as String?
          : null;
      setState(() {
        _errorMessage = serverMessage ?? '업로드 중 문제가 발생했습니다. 다시 시도해주세요.';
        _stage = _Stage.error;
      });
    } on VisitVerifyException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _stage = _Stage.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '업로드 중 문제가 발생했습니다. 다시 시도해주세요.';
        _stage = _Stage.error;
      });
    }
  }

  void _cancelUploadPressed() {
    _cancelUpload?.call();
    if (mounted) setState(() => _stage = _Stage.preview);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.spot.title)),
      body: SafeArea(
        child: switch (_stage) {
          _Stage.capturing => _buildCameraView(),
          _Stage.preview => _buildPreview(),
          _Stage.uploading => _buildUploading(),
          _Stage.success => _buildSuccess(context),
          _Stage.error => _buildError(context),
        },
      ),
    );
  }

  Widget _buildCameraView() {
    if (_cameraError != null) {
      return _CenteredMessage(
        message: _cameraError!,
        actionLabel: '다시 시도',
        onAction: _initializeCamera,
      );
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Positioned.fill(child: CameraPreview(controller)),
        Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: FloatingActionButton.large(
            onPressed: _capture,
            child: const Icon(Icons.camera_alt),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    final photo = _capturedPhoto!;
    return Column(
      children: [
        Expanded(child: Image.file(File(photo.path), fit: BoxFit.contain)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: _retake, child: const Text('다시 찍기')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(onPressed: _confirmAndUpload, child: const Text('이 사진으로 인증')),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUploading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: _uploadProgress > 0 ? _uploadProgress : null),
            const SizedBox(height: 12),
            Text('업로드 중… ${(_uploadProgress * 100).toStringAsFixed(0)}%'),
            const SizedBox(height: 16),
            TextButton(onPressed: _cancelUploadPressed, child: const Text('취소')),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text('${widget.spot.title} 인증 완료!', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 48),
            const SizedBox(height: 16),
            Text(_errorMessage ?? '알 수 없는 오류가 발생했습니다.', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('닫기'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () => setState(() => _stage = _Stage.preview),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.message, required this.actionLabel, required this.onAction});

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
