package com.fogapp.visit;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface VisitRepository extends JpaRepository<Visit, Long> {

    /** 한 사용자당 스팟 1회 정복(#48). 유니크 제약에 걸리기 전에 미리 걸러 409를 명확히 돌려준다. */
    boolean existsByUserIdAndSpotId(Long userId, Long spotId);

    /** 고아 사진 판정(#76). 이 URL을 가리키는 인증 기록이 있으면 지우면 안 된다. */
    boolean existsByPhotoUrl(String photoUrl);

    /** 내 인증 목록(최신순). 3-5 안개 해제 영역 복원과 3-6 해금 판정이 소비한다. */
    List<Visit> findByUserIdOrderByVerifiedAtDesc(Long userId);

    /**
     * 인증 좌표가 스팟 반경(m) 안인지 DB에서 판정한다(#48 서버측 검증).
     *
     * <p>클라이언트 판정(#45)만 믿으면 좌표를 위조해 정복률을 조작할 수 있으므로,
     * 기록을 남기기 전에 서버가 같은 기준으로 한 번 더 확인한다.
     * spots.geom 의 GiST 인덱스를 쓰도록 spots 쪽을 geography 로 캐스팅한다.</p>
     *
     * <p>스팟의 geom 이 NULL(좌표 누락·이상치, V2 참고)이면 어떤 좌표로도 통과하지 못한다.</p>
     */
    @Query(value = """
            SELECT EXISTS (
                SELECT 1 FROM spots
                WHERE id = :spotId
                  AND geom IS NOT NULL
                  AND ST_DWithin(
                        geom::geography,
                        ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography,
                        :radiusMeters
                      )
            )
            """, nativeQuery = true)
    boolean isWithinSpotRadius(@Param("spotId") Long spotId,
                               @Param("lat") double lat,
                               @Param("lng") double lng,
                               @Param("radiusMeters") double radiusMeters);
}
