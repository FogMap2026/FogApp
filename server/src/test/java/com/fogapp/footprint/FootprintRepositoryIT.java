package com.fogapp.footprint;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.within;

import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.jdbc.core.JdbcTemplate;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

/**
 * footprints 테이블(#1-8) 기본 CRUD·조회 동작을 실제 PostGIS에 대해 검증한다.
 */
@Testcontainers
@SpringBootTest
class FootprintRepositoryIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres =
            new PostgreSQLContainer<>(DockerImageName.parse("postgis/postgis:16-3.4")
                    .asCompatibleSubstituteFor("postgres"));

    @Autowired
    private FootprintRepository footprintRepository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    private Long userId;
    private Long spotId;

    @BeforeEach
    void setUp() {
        userId = jdbcTemplate.queryForObject(
                "INSERT INTO users (firebase_uid) VALUES (?) RETURNING id",
                Long.class, "test-uid-" + System.nanoTime());
        spotId = jdbcTemplate.queryForObject(
                "INSERT INTO spots (content_id, title) VALUES (?, ?) RETURNING id",
                Long.class, "content-" + System.nanoTime(), "테스트 스팟");
    }

    @Test
    void 발자취를_저장하면_생성시각과_좋아요수_기본값이_채워진다() {
        Footprint saved = footprintRepository.save(new Footprint(userId, spotId, "첫 발자취", null, 37.5665, 126.9780));

        assertThat(saved.getId()).isNotNull();
        assertThat(saved.getLikeCount()).isZero();
        assertThat(saved.getCreatedAt()).isNotNull();
        assertThat(saved.getUpdatedAt()).isNotNull();
    }

    @Test
    void 스팟에_남긴_발자취를_최신순으로_조회한다() {
        footprintRepository.saveAndFlush(new Footprint(userId, spotId, "먼저 작성", null, 37.5665, 126.9780));
        footprintRepository.saveAndFlush(new Footprint(userId, spotId, "나중에 작성", null, 37.5665, 126.9780));

        List<Footprint> found = footprintRepository.findBySpotIdOrderByCreatedAtDesc(spotId);

        assertThat(found).extracting(Footprint::getContent).containsExactly("나중에 작성", "먼저 작성");
    }

    @Test
    void 유저별_발자취를_조회한다() {
        footprintRepository.save(new Footprint(userId, spotId, "내 발자취", null, 37.5665, 126.9780));

        List<Footprint> found = footprintRepository.findByUserIdOrderByCreatedAtDesc(userId);

        assertThat(found).hasSize(1);
        assertThat(found.get(0).getUserId()).isEqualTo(userId);
    }

    // ── geom 자동 채움 (#114) ────────────────────────────────────────────

    @Test
    void 좌표를_넣으면_트리거가_geom을_채운다() {
        // geom 은 애플리케이션이 아니라 DB 트리거가 채운다(V5) — 작성 경로가 늘어나도
        // 좌표 생성 로직이 한 곳에만 있어야 누락이 안 생긴다.
        Long id = footprintRepository.saveAndFlush(
                new Footprint(userId, spotId, "여기 계단 힘들다", null, 37.5759, 126.9769)).getId();

        Double lng = jdbcTemplate.queryForObject(
                "SELECT ST_X(geom) FROM footprints WHERE id = ?", Double.class, id);
        Double lat = jdbcTemplate.queryForObject(
                "SELECT ST_Y(geom) FROM footprints WHERE id = ?", Double.class, id);

        assertThat(lng).isCloseTo(126.9769, within(1e-6));
        assertThat(lat).isCloseTo(37.5759, within(1e-6));
    }

    @Test
    void 좌표가_없으면_geom도_비어_있다() {
        // 좌표 없는 글도 저장은 된다 — 스팟 상세 목록에는 남고 반경 조회에서만 빠진다.
        Long id = footprintRepository.saveAndFlush(
                new Footprint(userId, spotId, "좌표 없는 글", null, null, null)).getId();

        assertThat(jdbcTemplate.queryForObject(
                "SELECT geom IS NULL FROM footprints WHERE id = ?", Boolean.class, id)).isTrue();
    }

    @Test
    void 좌표가_범위를_벗어나면_행은_남고_geom만_비운다() {
        // 글 자체는 사용자가 쓴 것이라 좌표가 이상하다고 버리면 안 된다.
        // geom 이 NULL 이면 반경 조회에서 자연히 빠진다.
        Long id = footprintRepository.saveAndFlush(
                new Footprint(userId, spotId, "이상치 좌표", null, 999.0, 999.0)).getId();

        assertThat(footprintRepository.findById(id)).isPresent();
        assertThat(jdbcTemplate.queryForObject(
                "SELECT geom IS NULL FROM footprints WHERE id = ?", Boolean.class, id)).isTrue();
    }

    @Test
    void 좌표를_수정하면_geom도_따라_바뀐다() {
        Long id = footprintRepository.saveAndFlush(
                new Footprint(userId, spotId, "옮길 글", null, 37.5, 127.0)).getId();

        jdbcTemplate.update("UPDATE footprints SET lat = ?, lng = ? WHERE id = ?", 35.1796, 129.0756, id);

        assertThat(jdbcTemplate.queryForObject(
                "SELECT ST_Y(geom) FROM footprints WHERE id = ?", Double.class, id))
                .isCloseTo(35.1796, within(1e-6));
    }
}
