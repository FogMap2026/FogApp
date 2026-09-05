package com.fogapp.spot;

import java.util.List;
import java.util.Optional;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface SpotRepository extends JpaRepository<Spot, Long> {

    /** 지역 코드별 스팟 조회(#7). 지도가 지역 단위로 로드할 때 사용. */
    Page<Spot> findByAreaCode(String areaCode, Pageable pageable);

    /** 수집 배치(#5)의 중복 적재 방지·업서트용 조회. content_id 는 유니크. */
    Optional<Spot> findByContentId(String contentId);

    /**
     * 소개글을 <b>아직 조회하지 않은</b> 스팟(#100). 상세조회로 채울 대상을 고른다.
     *
     * <p>상세는 스팟 1건당 1회 호출이라 비싸다 — 이미 조회한 것을 제외해 재실행이 남은 것만
     * 집어가게 하고, {@code limit} 으로 한 번에 쓰는 호출량을 묶는다.</p>
     *
     * <p><b>{@code NULL} 만 대상이다. 빈 문자열은 제외한다.</b> 둘은 뜻이 다르다 —
     * {@code NULL} 은 "아직 안 불러봤다", 빈 문자열은 <b>"불러봤는데 관광공사에 소개글이
     * 없다"</b>는 표식이다({@code SpotOverviewWriter}가 그렇게 기록한다).</p>
     *
     * <p>구분하지 않으면 소개글이 원래 없는 스팟이 <b>매 실행 대상에 다시 들어와</b>
     * 채워지지도 않으면서 호출만 태운다. 그런 스팟이 쌓여 {@code limit} 에 도달하면
     * 창이 그들로만 채워져 <b>배치가 조용히 멈춘다</b> — 로그는 "대상 200, 채움 0" 만
     * 반복해 다 채워진 것과 구분되지 않는다.</p>
     */
    @Query(value = "SELECT * FROM spots WHERE overview IS NULL "
            + "ORDER BY id LIMIT :limit", nativeQuery = true)
    List<Spot> findWithoutOverview(@Param("limit") int limit);

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
