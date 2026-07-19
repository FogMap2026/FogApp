import 'package:flutter/material.dart';

import 'social/personality_test_screen.dart';

/// 탐험의 메인 화면. Phase 2에서 Naver Map + 안개 오버레이로 대체됩니다.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🌫️ FogApp')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🌫️', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text('안개 지도가 여기에 표시됩니다'),
            const SizedBox(height: 8),
            const Text(
              'Phase 2 — Map & Fog Core',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            OutlinedButton(
              // 지도 화면이 준비될 때까지 성향 테스트(#31)로 가는 임시 진입점.
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PersonalityTestScreen()),
              ),
              child: const Text('여행 성향 테스트 하기'),
            ),
          ],
        ),
      ),
    );
  }
}
