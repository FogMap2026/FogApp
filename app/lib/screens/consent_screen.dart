import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'privacy_policy_screen.dart';

/// 최초 로그인 후 띄우는 개인정보·위치정보 수집 동의 화면(#152).
///
/// 원스토어는 "개인정보를 수집하는 상품에 수집·활용 약관 및 동의절차가 구현되지
/// 않은 경우 심사에서 반려"한다고 명시한다 — [AuthGate]가 로그인은 됐지만
/// [Profile.hasConsented]가 false인 사용자를 이 화면으로 보낸다.
///
/// **위치정보 동의를 개인정보 동의와 분리한다.** 체크박스 하나로 묶으면 "동의를
/// 받은 게 아니라 받은 척한 것"이 된다(이슈 본문) — 이 앱은 사용자가 언제 어디에
/// 있었는지를 서버에 남기므로 특히 그렇다.
///
/// **동의는 이 앱을 쓰기 위한 조건이다.** 안개 걷기·발자취 둘 다 위치가 핵심이라
/// 부분 동의로 켤 수 있는 기능이 사실상 없다 — 거부하면 로그아웃한다
/// ([ConsentUpdateRequest] 서버 쪽 문서에 같은 판단을 남겨뒀다).
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({required this.onConsented, super.key});

  /// 동의 저장에 성공하면 호출된다 — [AuthGate]가 프로필을 다시 읽어 지도로 넘어간다.
  final VoidCallback onConsented;

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _privacyChecked = false;
  bool _locationChecked = false;
  bool _submitting = false;
  String? _errorMessage;

  bool get _canSubmit => _privacyChecked && _locationChecked && !_submitting;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(profileServiceProvider).consent();
      if (mounted) widget.onConsented();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = '처리하지 못했어요. 네트워크를 확인하고 다시 시도해주세요.';
      });
    }
  }

  Future<void> _decline() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('동의하지 않고 나가기'),
        content: const Text(
          '개인정보·위치정보 수집에 동의하지 않으면 이 앱을 사용할 수 없어요. '
          '로그아웃할까요?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('로그아웃')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authServiceProvider).signOut();
    }
  }

  void _openFullPolicy() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('시작하기 전에'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('FogApp이 모으는 정보', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    '안개를 걷으며 여행하는 앱의 특성상, 아래 정보를 모아 서비스를 제공합니다. '
                    '자세한 내용은 아래에서 전문을 확인할 수 있어요.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  const _CollectionItem(
                    title: '계정 정보',
                    detail: '이메일, 닉네임, 프로필 이미지 — 로그인·회원 식별에 사용',
                  ),
                  const _CollectionItem(
                    title: '위치정보',
                    detail:
                        '방문 인증·발자취 작성 시점의 좌표 — 안개 해제·정복률 계산에 사용. '
                        '앱 실행 중에만 수집하고, 백그라운드에서는 수집하지 않습니다.',
                  ),
                  const _CollectionItem(
                    title: '사진',
                    detail: '방문 인증 사진, 발자취에 첨부한 사진',
                  ),
                  const _CollectionItem(
                    title: '여행 성향',
                    detail: '성향 테스트 결과 — 동행 추천에 사용',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '보유 기간: 회원 탈퇴 시 지체 없이 파기합니다. 발자취는 직접 삭제할 수 있고, '
                    '삭제하면 즉시 파기됩니다.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _openFullPolicy,
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                    child: const Text('개인정보처리방침 전문 보기'),
                  ),
                  const Divider(height: 32),
                  CheckboxListTile(
                    value: _privacyChecked,
                    onChanged: (v) => setState(() => _privacyChecked = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('개인정보 수집·이용에 동의합니다'),
                    subtitle: const Text('이메일·닉네임·프로필 이미지·이용기록·여행 성향'),
                  ),
                  CheckboxListTile(
                    value: _locationChecked,
                    onChanged: (v) => setState(() => _locationChecked = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('위치정보 수집·이용에 동의합니다'),
                    subtitle: const Text('방문 인증·발자취 작성 시점의 좌표 — 개인정보 동의와 별도입니다'),
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: _canSubmit ? _submit : null,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('동의하고 시작하기'),
                  ),
                  TextButton(
                    onPressed: _submitting ? null : _decline,
                    child: const Text('동의하지 않음'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionItem extends StatelessWidget {
  const _CollectionItem({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(detail, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
