package com.fogapp.match;

import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
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

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fogapp.auth.TokenVerifier;
import com.fogapp.auth.VerifiedToken;

/**
 * 매칭 요청·상태변경·취소가 인증된 본인 명의로만 되는지 검증한다(#52).
 * 토큰 검증기(TokenVerifier)만 mocking 하여 Firebase 자격증명 없이도 인증 경로를 시험한다.
 */
@Testcontainers
@SpringBootTest
@AutoConfigureMockMvc
class MatchControllerIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres =
            new PostgreSQLContainer<>(DockerImageName.parse("postgis/postgis:16-3.4")
                    .asCompatibleSubstituteFor("postgres"));

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private TokenVerifier tokenVerifier;

    @BeforeEach
    void cleanUpUsers() {
        // 각 테스트가 고정된 firebase_uid("uid-alice" 등)를 재사용하므로, 테스트 간 잔여 데이터로
        // UNIQUE 제약 위반이 나지 않도록 매번 비운다. matches는 ON DELETE CASCADE로 함께 정리된다.
        jdbcTemplate.update("DELETE FROM users");
    }

    private void loginAs(String token, String uid) {
        given(tokenVerifier.verify(token)).willReturn(new VerifiedToken(uid, uid + "@example.com", null, null));
    }

    /** uid를 가진 사용자를 로그인 없이 미리 만들어둔다(매칭 상대 지정용). */
    private Long ensureUser(String uid) {
        return jdbcTemplate.queryForObject(
                "INSERT INTO users (firebase_uid) VALUES (?) RETURNING id", Long.class, uid);
    }

    /** 닉네임까지 지정해 미리 만들어둔다(상대방 닉네임 노출 검증용, 5-2). */
    private Long ensureUser(String uid, String nickname) {
        return jdbcTemplate.queryForObject(
                "INSERT INTO users (firebase_uid, nickname) VALUES (?, ?) RETURNING id",
                Long.class, uid, nickname);
    }

    private Long createMatchAs(String token, Long addresseeId) throws Exception {
        String body = mockMvc.perform(post("/api/matches")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"addresseeId\":" + addresseeId + "}"))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return objectMapper.readTree(body).get("id").asLong();
    }

    @Test
    void 매칭_요청자는_로그인한_본인으로_기록된다() throws Exception {
        loginAs("alice-token", "uid-alice");
        Long bobId = ensureUser("uid-bob");

        mockMvc.perform(post("/api/matches")
                        .header("Authorization", "Bearer alice-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"addresseeId\":" + bobId + "}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.addresseeId").value(bobId));
    }

    @Test
    void 요청_대상자가_아니면_매칭_상태를_바꿀_수_없다() throws Exception {
        loginAs("alice-token", "uid-alice");
        Long bobId = ensureUser("uid-bob");
        Long matchId = createMatchAs("alice-token", bobId);

        // 제3자(carol)가 alice -> bob 매칭을 수락 시도
        loginAs("carol-token", "uid-carol");
        mockMvc.perform(patch("/api/matches/" + matchId + "/status")
                        .header("Authorization", "Bearer carol-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"status\":\"accepted\"}"))
                .andExpect(status().isForbidden());

        // 요청을 보낸 alice 본인도 자기 요청을 스스로 수락할 수 없다(대상자만 가능)
        mockMvc.perform(patch("/api/matches/" + matchId + "/status")
                        .header("Authorization", "Bearer alice-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"status\":\"accepted\"}"))
                .andExpect(status().isForbidden());
    }

    @Test
    void 요청_대상자는_매칭을_수락할_수_있다() throws Exception {
        loginAs("alice-token", "uid-alice");
        Long bobId = ensureUser("uid-bob");
        Long matchId = createMatchAs("alice-token", bobId);

        loginAs("bob-token", "uid-bob");
        mockMvc.perform(patch("/api/matches/" + matchId + "/status")
                        .header("Authorization", "Bearer bob-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"status\":\"accepted\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("accepted"));
    }

    @Test
    void 관계없는_사용자는_매칭을_취소할_수_없다() throws Exception {
        loginAs("alice-token", "uid-alice");
        Long bobId = ensureUser("uid-bob");
        Long matchId = createMatchAs("alice-token", bobId);

        loginAs("carol-token", "uid-carol");
        mockMvc.perform(delete("/api/matches/" + matchId)
                        .header("Authorization", "Bearer carol-token"))
                .andExpect(status().isForbidden());
    }

    @Test
    void 요청자는_본인이_보낸_매칭을_취소할_수_있다() throws Exception {
        loginAs("alice-token", "uid-alice");
        Long bobId = ensureUser("uid-bob");
        Long matchId = createMatchAs("alice-token", bobId);

        mockMvc.perform(delete("/api/matches/" + matchId)
                        .header("Authorization", "Bearer alice-token"))
                .andExpect(status().isNoContent());
    }

    @Test
    void 제3자는_남의_매칭을_조회할_수_없다() throws Exception {
        // 5-2 리뷰(PGH0621/songkh1201): GET /api/matches/{id}에 당사자 검사가 없으면
        // id만 알아도 상대방 닉네임·성향 유사도가 새어나가고 direction까지 틀리게 계산된다.
        loginAs("alice-token", "uid-alice");
        Long bobId = ensureUser("uid-bob");
        Long matchId = createMatchAs("alice-token", bobId);

        loginAs("carol-token", "uid-carol");
        mockMvc.perform(get("/api/matches/" + matchId)
                        .header("Authorization", "Bearer carol-token"))
                .andExpect(status().isForbidden());
    }

    @Test
    void 당사자는_매칭을_단건_조회할_수_있다() throws Exception {
        loginAs("alice-token", "uid-alice");
        Long bobId = ensureUser("uid-bob", "밥");
        Long matchId = createMatchAs("alice-token", bobId);

        mockMvc.perform(get("/api/matches/" + matchId)
                        .header("Authorization", "Bearer alice-token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.direction").value("SENT"))
                .andExpect(jsonPath("$.counterpartNickname").value("밥"));
    }

    @Test
    void 목록에서_보낸_요청은_direction이_SENT이고_상대방_닉네임을_포함한다() throws Exception {
        // 5-2: requesterId/addresseeId만으로는 "누가 보냈는지"를 앱이 매번 계산해야 한다 —
        // 서버가 로그인 사용자(viewer) 기준으로 미리 방향과 상대방 정보를 계산해 내려준다.
        loginAs("alice-token", "uid-alice");
        Long bobId = ensureUser("uid-bob", "밥");
        createMatchAs("alice-token", bobId);

        mockMvc.perform(get("/api/matches").header("Authorization", "Bearer alice-token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].direction").value("SENT"))
                .andExpect(jsonPath("$[0].counterpartId").value(bobId))
                .andExpect(jsonPath("$[0].counterpartNickname").value("밥"));
    }

    @Test
    void 목록에서_받은_요청은_direction이_RECEIVED다() throws Exception {
        Long aliceId = ensureUser("uid-alice", "앨리스");
        Long bobId = ensureUser("uid-bob", "밥");
        loginAs("alice-token", "uid-alice");
        loginAs("bob-token", "uid-bob");
        createMatchAs("alice-token", bobId);

        mockMvc.perform(get("/api/matches").header("Authorization", "Bearer bob-token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].direction").value("RECEIVED"))
                .andExpect(jsonPath("$[0].counterpartId").value(aliceId))
                .andExpect(jsonPath("$[0].counterpartNickname").value("앨리스"));
    }

    @Test
    void 인증_없이_매칭을_요청할_수_없다() throws Exception {
        Long bobId = ensureUser("uid-bob");

        mockMvc.perform(post("/api/matches")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"addresseeId\":" + bobId + "}"))
                .andExpect(status().isUnauthorized());
    }
}
