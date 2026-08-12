import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import 'api_client.dart';

/// 서버 `VisitResponse`(#48)에서 이 화면이 쓰는 최소 필드만 뽑은 모델.
/// `spotId`는 근접 알림(#46) 필터에, `center`는 안개 복원(#49)에 쓰인다.
class VisitedSpot {
  const VisitedSpot({required this.spotId, required this.center});

  final int spotId;
  final NLatLng center;
}

/// `GET /api/visits`(#48) — 내 인증 목록 조회를 담당한다.
///
/// 근접 알림(#46)의 "이미 인증한 스팟은 알리지 않는다" 필터와, 안개 복원(#49)의
/// "재진입 시 걷힌 영역 유지"가 같은 응답을 서로 다른 용도로 쓰므로 한 번만 조회해
/// [VisitedSpot] 목록으로 감싼다.
///
/// 방문 인증 자체를 다루는 풀 서비스(사진 업로드·인증 요청 등)는 #47에서 별도로
/// 만들어지고 있다 — 그쪽이 병합되면 이 클래스는 그 서비스로 흡수/정리될 수 있다.
class VisitedSpotsService {
  VisitedSpotsService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<VisitedSpot>> fetchVisitedSpots() async {
    final response = await _apiClient.dio.get<List<dynamic>>('/api/visits');
    return (response.data ?? []).map((e) {
      final map = e as Map<String, dynamic>;
      return VisitedSpot(
        spotId: map['spotId'] as int,
        center: NLatLng((map['lat'] as num).toDouble(), (map['lng'] as num).toDouble()),
      );
    }).toList();
  }
}

final visitedSpotsServiceProvider = Provider<VisitedSpotsService>((ref) {
  return VisitedSpotsService(ref.watch(apiClientProvider));
});
