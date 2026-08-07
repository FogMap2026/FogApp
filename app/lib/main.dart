import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/auth_gate.dart';

/// 빌드/실행 시 `--dart-define=NAVER_MAP_CLIENT_ID=발급받은_ID` 로 주입합니다.
/// 값 발급처는 docs/ENV_GUIDE.md 참고, 절대 커밋하지 마세요.
const String naverMapClientId = String.fromEnvironment('NAVER_MAP_CLIENT_ID');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO(infra): #2(Firebase 프로젝트 설정) 완료 후 `flutterfire configure`로
  // 생성되는 firebase_options.dart를 options 인자로 연결합니다.
  await Firebase.initializeApp();

  await FlutterNaverMap().init(
    clientId: naverMapClientId,
    onAuthFailed: (ex) => debugPrint('[NaverMap] 인증 실패: $ex'),
  );

  runApp(const ProviderScope(child: FogApp()));
}

class FogApp extends StatelessWidget {
  const FogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FogApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B7A99)),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}
