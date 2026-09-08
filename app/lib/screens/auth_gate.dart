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
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('프로필을 불러오지 못했어요.'),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _reloadProfile, child: const Text('다시 시도')),
                    ],
                  ),
                ),
              );
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
