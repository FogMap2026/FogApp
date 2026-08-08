package com.fogapp.match;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.offset;

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
 * 매칭 요청 시 성향 유사도 자동 계산과 후보 추천(#37)을 실제 PostGIS에 대해 검증한다.
 */
@Testcontainers
@SpringBootTest
class MatchServiceIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres =
            new PostgreSQLContainer<>(DockerImageName.parse("postgis/postgis:16-3.4")
                    .asCompatibleSubstituteFor("postgres"));

    @Autowired
    private MatchService matchService;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    void cleanUpUsers() {
        // recommendCandidates()는 users 테이블 전체를 훑으므로, 테스트 간 간섭을 막기 위해 매번 비운다.
        // matches 등 자식 테이블은 ON DELETE CASCADE로 함께 정리된다.
        jdbcTemplate.update("DELETE FROM users");
    }

    private Long createUser(String nickname, Integer spontaneity, Integer restVsRoam, Integer extraversion) {
        Long id = jdbcTemplate.queryForObject(
                "INSERT INTO users (firebase_uid, nickname) VALUES (?, ?) RETURNING id",
                Long.class, "test-uid-" + System.nanoTime() + "-" + Math.random(), nickname);

        if (spontaneity != null) {
            String scoresJson = """
                    {"version":1,"axes":{
                      "spontaneity":{"score":%d,"pole":"P"},
                      "restVsRoam":{"score":%d,"pole":"R"},
                      "extraversion":{"score":%d,"pole":"I"}
                    }}
                    """.formatted(spontaneity, restVsRoam, extraversion);
            jdbcTemplate.update(
                    "UPDATE users SET personality_type = ?, personality_scores = ?::jsonb WHERE id = ?",
                    "PRI", scoresJson, id);
        }
        return id;
    }

    @Test
    void 둘_다_성향_데이터가_있으면_매칭_요청시_유사도가_자동_계산된다() {
        Long userA = createUser("A", 50, 50, 50);
        Long userB = createUser("B", 50, 50, 50);

        Match match = matchService.request(userA, userB);

        assertThat(match.getScore()).isNotNull();
        assertThat(match.getScore()).isCloseTo(1.0, offset(0.0001));
    }

    @Test
    void 한쪽이라도_성향_데이터가_없으면_score는_null이다() {
        Long userA = createUser("A", 50, 50, 50);
        Long userB = createUser("B", null, null, null);

        Match match = matchService.request(userA, userB);

        assertThat(match.getScore()).isNull();
    }

    @Test
    void 후보_추천은_유사도_높은_순으로_정렬되고_본인과_미응답자는_제외한다() {
        Long me = createUser("me", 50, 50, 50);
        Long close = createUser("close", 55, 50, 50);
        Long far = createUser("far", 100, 0, 100);
        createUser("no-personality", null, null, null);

        List<MatchCandidate> candidates = matchService.recommendCandidates(me, 10);

        assertThat(candidates).extracting(MatchCandidate::userId).containsExactly(close, far);
    }

    @Test
    void 본인이_성향_테스트를_안했으면_추천_결과가_비어있다() {
        Long me = createUser("me", null, null, null);
        createUser("other", 50, 50, 50);

        List<MatchCandidate> candidates = matchService.recommendCandidates(me, 10);

        assertThat(candidates).isEmpty();
    }

    @Test
    void limit만큼만_후보를_반환한다() {
        Long me = createUser("me", 50, 50, 50);
        for (int i = 0; i < 5; i++) {
            createUser("candidate-" + i, 50 + i, 50, 50);
        }

        List<MatchCandidate> candidates = matchService.recommendCandidates(me, 2);

        assertThat(candidates).hasSize(2);
    }
}
