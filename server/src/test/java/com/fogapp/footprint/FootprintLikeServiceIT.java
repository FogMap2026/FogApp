package com.fogapp.footprint;

import static org.assertj.core.api.Assertions.assertThat;

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
 * 발자취 좋아요·공감(#23) — like_count 증감, 중복/미존재 좋아요 취소의 멱등성을 실제 PostGIS에 대해 검증한다.
 */
@Testcontainers
@SpringBootTest
class FootprintLikeServiceIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres =
            new PostgreSQLContainer<>(DockerImageName.parse("postgis/postgis:16-3.4")
                    .asCompatibleSubstituteFor("postgres"));

    @Autowired
    private FootprintLikeService footprintLikeService;

    @Autowired
    private FootprintRepository footprintRepository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    private Long userA;
    private Long userB;
    private Long footprintId;

    @BeforeEach
    void setUp() {
        userA = createUser();
        userB = createUser();
        Long spotId = jdbcTemplate.queryForObject(
                "INSERT INTO spots (content_id, title) VALUES (?, ?) RETURNING id",
                Long.class, "content-" + System.nanoTime(), "테스트 스팟");
        footprintId = footprintRepository.save(new Footprint(userA, spotId, "발자취", null)).getId();
    }

    private Long createUser() {
        return jdbcTemplate.queryForObject(
                "INSERT INTO users (firebase_uid) VALUES (?) RETURNING id",
                Long.class, "test-uid-" + System.nanoTime() + "-" + Math.random());
    }

    private int likeCount() {
        return footprintRepository.findById(footprintId).orElseThrow().getLikeCount();
    }

    @Test
    void 좋아요를_누르면_카운트가_증가한다() {
        footprintLikeService.like(footprintId, userA);

        assertThat(likeCount()).isEqualTo(1);
    }

    @Test
    void 같은_사용자가_두_번_좋아요해도_카운트는_한_번만_증가한다() {
        footprintLikeService.like(footprintId, userA);
        footprintLikeService.like(footprintId, userA);

        assertThat(likeCount()).isEqualTo(1);
    }

    @Test
    void 서로_다른_사용자의_좋아요는_각각_카운트된다() {
        footprintLikeService.like(footprintId, userA);
        footprintLikeService.like(footprintId, userB);

        assertThat(likeCount()).isEqualTo(2);
    }

    @Test
    void 좋아요_취소하면_카운트가_감소한다() {
        footprintLikeService.like(footprintId, userA);

        footprintLikeService.unlike(footprintId, userA);

        assertThat(likeCount()).isZero();
    }

    @Test
    void 좋아요하지_않은_상태에서_취소해도_에러없이_무시되고_카운트는_0_밑으로_내려가지_않는다() {
        footprintLikeService.unlike(footprintId, userA);

        assertThat(likeCount()).isZero();
    }
}
