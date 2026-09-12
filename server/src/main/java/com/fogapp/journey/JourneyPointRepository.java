package com.fogapp.journey;

import java.time.OffsetDateTime;
import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface JourneyPointRepository extends JpaRepository<JourneyPoint, Long> {

    /**
     * 내 궤적을 시간순으로. {@code idx_journey_points_user_time} 을 탄다.
     *
     * <p>상한을 둔다 — 오래 쓴 계정이 수만 점을 쌓으면 지도 진입이 그만큼 느려진다.
     * 안개 복원은 «최근에 어디를 걸었는가» 면 충분하다.</p>
     *
     * <p>🔴 {@code CAST(:from AS timestamptz)} 를 <b>지우지 말 것</b>. {@code :from IS NULL} 만
     * 쓰면 Postgres 가 그 자리의 자리표시자 타입을 정할 근거가 없어
     * <i>could not determine data type of parameter</i> 로 <b>질의 자체가 거절된다</b> —
     * 값이 null 이든 아니든 한 번도 안 돈다. CI 가 이걸 잡았다(#131).</p>
     */
    @Query(value = """
            SELECT * FROM journey_points
             WHERE user_id = :userId
               AND (CAST(:from AS timestamptz) IS NULL OR recorded_at >= CAST(:from AS timestamptz))
               AND (CAST(:to   AS timestamptz) IS NULL OR recorded_at <= CAST(:to   AS timestamptz))
             ORDER BY recorded_at DESC
             LIMIT :limit
            """, nativeQuery = true)
    List<JourneyPoint> findMine(@Param("userId") Long userId,
                                @Param("from") OffsetDateTime from,
                                @Param("to") OffsetDateTime to,
                                @Param("limit") int limit);

    /**
     * 한 점을 넣되 <b>이미 있으면 조용히 넘어간다</b>(#131).
     *
     * <p>🔑 batch 업로드는 재전송이 일어난다 — 네트워크가 끊겼다 붙으면 앱이 같은 묶음을
     * 다시 보낸다. {@code (user_id, recorded_at)} 유니크에 {@code ON CONFLICT DO NOTHING}
     * 을 걸어 <b>서버가 멱등을 보장</b>한다. 앱에서 「이미 보냈는지」를 추적하는 것보다
     * 훨씬 싸고, 앱이 재전송을 마음 편히 할 수 있다.</p>
     *
     * <p>JPA {@code save} 를 쓰지 않는 이유이기도 하다 — 유니크 충돌이 예외로 튀면
     * 묶음 전체가 롤백되어 <b>한 점 때문에 나머지가 다 버려진다.</b></p>
     *
     * @return 실제로 들어간 행 수 (0 이면 이미 있던 점)
     */
    @Modifying
    @Query(value = """
            INSERT INTO journey_points (user_id, lat, lng, recorded_at)
            VALUES (:userId, :lat, :lng, :recordedAt)
            ON CONFLICT (user_id, recorded_at) DO NOTHING
            """, nativeQuery = true)
    int insertIgnoringDuplicate(@Param("userId") Long userId,
                                @Param("lat") double lat,
                                @Param("lng") double lng,
                                @Param("recordedAt") OffsetDateTime recordedAt);
}
