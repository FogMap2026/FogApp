import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/spot.dart';
import '../services/footprint_service.dart';

/// 스팟에 발자취(글)를 남기는 화면(#70).
///
/// 사진 첨부는 이번 스코프에서 뺐다 — 발자취 전용 업로드 엔드포인트가 아직 없고
/// (`POST /api/visits/photo`는 방문 인증 전용이라 경로 검증이 다르다), 이슈에서
/// 제안된 "텍스트만으로 시작" 안을 따른다. 필요해지면 별도 이슈로 붙인다.
class FootprintCreateScreen extends ConsumerStatefulWidget {
  const FootprintCreateScreen({required this.spot, super.key});

  final Spot spot;

  @override
  ConsumerState<FootprintCreateScreen> createState() => _FootprintCreateScreenState();
}

class _FootprintCreateScreenState extends ConsumerState<FootprintCreateScreen> {
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
      await ref.read(footprintServiceProvider).create(spotId: widget.spot.id, content: content);
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
      appBar: AppBar(title: Text('${widget.spot.title}에 발자취 남기기')),
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
                    hintText: '이곳에서의 기억을 남겨보세요',
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
