package com.fogapp.footprint;

import static org.assertj.core.api.Assertions.assertThat;

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
        Footprint saved = footprintRepository.save(new Footprint(userId, spotId, "첫 발자취", null));

        assertThat(saved.getId()).isNotNull();
        assertThat(saved.getLikeCount()).isZero();
        assertThat(saved.getCreatedAt()).isNotNull();
        assertThat(saved.getUpdatedAt()).isNotNull();
    }

    @Test
    void 스팟에_남긴_발자취를_최신순으로_조회한다() {
        footprintRepository.saveAndFlush(new Footprint(userId, spotId, "먼저 작성", null));
        footprintRepository.saveAndFlush(new Footprint(userId, spotId, "나중에 작성", null));

        List<Footprint> found = footprintRepository.findBySpotIdOrderByCreatedAtDesc(spotId);

        assertThat(found).extracting(Footprint::getContent).containsExactly("나중에 작성", "먼저 작성");
    }

    @Test
    void 유저별_발자취를_조회한다() {
        footprintRepository.save(new Footprint(userId, spotId, "내 발자취", null));

        List<Footprint> found = footprintRepository.findByUserIdOrderByCreatedAtDesc(userId);

        assertThat(found).hasSize(1);
        assertThat(found.get(0).getUserId()).isEqualTo(userId);
    }
}
