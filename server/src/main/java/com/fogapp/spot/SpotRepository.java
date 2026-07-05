package com.fogapp.spot;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface SpotRepository extends JpaRepository<Spot, Long> {

    /**
     * 중심 좌표 반경(m) 내 스팟을 가까운 순으로 조회한다.
     * geom(GiST 인덱스, idx_spots_geom)을 geography 로 캐스팅해 ST_DWithin/KNN(<->) 을 쓴다 —
     * 반경을 도(degree)가 아닌 미터로 그대로 받기 위함이며, geom 의 GiST 인덱스가 bbox 사전 필터로 쓰인다.
     */
    @Query(value = """
            SELECT * FROM spots
            WHERE geom IS NOT NULL
              AND ST_DWithin(
                    geom::geography,
                    ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography,
                    :radiusMeters
                  )
            ORDER BY geom::geography <-> ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography
            """, nativeQuery = true)
    List<Spot> findWithinRadius(@Param("lat") double lat, @Param("lng") double lng, @Param("radiusMeters") double radiusMeters);
}
