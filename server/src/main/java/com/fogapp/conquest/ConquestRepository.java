package com.fogapp.conquest;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.fogapp.spot.Spot;

public interface ConquestRepository extends JpaRepository<Spot, Long> {

    /**
     * 지역별 정복률 집계(#51). 지역 단위는 <b>시/군/구</b>다(팀 결정).
     *
     * <p>시/도 단위는 분모가 너무 커서 정복률이 거의 오르지 않는다 — 서울 전체가 한 지역이면
     * 수천 개 스팟이 분모가 된다. 시/군/구는 "경주 15%" 처럼 즉각적인 성취감을 준다.</p>
     *
     * <p>{@code LEFT JOIN visits} 의 {@code user_id} 조건은 반드시 <b>ON 절에</b> 둔다 —
     * WHERE 로 내리면 아직 방문하지 않은 지역이 결과에서 통째로 빠져 분모가 사라진다.</p>
     *
     * <p>지역 이름은 별도 코드 테이블 없이 {@code addr1} 의 앞 두 토큰에서 뽑는다.
     * 한 그룹의 스팟은 같은 행정구역이라 접두사가 같으므로 {@code MIN} 으로 대표값을 취한다.</p>
     */
    @Query(value = """
            SELECT s.area_code AS "areaCode",
                   s.sigungu_code AS "sigunguCode",
                   MIN(split_part(COALESCE(s.addr1, ''), ' ', 1)) AS "sidoName",
                   MIN(split_part(COALESCE(s.addr1, ''), ' ', 2)) AS "sigunguName",
                   COUNT(*) AS "totalSpots",
                   COUNT(v.id) AS "visitedSpots"
            FROM spots s
            LEFT JOIN visits v ON v.spot_id = s.id AND v.user_id = :userId
            WHERE s.area_code IS NOT NULL
            GROUP BY s.area_code, s.sigungu_code
            ORDER BY s.area_code, s.sigungu_code
            """, nativeQuery = true)
    List<ConquestRow> aggregate(@Param("userId") Long userId);
}
