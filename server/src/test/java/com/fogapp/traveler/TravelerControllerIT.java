package com.fogapp.traveler;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

import com.fogapp.auth.TokenVerifier;
import com.fogapp.auth.VerifiedToken;

/**
 * 주변 여행자 익명 표시(#133, 6-3).
 *
 * <p>여기서 지키는 셋 — 신고 접수본(09-10)이 그대로 구속 조건이다.</p>
 * <ul>
 *   <li><b>opt-in</b> — 게시한 적 없으면 조회에 안 뜬다</li>
 *   <li><b>30분 지연</b> — 방금 게시한 건 «본인 제외 전에도» 안 뜬다</li>
 *   <li><b>익명</b> — 응답에 {@code userId}·닉네임이 없다</li>
 * </ul>
 */
@Testcontainers
@SpringBootTest
@AutoConfigureMockMvc
class TravelerControllerIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres =
            new PostgreSQLContainer<>(DockerImageName.parse("postgis/postgis:16-3.4")
                    .asCompatibleSubstituteFor("postgres"));

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @MockBean
    private TokenVerifier tokenVerifier;

    @BeforeEach
    void cleanUpUsers() {
        // radiusMeters=5000로 조회하기 때문에 테스트마다 좌표를 0.01도씩만 떨어뜨려도
        // 서로의 반경 안에 들어온다. 이전 테스트의 traveler_positions가 남아 있으면
        // 이번 테스트의 nearby 조회에 섞여 든다 — user_id FK의 ON DELETE CASCADE로
        // 함께 정리되도록 매번 users를 비운다.
        jdbcTemplate.update("DELETE FROM users");
    }

    private void loginAs(String token, String uid) {
        given(tokenVerifier.verify(token)).willReturn(new VerifiedToken(uid, uid + "@example.com", null, null));
    }

    private Long signUp(String token, String uid) throws Exception {
        loginAs(token, uid);
        mockMvc.perform(get("/api/profile").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk());
        return jdbcTemplate.queryForObject(
                "SELECT id FROM users WHERE firebase_uid = ?", Long.class, uid);
    }

    private Long createSpot(double lat, double lng) {
        return jdbcTemplate.queryForObject(
                "INSERT INTO spots (content_id, title, lat, lng) VALUES (?, ?, ?, ?) RETURNING id",
                Long.class, "trv-" + System.nanoTime(), "여행자 테스트 스팟", lat, lng);
    }

    /** 방금 게시한 위치를 조회 창(30분) 밖으로 밀어낸다 — "예전에 게시한 것"을 재현한다. */
    private void ageToPast(Long userId, int minutesAgo) {
        jdbcTemplate.update(
                "UPDATE traveler_positions SET updated_at = now() - (? || ' minutes')::interval WHERE user_id = ?",
                minutesAgo, userId);
    }

    @Test
    void 방금_게시한_위치는_30분_텀_때문에_아직_안_보인다() throws Exception {
        Long alice = signUp("trv-alice", "uid-trv-alice");
        Long bob = signUp("trv-bob", "uid-trv-bob");
        Long spot = createSpot(37.50, 127.00);

        mockMvc.perform(post("/api/travelers/position")
                        .header("Authorization", "Bearer trv-alice")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"lat\":37.50,\"lng\":127.00}"))
                .andExpect(status().isNoContent());

        // bob이 같은 자리에서 조회 — alice가 방금 켰으니 아직 30분이 안 지났다.
        mockMvc.perform(get("/api/travelers/nearby")
                        .header("Authorization", "Bearer trv-bob")
                        .param("lat", "37.50").param("lng", "127.00").param("radiusMeters", "5000"))
                .andExpect(status().isOk())
                .andExpect(content().json("[]"));

        assertThat(alice).isNotNull();
        assertThat(spot).isNotNull();
    }

    @Test
    void 삼십분_지나면_스팟_id로만_보이고_userId는_없다() throws Exception {
        Long alice = signUp("trv-alice2", "uid-trv-alice2");
        signUp("trv-bob2", "uid-trv-bob2");
        Long spot = createSpot(37.51, 127.01);

        mockMvc.perform(post("/api/travelers/position")
                        .header("Authorization", "Bearer trv-alice2")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"lat\":37.51,\"lng\":127.01}"))
                .andExpect(status().isNoContent());
        ageToPast(alice, 40);

        mockMvc.perform(get("/api/travelers/nearby")
                        .header("Authorization", "Bearer trv-bob2")
                        .param("lat", "37.51").param("lng", "127.01").param("radiusMeters", "5000"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", org.hamcrest.Matchers.hasSize(1)))
                .andExpect(jsonPath("$[0].spotId").value(spot))
                .andExpect(jsonPath("$[0].userId").doesNotExist())
                .andExpect(jsonPath("$[0].seenAt").exists());
    }

    @Test
    void 내_위치는_내_조회에서_빠진다() throws Exception {
        Long alice = signUp("trv-alice3", "uid-trv-alice3");
        createSpot(37.52, 127.02);

        mockMvc.perform(post("/api/travelers/position")
                        .header("Authorization", "Bearer trv-alice3")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"lat\":37.52,\"lng\":127.02}"))
                .andExpect(status().isNoContent());
        ageToPast(alice, 40);

        mockMvc.perform(get("/api/travelers/nearby")
                        .header("Authorization", "Bearer trv-alice3")
                        .param("lat", "37.52").param("lng", "127.02").param("radiusMeters", "5000"))
                .andExpect(status().isOk())
                .andExpect(content().json("[]"));
    }

    @Test
    void 두_번_게시해도_행이_하나다_UPSERT() throws Exception {
        Long alice = signUp("trv-alice4", "uid-trv-alice4");
        createSpot(37.53, 127.03);
        Long spot2 = createSpot(37.531, 127.031);

        mockMvc.perform(post("/api/travelers/position")
                        .header("Authorization", "Bearer trv-alice4")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"lat\":37.53,\"lng\":127.03}"))
                .andExpect(status().isNoContent());
        mockMvc.perform(post("/api/travelers/position")
                        .header("Authorization", "Bearer trv-alice4")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"lat\":37.531,\"lng\":127.031}"))
                .andExpect(status().isNoContent());

        Integer rows = jdbcTemplate.queryForObject(
                "SELECT count(*) FROM traveler_positions WHERE user_id = ?", Integer.class, alice);
        assertThat(rows).isEqualTo(1);

        Long stored = jdbcTemplate.queryForObject(
                "SELECT nearest_spot_id FROM traveler_positions WHERE user_id = ?", Long.class, alice);
        assertThat(stored).isEqualTo(spot2); // 두 번째 값으로 덮어써야 한다.
    }

    @Test
    void 공유를_끄면_조회에서_사라진다() throws Exception {
        Long alice = signUp("trv-alice5", "uid-trv-alice5");
        signUp("trv-bob5", "uid-trv-bob5");
        createSpot(37.54, 127.04);

        mockMvc.perform(post("/api/travelers/position")
                        .header("Authorization", "Bearer trv-alice5")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"lat\":37.54,\"lng\":127.04}"))
                .andExpect(status().isNoContent());
        ageToPast(alice, 40);

        mockMvc.perform(delete("/api/travelers/position")
                        .header("Authorization", "Bearer trv-alice5"))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/travelers/nearby")
                        .header("Authorization", "Bearer trv-bob5")
                        .param("lat", "37.54").param("lng", "127.04").param("radiusMeters", "5000"))
                .andExpect(status().isOk())
                .andExpect(content().json("[]"));
    }

    @Test
    void 주변에_스팟이_없으면_게시가_거부된다() throws Exception {
        signUp("trv-alice6", "uid-trv-alice6");

        // 스팟을 하나도 안 만들었으므로 반경 안에 아무것도 없다.
        mockMvc.perform(post("/api/travelers/position")
                        .header("Authorization", "Bearer trv-alice6")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"lat\":1.0,\"lng\":1.0}"))
                .andExpect(status().isNotFound());
    }

    @Test
    void 인증_없이는_게시도_조회도_할_수_없다() throws Exception {
        mockMvc.perform(post("/api/travelers/position").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"lat\":37.5,\"lng\":127.0}"))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(get("/api/travelers/nearby")
                        .param("lat", "37.5").param("lng", "127.0").param("radiusMeters", "1000"))
                .andExpect(status().isUnauthorized());
    }
}
