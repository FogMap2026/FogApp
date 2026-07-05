import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO(infra): #2(Firebase 프로젝트 설정) 완료 후 `flutterfire configure`로
  // 생성되는 firebase_options.dart를 options 인자로 연결합니다.
  await Firebase.initializeApp();
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
