import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'consent_screen.dart';
import 'login_screen.dart';
import 'map_screen.dart';

/// 로그인 상태에 따라 로그인 화면 또는 지도 화면을 보여준다.
///
/// 로그인은 됐지만 개인정보·위치정보 수집에 아직 동의하지 않은 사용자는
/// [ConsentScreen]을 먼저 본다(#152) — 원스토어가 "동의절차 미구현"을 명시적
/// 반려 사유로 든다.
///
/// **동의 여부는 서버에만 있어서, 프로필 조회가 실패하면 지도로 보내지 않고 막는다.**
/// 서버가 죽었다고 통과시키면(fail-open) 네트워크만 끊어도 동의 게이트를 우회할 수
/// 있으므로 그건 안 된다(PGH0621 리뷰, PR #160). 대신 막는 화면 자체는 [#146]과 같은
/// 수준으로 원인·대안을 설명한다 — [_ProfileLoadErrorScreen] 참고.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  Future<Profile>? _profileFuture;
  String? _profileForUid;

  Future<Profile> _loadProfile() {
    return ref.read(profileServiceProvider).me();
  }

  void _reloadProfile() {
    setState(() => _profileFuture = _loadProfile());
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          _profileFuture = null;
          _profileForUid = null;
          return const LoginScreen();
        }

        // 로그인한 사용자가 바뀌면(로그아웃 후 다른 계정 로그인 등) 프로필을 새로 받는다.
        if (_profileFuture == null || _profileForUid != user.uid) {
          _profileForUid = user.uid;
          _profileFuture = _loadProfile();
        }

        return FutureBuilder<Profile>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasError) {
              return _ProfileLoadErrorScreen(onRetry: _reloadProfile);
            }
            final profile = snapshot.data!;
            if (!profile.hasConsented) {
              return ConsentScreen(onConsented: _reloadProfile);
            }
            return const MapScreen();
          },
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(child: Text('인증 오류: $error')),
      ),
    );
  }
}

/// 로그인 직후 프로필 조회가 실패했을 때 보여주는 화면.
///
/// [MapScreen]의 `_ServerErrorNotice`(#146)와 같은 톤(원인 → 대안 → 재시도)을
/// 쓴다 — "프로필을 불러오지 못했어요"라고만 하면 사용자는 자기 계정 문제로
/// 오해하기 쉽지만, 실제로는 대부분 서버 연결 문제다. 심사위원이 새벽에 앱을
/// 켰을 때(서버가 팀원 PC에서 도는 동안, #154) 볼 가능성이 낮지 않은 화면이라
/// 원인과 재시도 경로를 분명히 남긴다.
class _ProfileLoadErrorScreen extends StatelessWidget {
  const _ProfileLoadErrorScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 40, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text('서버에 연결하지 못했어요', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                '잠시 후 다시 시도해 주세요. 계속되면 서버 점검 중일 수 있어요.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
            ],
          ),
        ),
      ),
    );
  }
}
