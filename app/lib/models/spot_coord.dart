/// 스팟의 id 와 좌표만 — 안개 구역([FogRegions])이 전국 스팟을 한 번에 받을 때 쓴다
/// (`GET /api/spots/coords`, #223). 제목·주소·소개는 없다: 구역은 «어디에 스팟이 있나»만 안다.
class SpotCoord {
  const SpotCoord({required this.id, required this.lat, required this.lng});

  final int id;
  final double lat;
  final double lng;

  factory SpotCoord.fromJson(Map<String, dynamic> json) => SpotCoord(
        id: (json['id'] as num).toInt(),
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
      );

  /// 기기 캐시용 — `[id, lat, lng]` 로 줄여 12,600건을 300KB 안쪽에 둔다.
  List<num> toCompact() => [id, lat, lng];

  factory SpotCoord.fromCompact(List<dynamic> row) => SpotCoord(
        id: (row[0] as num).toInt(),
        lat: (row[1] as num).toDouble(),
        lng: (row[2] as num).toDouble(),
      );
}
