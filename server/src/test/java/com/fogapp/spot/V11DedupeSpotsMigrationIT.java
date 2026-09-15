package com.fogapp.spot;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;

import org.flywaydb.core.Flyway;
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
 * V11(좌표가 같은 스팟 합치기)을 <b>행이 있는 DB</b>에서 검증한다(#222 리뷰).
 *
 * <p>CI 의 Flyway 는 빈 DB 에 V1→V11 을 올리므로 V11 의 DELETE·UPDATE 는 전부 0행에 대해 돌고,
 * 초록은 「문법이 맞다」까지다. 여기서는 V10 까지만 올린 채 컨텍스트를 띄우고, 행을 심은 뒤 V11 을
 * 돌려 «무엇이 남고 무엇이 옮겨졌나»를 본다. 마지막 단언(좌표가 다른 스팟과 그 방문은 그대로)이
 * 제일 중요하다 — 「옮겼다」만 보면 DELETE 가 넓게 지워도 초록이다.</p>
 */
@Testcontainers
@SpringBootTest(properties = "spring.flyway.target=10")
class V11DedupeSpotsMigrationIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres =
            new PostgreSQLContainer<>(DockerImageName.parse("postgis/postgis:16-3.4")
                    .asCompatibleSubstituteFor("postgres"));

    @Autowired
    private JdbcTemplate jdbc;

    @Autowired
    private Flyway flyway;

    private static final double LAT = 37.4550873442;
    private static final double LNG = 126.7060989801;

    private long spot(String contentId, String typeId, String title, double lat, double lng) {
        return jdbc.queryForObject(
                "INSERT INTO spots (content_id, content_type_id, title, lat, lng) VALUES (?, ?, ?, ?, ?) RETURNING id",
                Long.class, contentId, typeId, title, lat, lng);
    }

    private long user(String uid) {
        return jdbc.queryForObject("INSERT INTO users (firebase_uid) VALUES (?) RETURNING id", Long.class, uid);
    }

    private void visit(long userId, long spotId) {
        jdbc.update("INSERT INTO visits (user_id, spot_id, photo_url, lat, lng) VALUES (?, ?, 'p', ?, ?)",
                userId, spotId, LAT, LNG);
    }

    @Test
    void 좌표가_같은_스팟은_행사가_아닌_쪽으로_합쳐지고_참조는_옮겨지며_다른_스팟은_그대로다() {
        // ── 심기 (V10 스키마) ──
        // 같은 좌표: 행사 B(id 가장 작음) + 타입 모름 D(id 작음) + 관광지 A(id 큼)
        // — «행사 아님»과 «타입 앎»이 id 보다 앞선다. B·D 의 id 를 일부러 작게 심어 「낮은 id」만으로는
        // A 가 못 이기게 한다.
        long eventB = spot("B", "15", "한복사랑 인천시민 놀이마당", LAT, LNG);
        long unknownD = spot("D", null, "타입 모름", LAT, LNG);
        long placeA = spot("A", "12", "인천애뜰", LAT, LNG);
        // 좌표가 다른 스팟 C — 배제 단언용
        long otherC = spot("C", "12", "모래내시장", 37.4569, 126.7205);
        // 또 다른 좌표: 문화시설 E(id 작음) + 관광지 F(id 큼) — 행사가 아닌 것끼리는 관광지가 남는다
        // (남산골공원 타임캡슐광장 14 vs 남산골한옥마을 12).
        long facilityE = spot("E", "14", "남산골공원서울천년타임캡슐광장", 37.5595, 126.9940);
        long placeF = spot("F", "12", "남산골한옥마을", 37.5595, 126.9940);

        long user1 = user("u1"); // B 만 인증
        long user2 = user("u2"); // A·B 둘 다 인증
        long user3 = user("u3"); // C 만 인증
        visit(user1, eventB);
        visit(user2, placeA);
        visit(user2, eventB);
        visit(user3, otherC);

        jdbc.update("INSERT INTO footprints (user_id, spot_id, content) VALUES (?, ?, '발자취')", user1, eventB);
        jdbc.update("INSERT INTO traveler_positions (user_id, nearest_spot_id) VALUES (?, ?)", user1, eventB);
        jdbc.update("INSERT INTO traveler_positions (user_id, nearest_spot_id) VALUES (?, ?)", user3, otherC);

        // ── V11 ──
        Flyway.configure()
                .configuration(flyway.getConfiguration())
                .target("11")
                .load()
                .migrate();

        // ── 남는 것: A(행사 B·타입 모름 D 는 없다), C, F(문화시설 E 는 없다) ──
        List<Long> remaining = jdbc.queryForList("SELECT id FROM spots ORDER BY id", Long.class);
        assertThat(remaining).containsExactly(placeA, otherC, placeF);
        assertThat(remaining).doesNotContain(eventB, unknownD, facilityE);

        // 사용자 1 의 방문은 A 로 옮겨졌다
        assertThat(jdbc.queryForList("SELECT spot_id FROM visits WHERE user_id = ?", Long.class, user1))
                .containsExactly(placeA);
        // 사용자 2 는 양쪽을 다 인증했으니 A 로 «1건»
        assertThat(jdbc.queryForList("SELECT spot_id FROM visits WHERE user_id = ?", Long.class, user2))
                .containsExactly(placeA);
        // 발자취·위치공유도 A 를 가리킨다
        assertThat(jdbc.queryForObject("SELECT spot_id FROM footprints WHERE user_id = ?", Long.class, user1))
                .isEqualTo(placeA);
        assertThat(jdbc.queryForObject(
                "SELECT nearest_spot_id FROM traveler_positions WHERE user_id = ?", Long.class, user1))
                .isEqualTo(placeA);

        // 🔴 배제: 좌표가 다른 C 와 그 방문·위치공유는 그대로
        assertThat(jdbc.queryForList("SELECT spot_id FROM visits WHERE user_id = ?", Long.class, user3))
                .containsExactly(otherC);
        assertThat(jdbc.queryForObject(
                "SELECT nearest_spot_id FROM traveler_positions WHERE user_id = ?", Long.class, user3))
                .isEqualTo(otherC);
        assertThat(jdbc.queryForObject("SELECT count(*) FROM visits", Long.class)).isEqualTo(3L);
    }
}
