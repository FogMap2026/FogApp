package com.fogapp.message;

import static org.assertj.core.api.Assertions.assertThat;
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
import org.springframework.test.web.servlet.ResultActions;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fogapp.auth.TokenVerifier;
import com.fogapp.auth.VerifiedToken;

/**
 * 친구끼리 메시지 — «수락된 매칭의 당사자»만 읽고 쓸 수 있는지, 끊으면 대화도 지워지는지.
 * 토큰 검증기만 mocking 한다({@code MatchControllerIT} 와 같은 방식).
 */
@Testcontainers
@SpringBootTest
@AutoConfigureMockMvc
class MessageControllerIT {

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
    void cleanUp() {
        // matches·messages 는 users 에 ON DELETE CASCADE 로 걸려 함께 비워진다.
        jdbcTemplate.update("DELETE FROM users");
        loginAs("alice-token", "uid-alice");
        loginAs("bob-token", "uid-bob");
        loginAs("carol-token", "uid-carol");
    }

    private void loginAs(String token, String uid) {
        given(tokenVerifier.verify(token)).willReturn(new VerifiedToken(uid, uid + "@example.com", null, null));
    }

    private Long ensureUser(String uid) {
        return jdbcTemplate.queryForObject(
                "INSERT INTO users (firebase_uid) VALUES (?) RETURNING id", Long.class, uid);
    }

    /** alice → bob 요청. accept 면 bob 이 수락까지 한다. */
    private Long matchAliceBob(boolean accept) throws Exception {
        Long bobId = ensureUser("uid-bob");
        String body = mockMvc.perform(post("/api/matches")
                        .header("Authorization", "Bearer alice-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"addresseeId\":" + bobId + "}"))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        Long matchId = objectMapper.readTree(body).get("id").asLong();
        if (accept) {
            mockMvc.perform(patch("/api/matches/" + matchId + "/status")
                            .header("Authorization", "Bearer bob-token")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("{\"status\":\"accepted\"}"))
                    .andExpect(status().isOk());
        }
        return matchId;
    }

    private ResultActions send(String token, Long matchId, String content) throws Exception {
        return mockMvc.perform(post("/api/matches/" + matchId + "/messages")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(java.util.Map.of("content", content))));
    }

    private ResultActions list(String token, Long matchId, String query) throws Exception {
        return mockMvc.perform(get("/api/matches/" + matchId + "/messages" + query)
                .header("Authorization", "Bearer " + token));
    }

    @Test
    void 친구끼리는_주고받고_각자_mine_이_맞게_보인다() throws Exception {
        Long matchId = matchAliceBob(true);

        send("alice-token", matchId, "  안녕  ").andExpect(status().isCreated())
                .andExpect(jsonPath("$.mine").value(true))
                .andExpect(jsonPath("$.content").value("안녕")); // 앞뒤 공백은 저장하지 않는다
        send("bob-token", matchId, "반가워").andExpect(status().isCreated());

        list("bob-token", matchId, "").andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].content").value("안녕")) // 시간순
                .andExpect(jsonPath("$[0].mine").value(false))
                .andExpect(jsonPath("$[1].content").value("반가워"))
                .andExpect(jsonPath("$[1].mine").value(true));
    }

    @Test
    void afterId_이후만_내려준다() throws Exception {
        Long matchId = matchAliceBob(true);
        String first = send("alice-token", matchId, "하나").andReturn().getResponse().getContentAsString();
        long firstId = objectMapper.readTree(first).get("id").asLong();
        send("bob-token", matchId, "둘");

        list("alice-token", matchId, "?afterId=" + firstId).andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].content").value("둘"));
    }

    @Test
    void 수락_전에는_요청자도_대상자도_보낼_수_없다() throws Exception {
        Long matchId = matchAliceBob(false);

        send("alice-token", matchId, "먼저 말 걸기").andExpect(status().isForbidden());
        send("bob-token", matchId, "대기 중").andExpect(status().isForbidden());
        list("alice-token", matchId, "").andExpect(status().isForbidden());
    }

    @Test
    void 제3자는_친구_사이의_대화를_읽거나_쓸_수_없다() throws Exception {
        Long matchId = matchAliceBob(true);
        send("alice-token", matchId, "비밀");

        list("carol-token", matchId, "").andExpect(status().isForbidden());
        send("carol-token", matchId, "끼어들기").andExpect(status().isForbidden());
    }

    @Test
    void 빈_메시지와_너무_긴_메시지는_거절한다() throws Exception {
        Long matchId = matchAliceBob(true);

        send("alice-token", matchId, "   ").andExpect(status().isBadRequest());
        send("alice-token", matchId, "가".repeat(Message.MAX_LENGTH + 1)).andExpect(status().isBadRequest());
    }

    @Test
    void 친구를_끊으면_대화도_지워진다() throws Exception {
        Long matchId = matchAliceBob(true);
        send("alice-token", matchId, "곧 사라질 말");

        mockMvc.perform(delete("/api/matches/" + matchId).header("Authorization", "Bearer bob-token"))
                .andExpect(status().isNoContent());

        Integer left = jdbcTemplate.queryForObject(
                "SELECT count(*) FROM messages WHERE match_id = ?", Integer.class, matchId);
        assertThat(left).isZero();
    }

    @Test
    void 탈퇴하면_그_사람이_낀_대화가_지워진다() throws Exception {
        Long matchId = matchAliceBob(true);
        send("alice-token", matchId, "알리스가 보냄");
        send("bob-token", matchId, "밥이 보냄");

        jdbcTemplate.update("DELETE FROM users WHERE firebase_uid = 'uid-alice'");

        Integer left = jdbcTemplate.queryForObject("SELECT count(*) FROM messages", Integer.class);
        assertThat(left).isZero(); // 밥이 보낸 것도 — 대화방(매칭)이 사라졌으니
    }
}
