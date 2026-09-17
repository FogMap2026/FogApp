import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/push_service.dart';
import '../services/traveler_service.dart';
import '../services/traveler_sharing.dart';
import 'privacy_policy_screen.dart';

/// 설정 화면 — 지도 ☰ 메뉴의 마지막 항목.
///
/// 이 항목들은 원래 프로필 화면 아래쪽에 붙어 있었다. 지도 메뉴에 「설정」이 생기면서
/// **프로필(내가 누구인가)과 설정(앱이 어떻게 동작하는가)을 갈랐다** — 둘 다 프로필 화면으로
/// 가면 상단 프로필 버튼과 메뉴의 설정 버튼이 같은 화면을 여는 꼴이 된다.
///
/// 로그아웃(#228)도 여기 있다 — 탈퇴와 나란히 두되 색으로 가른다(되돌릴 수 있는 것 / 없는 것),
/// 그리고 로그아웃 문구에 «기록은 계정에 남는다»를 적어 헷갈리지 않게 한다.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _setPushEnabled(bool enabled) async {
    ref.read(pushEnabledProvider.notifier).set(enabled);
    final push = ref.read(pushServiceProvider);
    if (enabled) {
      await push.enable();
    } else {
      await push.disable();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 알림 받기(#134). 켜져 있으면 이 기기 토큰이 서버에 있고, 끄면 지운다 — 보낼 곳이
            // 없어진다(별도 플래그를 두지 않는다). 보내는 것은 친구 요청·수락·새 메시지뿐이고,
            // 스팟 근접은 푸시로 보내지 않는다(백그라운드 위치를 안 받는다, #135 취소).
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('알림 받기'),
              subtitle: const Text('친구 요청·수락과 새 메시지를 알려줘요'),
              value: ref.watch(pushEnabledProvider),
              onChanged: _setPushEnabled,
            ),
            // 내 위치 공유(#133). 기본값 꺼짐 — 신고 접수본의 opt-in 요건. 게시 자체는 지도
            // 화면이 한다(내 위치를 아는 곳) — travelerSharingProvider 로 잇는다.
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.people_outline),
              title: const Text('내 위치 공유'),
              subtitle: const Text('가까운 스팟 단위로, 30분 뒤에 다른 여행자에게 익명으로 보여요'),
              value: ref.watch(travelerSharingProvider),
              onChanged: (v) => ref.read(travelerSharingProvider.notifier).set(v),
            ),
            // 동의 화면(#152)에서 한 번만 보고 지나가는 처리방침을 여기서도
            // 다시 볼 수 있게 한다 — 이슈의 "다시 볼 수 있는 경로" 요구사항.
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('개인정보처리방침'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
            ),
            const Divider(height: 32),
            // 로그아웃(#228) — 계정은 그대로 두고 이 기기에서만 나간다.
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout),
              title: const Text('로그아웃'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _logout,
            ),
            // 회원 탈퇴(#182). 방침 4장·7장이 약속한 「즉시 파기」의 실제 경로다 —
            // 그전에는 이행 수단이 «운영 DB 에 손으로 치는 SQL» 뿐이었다.
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.person_remove_outlined, color: Theme.of(context).colorScheme.error),
              title: Text('회원 탈퇴', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _withdraw,
            ),
          ],
        ),
      ),
    );
  }

  /// 로그아웃(#228). 계정·기록은 서버에 그대로 남고, 이 기기의 로그인만 푼다 — 다시 로그인하면
  /// 인증·발자취·걷힌 자리가 그대로 돌아온다고 적어 탈퇴와 헷갈리지 않게 한다.
  ///
  /// 로그아웃하면 [AuthGate] 가 로그인 화면으로 바뀌는데, 이 화면은 지도 위에 push 된 것이라
  /// 그대로 두면 로그인 화면 «위에» 남는다 — 먼저 첫 화면까지 걷어낸다.
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('이 기기에서 로그아웃합니다. 인증한 스팟·발자취·걸어온 자리는 계정에 그대로 남아요.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('로그아웃')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _stopSharingBeforeLeaving();
    // 이 기기로 다음 사람 알림이 가지 않게 토큰을 지운다. «꺼둠»으로 기억하지는 않는다(#134).
    await ref.read(pushServiceProvider).disable(forget: false);
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    await ref.read(authServiceProvider).signOut();
  }

  /// 로그아웃·탈퇴 전에 「내 위치 공유」를 끈다(#228 리뷰, 송건희). 세션 상태라 다음 사람이
  /// 같은 기기에서 로그인하면 **켜진 채로 시작**하는데, 그건 신고 접수본의 opt-in(기본값 꺼짐)
  /// 요건을 어긴다. 서버 행 삭제는 실패해도 넘어간다 — 로그아웃 자체는 진행돼야 하고, 남은 행은
  /// 서버가 30분 뒤 알아서 거른다.
  Future<void> _stopSharingBeforeLeaving() async {
    if (ref.read(travelerSharingProvider)) {
      try {
        await ref.read(travelerServiceProvider).stopSharing();
      } catch (e) {
        debugPrint('[Settings] 위치 공유 끄기 실패(로그아웃은 진행): $e');
      }
    }
    ref.read(travelerSharingProvider.notifier).set(false);
  }

  /// 회원 탈퇴(#182). ⛔ **되돌릴 수 없다** — 무엇이 지워지는지 나열하고 확인을 받는다.
  ///
  /// 목록을 «세지 않고 나열»하는 것은 「관련 정보」 같은 말로는 무엇을 잃는지 모르기
  /// 때문이다. 기본 동작은 취소다.
  /// 지운 뒤에는 토큰이 가리키는 계정이 없으므로 **곧바로 로그아웃한다** — 안 그러면
  /// 다음 요청이 전부 실패하며 화면이 깨진 것처럼 보인다.
  Future<void> _withdraw() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('회원 탈퇴'),
        content: const Text(
          '계정과 함께 아래가 모두 삭제됩니다.\n\n'
          '· 방문 인증 기록과 사진\n'
          '· 남긴 발자취와 좋아요\n'
          '· 동행 요청·수락 이력\n'
          '· 여행 성향 결과\n'
          '· 걸어온 자리(안개가 걷힌 지점 기록)\n\n'
          '되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('탈퇴하기'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(profileServiceProvider).withdraw();
      // 공유 상태를 끈다 — 계정은 서버에서 지워졌지만 provider 는 이 기기에 남는다(#228 리뷰).
      ref.read(travelerSharingProvider.notifier).set(false);
      // 계정이 사라졌으니 토큰도 의미가 없다. 로그아웃하면 AuthGate 가 로그인 화면으로
      // 되돌린다 — 그 판정은 한 곳(AuthGate)에 둔다. 다만 이 화면은 지도 위에 push 된
      // 것이라 그대로 두면 로그인 화면 «위에» 남으므로 첫 화면까지 먼저 걷어낸다([_logout] 과 같다).
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      await ref.read(authServiceProvider).signOut();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('탈퇴에 실패했어요. 잠시 후 다시 시도해 주세요.')));
    }
  }
}
