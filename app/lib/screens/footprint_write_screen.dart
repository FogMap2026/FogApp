import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/spot.dart';
import '../services/footprint_service.dart';

/// 스팟에 발자취(글)를 남기는 화면(#70).
///
/// 방문 인증(#47)과 독립적이다 — 서버가 막지 않아, 인증 전 스팟에도 쓸 수 있게
/// 열어둔다. 사진 첨부는 발자취 전용 업로드 엔드포인트가 아직 없어 이번 스코프에는
/// 없다(이슈 #70의 제안대로 텍스트만 우선 지원, 필요해지면 별도 이슈로 다룬다).
class FootprintWriteScreen extends ConsumerStatefulWidget {
  const FootprintWriteScreen({required this.spot, super.key});

  final Spot spot;

  @override
  ConsumerState<FootprintWriteScreen> createState() => _FootprintWriteScreenState();
}

class _FootprintWriteScreenState extends ConsumerState<FootprintWriteScreen> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSubmit => _controller.text.trim().isNotEmpty && !_submitting;

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(footprintServiceProvider).create(spotId: widget.spot.id, content: content);
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      final responseData = e.response?.data;
      final serverMessage = e.response?.statusCode == 400 && responseData is Map
          ? responseData['message'] as String?
          : null;
      if (mounted) {
        setState(() => _errorMessage = serverMessage ?? '발자취를 남기지 못했어요. 다시 시도해주세요.');
      }
    } catch (_) {
      if (mounted) setState(() => _errorMessage = '발자취를 남기지 못했어요. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('발자취 남기기')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.spot.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                maxLines: 8,
                maxLength: 1000,
                autofocus: true,
                enabled: !_submitting,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: '이곳에서의 기록을 남겨보세요',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _canSubmit ? _submit : null,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('남기기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
