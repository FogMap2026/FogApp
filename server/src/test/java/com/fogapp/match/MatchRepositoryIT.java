package com.fogapp.match;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

/**
 * matches 테이블(#1-8) 기본 CRUD·제약조건 동작을 실제 PostGIS에 대해 검증한다.
 */
@Testcontainers
@SpringBootTest
class MatchRepositoryIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres =
            new PostgreSQLContainer<>(DockerImageName.parse("postgis/postgis:16-3.4")
                    .asCompatibleSubstituteFor("postgres"));

    @Autowired
    private MatchRepository matchRepository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    private Long userA;
    private Long userB;
    private Long userC;

    @BeforeEach
    void setUp() {
        userA = createUser();
        userB = createUser();
        userC = createUser();
    }

    private Long createUser() {
        return jdbcTemplate.queryForObject(
                "INSERT INTO users (firebase_uid) VALUES (?) RETURNING id",
                Long.class, "test-uid-" + System.nanoTime() + "-" + Math.random());
    }

    @Test
    void 매칭_요청을_저장하면_기본_상태는_pending이다() {
        Match saved = matchRepository.save(new Match(userA, userB));

        assertThat(saved.getStatus()).isEqualTo(Match.STATUS_PENDING);
        assertThat(saved.getCreatedAt()).isNotNull();
    }

    @Test
    void 자기_자신에게는_매칭을_요청할_수_없다() {
        assertThatThrownBy(() -> new Match(userA, userA))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void 동일한_요청자_대상자_조합은_중복_저장할_수_없다() {
        matchRepository.saveAndFlush(new Match(userA, userB));

        assertThatThrownBy(() -> matchRepository.saveAndFlush(new Match(userA, userB)))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void 요청자_또는_대상자로_참여한_매칭을_모두_조회한다() {
        matchRepository.save(new Match(userA, userB));
        matchRepository.save(new Match(userC, userA));
        matchRepository.save(new Match(userB, userC));

        List<Match> found = matchRepository.findAllInvolvingUser(userA);

        assertThat(found).hasSize(2);
    }
}
