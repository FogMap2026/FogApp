import 'package:flutter/material.dart';

/// 탐험의 메인 화면. Phase 2에서 Naver Map + 안개 오버레이로 대체됩니다.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🌫️ FogApp')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🌫️', style: TextStyle(fontSize: 64)),
            SizedBox(height: 16),
            Text('안개 지도가 여기에 표시됩니다'),
            SizedBox(height: 8),
            Text(
              'Phase 2 — Map & Fog Core',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
