import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

/// 걸어온 자리(#131) — 안개를 15m 반경으로 걷는 데 쓰는 궤적.
///
/// 그전까지 궤적은 앱 메모리에만 있어 **앱을 끄면 사라졌다.** 인증으로 걷힌 안개는
/// `GET /api/visits` 로 복원되는데 걸어온 자리는 복원할 곳이 없었다.
class JourneyService {
  JourneyService(this._apiClient);

  final ApiClient _apiClient;

  /// 서버가 한 번에 받는 최대 개수. 서버의 `JourneyPointsUploadRequest.MAX_POINTS` 와
  /// 같은 값이다 — 넘기면 400 이라 호출부가 쪼개서 보내야 한다.
  static const maxPointsPerUpload = 200;

  /// 궤적을 모아 올린다.
  ///
  /// **재전송해도 안전하다.** 서버가 `(user_id, recorded_at)` 유니크에
  /// `ON CONFLICT DO NOTHING` 으로 받으므로, 네트워크가 끊겼다 붙어 같은 묶음을 다시
  /// 보내도 점이 두 겹으로 쌓이지 않는다. 그래서 앱은 「이미 보냈는지」를 추적하지 않는다.
  ///
  /// 응답의 `saved` 가 0 이어도 **실패가 아니다** — 「이미 다 있다」는 뜻이다.
  ///
  /// @return 서버에 새로 저장된 점의 수
  Future<int> upload(List<JourneyPointUpload> points) async {
    if (points.isEmpty) return 0;
    var saved = 0;
    // 상한을 넘으면 400 이 난다. 오래 끊겼다 붙으면 쌓인 양이 상한을 넘을 수 있어
    // 여기서 쪼갠다 — 서버가 상한을 두는 이유(앱 버그일 때 서버가 먼저 죽는 것)를
    // 앱이 지켜주는 쪽이다.
    for (var i = 0; i < points.length; i += maxPointsPerUpload) {
      final chunk = points.sublist(
        i,
        (i + maxPointsPerUpload).clamp(0, points.length),
      );
      final response = await _apiClient.dio.post<Map<String, dynamic>>(
        '/api/journeys/points',
        data: {'points': chunk.map((p) => p.toJson()).toList()},
      );
      saved += (response.data?['saved'] as num?)?.toInt() ?? 0;
    }
    return saved;
  }

  /// 내 궤적. 지도 진입 시 안개 구멍을 복원하는 데 쓴다.
  ///
  /// 서버는 좌표만 돌려준다 — **반경(15m)과 격자 스냅은 앱이 정한다**
  /// ([FogOverlayController]). 반경을 서버가 정하면 앱을 고칠 때마다 서버를 같이
  /// 배포해야 한다.
  Future<List<NLatLng>> fetchMine() async {
    final response = await _apiClient.dio.get<List<dynamic>>('/api/journeys');
    return (response.data ?? [])
        .map((e) => e as Map<String, dynamic>)
        .map(
          (e) => NLatLng(
            (e['lat'] as num).toDouble(),
            (e['lng'] as num).toDouble(),
          ),
        )
        .toList();
  }
}

/// 올릴 궤적 한 점. [recordedAt] 은 **단말이 측위한 시각**이지 보낸 시각이 아니다 —
/// batch 로 모아 올리므로 둘이 벌어지고, 서버의 멱등 키가 이 값이다.
class JourneyPointUpload {
  const JourneyPointUpload({
    required this.lat,
    required this.lng,
    required this.recordedAt,
  });

  final double lat;
  final double lng;
  final DateTime recordedAt;

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        // 서버가 OffsetDateTime 으로 받는다 — UTC 로 보내 오프셋을 명시한다.
        'recordedAt': recordedAt.toUtc().toIso8601String(),
      };
}

final journeyServiceProvider = Provider<JourneyService>((ref) {
  return JourneyService(ref.watch(apiClientProvider));
});
