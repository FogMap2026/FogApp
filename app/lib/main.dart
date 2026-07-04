import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/map_screen.dart';

void main() {
  // TODO(infra): Firebase.initializeApp() 연동 (Phase 1)
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
      home: const MapScreen(),
    );
  }
}
