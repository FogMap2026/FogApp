package com.fogapp.footprint;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface FootprintRepository extends JpaRepository<Footprint, Long> {

    List<Footprint> findBySpotIdOrderByCreatedAtDesc(Long spotId);

    List<Footprint> findByUserIdOrderByCreatedAtDesc(Long userId);

    /**
     * 중심 좌표 반경(m) 내 발자취를 가까운 순으로 조회한다(#115).
     *
     * <p>{@code spots.findWithinRadius} 와 같은 구조다 — {@code geom} 을 {@code geography} 로
     * 캐스팅해 반경을 도(degree)가 아닌 <b>미터</b>로 그대로 받고, {@code idx_footprints_geom}
     * (GiST)이 bbox 사전 필터로 쓰인다.</p>
     *
     * <p>{@code geom} 이 NULL 인 행(좌표 없음·이상치)은 자연히 빠진다.</p>
     *
     * <p>⚠️ {@code limit} 이 필수다. 한 지점에 글이 몰리면 반경이 좁아도 수천 건이 나올 수 있어,
     * 상한이 없으면 응답과 지도 렌더가 함께 무너진다.</p>
     */
    @Query(value = """
            SELECT * FROM footprints
            WHERE geom IS NOT NULL
              AND ST_DWithin(
                    geom::geography,
                    ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography,
                    :radiusMeters
                  )
            ORDER BY geom::geography <-> ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography
            LIMIT :limit
            """, nativeQuery = true)
    List<Footprint> findWithinRadius(@Param("lat") double lat,
                                     @Param("lng") double lng,
                                     @Param("radiusMeters") double radiusMeters,
                                     @Param("limit") int limit);

    /**
     * like_count를 원자적으로 증감한다(동시 좋아요 경합 방지를 위해 read-modify-write 대신 UPDATE 쿼리 사용).
     * 0 미만으로 내려가지 않도록 감소는 like_count > 0 조건을 건다.
     */
    @Modifying
    @Query("UPDATE Footprint f SET f.likeCount = f.likeCount + 1 WHERE f.id = :id")
    void incrementLikeCount(@Param("id") Long id);

    @Modifying
    @Query("UPDATE Footprint f SET f.likeCount = f.likeCount - 1 WHERE f.id = :id AND f.likeCount > 0")
    void decrementLikeCount(@Param("id") Long id);
}
