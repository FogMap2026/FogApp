package com.fogapp.traveler;

import java.time.OffsetDateTime;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface TravelerPositionRepository extends JpaRepository<TravelerPosition, Long> {

    /**
     * 위치를 게시한다(#133). <b>UPSERT다</b> — 신고 접수본이 "이전 공개 위치정보는
     * 갱신 시 삭제 또는 덮어쓰기"라고 못 박았다. {@code INSERT} 만 쓰면 과거 위치가
     * 쌓여 접수본과 어긋난다.
     */
    @Modifying
    @Transactional
    @Query(value = """
            INSERT INTO traveler_positions (user_id, nearest_spot_id, updated_at)
            VALUES (:userId, :nearestSpotId, now())
            ON CONFLICT (user_id)
            DO UPDATE SET nearest_spot_id = EXCLUDED.nearest_spot_id, updated_at = now()
            """, nativeQuery = true)
    void upsert(@Param("userId") Long userId, @Param("nearestSpotId") Long nearestSpotId);

    /** 공유를 끈다(#133). 행이 없으면(이미 꺼져 있으면) 조용히 넘어간다. */
    void deleteByUserId(Long userId);

    /**
     * 반경 내, <b>30분 이상 지난</b> 남의 위치를 스팟 단위로 조회한다.
     *
     * <p>{@code cutoff} 이후(=최근 30분 이내)는 조회에서 뺀다 — 신고 접수본의
     * "측정 시점으로부터 30분이 경과한 위치정보만 지연하여 제공"을 만족한다.
     * {@code excludeUserId} 로 본인은 뺀다 — 내 캐릭터가 이중으로 안 뜬다.</p>
     *
     * <p>{@code spots.geom} 의 geography GiST 인덱스(V7)를 타도록 반경 판정을
     * spots 쪽에서 한다 — {@code traveler_positions} 은 스팟 id 만 들고 있다.</p>
     */
    @Query(value = """
            SELECT tp.nearest_spot_id AS spotId, s.lat AS lat, s.lng AS lng, tp.updated_at AS seenAt
            FROM traveler_positions tp
            JOIN spots s ON s.id = tp.nearest_spot_id
            WHERE tp.user_id != :excludeUserId
              AND tp.updated_at <= :cutoff
              AND s.geom IS NOT NULL
              AND ST_DWithin(
                    s.geom::geography,
                    ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography,
                    :radiusMeters
                  )
            """, nativeQuery = true)
    List<NearbyTravelerRow> findNearby(@Param("excludeUserId") Long excludeUserId,
                                        @Param("lat") double lat,
                                        @Param("lng") double lng,
                                        @Param("radiusMeters") double radiusMeters,
                                        @Param("cutoff") OffsetDateTime cutoff);

    /**
     * {@link #findNearby} 의 네이티브 프로젝션. 응답에 {@code userId} 를 담지 않는다 —
     * 익명이 여기서부터 지켜진다. {@code lat}/{@code lng} 는 <b>여행자 본인의 좌표가
     * 아니라 스팟의 좌표</b>다 — 스팟 위치는 원래 공개 정보라 앱이 다시 조회할 필요
     * 없이 바로 마커를 그릴 수 있게 같이 내려준다.
     */
    interface NearbyTravelerRow {
        Long getSpotId();
        double getLat();
        double getLng();
        OffsetDateTime getSeenAt();
    }
}
