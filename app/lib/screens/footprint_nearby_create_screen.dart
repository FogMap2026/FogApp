import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/footprint_service.dart';

/// 길목에 발자취(글귀)를 남기는 화면(#114, #118).
///
/// 스팟에 남기는 발자취([FootprintCreateScreen])와 달리 [lat]·[lng]만으로
/// 작성한다 — `spotId`는 넘기지 않는다(길목 글귀는 스팟이 없다).
///
/// GPS 정확도 검증(10m)과 잔여 횟수 확인은 이 화면에 오기 **전에** 호출부
/// (`MapScreen`)가 이미 마쳤다 — 여기서는 텍스트만 받고 제출한다. 다만 제출
/// 시점에 다른 기기에서 이미 횟수를 다 썼을 수 있어(#116), 429는 여기서도
/// 처리한다.
class FootprintNearbyCreateScreen extends ConsumerStatefulWidget {
  const FootprintNearbyCreateScreen({required this.lat, required this.lng, super.key});

  final double lat;
  final double lng;

  @override
  ConsumerState<FootprintNearbyCreateScreen> createState() => _FootprintNearbyCreateScreenState();
}

class _FootprintNearbyCreateScreenState extends ConsumerState<FootprintNearbyCreateScreen> {
  final _contentController = TextEditingController();
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  bool get _canSubmit => _contentController.text.trim().isNotEmpty && !_submitting;

  Future<void> _submit() async {
    final content = _contentController.text.trim();
    if (content.isEmpty || _submitting) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(footprintServiceProvider).create(
            content: content,
            lat: widget.lat,
            lng: widget.lng,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = e.response?.statusCode == 429
            ? '남은 발자취가 없어요. 스팟을 정복하면 다시 채워집니다.'
            : '발자취를 남기지 못했어요. 네트워크를 확인하고 다시 시도해주세요.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = '발자취를 남기지 못했어요. 네트워크를 확인하고 다시 시도해주세요.';
      });
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
              Expanded(
                child: TextField(
                  controller: _contentController,
                  autofocus: true,
                  maxLength: 1000,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: '지금 여기서 남기고 싶은 한마디',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _canSubmit ? _submit : null,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('발자취 남기기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
