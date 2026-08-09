package com.fogapp.visit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.concurrent.atomic.AtomicInteger;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.server.ResponseStatusException;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

import com.fogapp.common.NotFoundException;
import com.fogapp.spot.Spot;
import com.fogapp.spot.SpotRepository;
import com.fogapp.user.User;
import com.fogapp.user.UserRepository;

/**
 * 방문 인증(#48)을 실제 PostGIS로 검증한다.
 * 반경 판정이 DB(ST_DWithin)에서 이뤄지므로 컨테이너 없이는 의미 있는 검증이 되지 않는다.
 */
@Testcontainers
@SpringBootTest
class VisitServiceIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres =
            new PostgreSQLContainer<>(DockerImageName.parse("postgis/postgis:16-3.4")
                    .asCompatibleSubstituteFor("postgres"));

    /** @SpringBootTest 는 메서드 간 롤백이 없어 데이터가 공유된다 — 매번 새 식별자를 쓴다. */
    private static final AtomicInteger SEQ = new AtomicInteger();

    // 광화문 광장 기준. 반경 밖 좌표는 여기서 충분히 떨어뜨린다.
    private static final double SPOT_LAT = 37.5759;
    private static final double SPOT_LNG = 126.9769;

    @Autowired
    private VisitService visitService;

    @Autowired
    private VisitRepository visitRepository;

    @Autowired
    private SpotRepository spotRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    private Spot newSpot(Double lat, Double lng) {
        int n = SEQ.incrementAndGet();
        return spotRepository.save(new Spot(
                "VISIT-IT-" + n, "12", "인증테스트-" + n, "주소", null,
                "1", "1", null, null, null, null, lat, lng));
    }

    private User newUser() {
        int n = SEQ.incrementAndGet();
        return userRepository.save(new User("visit-it-uid-" + n, "u" + n + "@test.io", "탐험가" + n, null));
    }

    @Test
    void 반경_안에서_인증하면_기록이_남는다() {
        User user = newUser();
        Spot spot = newSpot(SPOT_LAT, SPOT_LNG);

        // 스팟에서 약 20m 떨어진 지점 (위도 0.0002도 ≈ 22m)
        Visit visit = visitService.verify(user.getId(), user.getFirebaseUid(), spot.getId(), "https://storage/photo.jpg", SPOT_LAT + 0.0002, SPOT_LNG);

        assertThat(visit.getId()).isNotNull();
        assertThat(visit.getUserId()).isEqualTo(user.getId());
        assertThat(visit.getSpotId()).isEqualTo(spot.getId());
        assertThat(visit.getVerifiedAt()).isNotNull();
    }

    @Test
    void 인증하면_geom이_트리거로_채워진다() {
        User user = newUser();
        Spot spot = newSpot(SPOT_LAT, SPOT_LNG);

        Visit visit = visitService.verify(user.getId(), user.getFirebaseUid(), spot.getId(), "https://storage/photo.jpg", SPOT_LAT, SPOT_LNG);

        // V4 트리거가 lat/lng 로부터 geom 을 채웠는지 (애플리케이션은 geom 을 건드리지 않는다)
        Boolean filled = jdbcTemplate.queryForObject(
                "SELECT geom IS NOT NULL FROM visits WHERE id = ?", Boolean.class, visit.getId());
        assertThat(filled).isTrue();
    }

    @Test
    void 반경_밖에서는_인증할_수_없다() {
        User user = newUser();
        Spot spot = newSpot(SPOT_LAT, SPOT_LNG);

        // 부산 — 반경(기본 100m) 밖
        assertThatThrownBy(() -> visitService.verify(user.getId(), user.getFirebaseUid(), spot.getId(), "https://storage/photo.jpg", 35.1796, 129.0756))
                .isInstanceOfSatisfying(ResponseStatusException.class,
                        e -> assertThat(e.getStatusCode()).isEqualTo(HttpStatus.UNPROCESSABLE_ENTITY));

        assertThat(visitRepository.existsByUserIdAndSpotId(user.getId(), spot.getId())).isFalse();
    }

    @Test
    void 같은_스팟을_두_번_인증할_수_없다() {
        User user = newUser();
        Spot spot = newSpot(SPOT_LAT, SPOT_LNG);
        visitService.verify(user.getId(), user.getFirebaseUid(), spot.getId(), "https://storage/1.jpg", SPOT_LAT, SPOT_LNG);

        assertThatThrownBy(() -> visitService.verify(user.getId(), user.getFirebaseUid(), spot.getId(), "https://storage/2.jpg", SPOT_LAT, SPOT_LNG))
                .isInstanceOfSatisfying(ResponseStatusException.class,
                        e -> assertThat(e.getStatusCode()).isEqualTo(HttpStatus.CONFLICT));
    }

    @Test
    void 다른_사용자는_같은_스팟을_인증할_수_있다() {
        Spot spot = newSpot(SPOT_LAT, SPOT_LNG);
        User first = newUser();
        User second = newUser();

        visitService.verify(first.getId(), first.getFirebaseUid(), spot.getId(), "https://storage/1.jpg", SPOT_LAT, SPOT_LNG);
        Visit other = visitService.verify(second.getId(), second.getFirebaseUid(), spot.getId(), "https://storage/2.jpg", SPOT_LAT, SPOT_LNG);

        assertThat(other.getId()).isNotNull();
    }

    @Test
    void 없는_스팟은_404다() {
        User user = newUser();

        assertThatThrownBy(() -> visitService.verify(user.getId(), user.getFirebaseUid(), 999_999_999L, "https://storage/photo.jpg", SPOT_LAT, SPOT_LNG))
                .isInstanceOf(NotFoundException.class);
    }

    @Test
    void 좌표가_없는_스팟은_인증할_수_없다() {
        User user = newUser();
        Spot spot = newSpot(null, null); // geom 이 NULL 로 남는다 (V2 규칙)

        assertThatThrownBy(() -> visitService.verify(user.getId(), user.getFirebaseUid(), spot.getId(), "https://storage/photo.jpg", SPOT_LAT, SPOT_LNG))
                .isInstanceOfSatisfying(ResponseStatusException.class,
                        e -> assertThat(e.getStatusCode()).isEqualTo(HttpStatus.UNPROCESSABLE_ENTITY));
    }

    @Test
    void 범위를_벗어난_좌표는_400이다() {
        User user = newUser();
        Spot spot = newSpot(SPOT_LAT, SPOT_LNG);

        // PostGIS geography 캐스팅까지 가면 500 이 되므로 서비스가 먼저 걸러야 한다.
        assertThatThrownBy(() -> visitService.verify(user.getId(), user.getFirebaseUid(), spot.getId(), "https://storage/photo.jpg", 200.0, 500.0))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void 내_인증_목록을_최신순으로_조회한다() {
        User user = newUser();
        Spot a = newSpot(SPOT_LAT, SPOT_LNG);
        Spot b = newSpot(SPOT_LAT, SPOT_LNG);

        visitService.verify(user.getId(), user.getFirebaseUid(), a.getId(), "https://storage/a.jpg", SPOT_LAT, SPOT_LNG);
        visitService.verify(user.getId(), user.getFirebaseUid(), b.getId(), "https://storage/b.jpg", SPOT_LAT, SPOT_LNG);

        assertThat(visitService.listByUser(user.getId()))
                .hasSize(2)
                .extracting(Visit::getSpotId)
                .containsExactlyInAnyOrder(a.getId(), b.getId());
    }
}
