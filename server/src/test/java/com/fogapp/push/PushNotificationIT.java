package com.fogapp.push;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.Map;

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
 * 푸시 알림(#134) — 기기 등록·해제와 «누구에게 보내려 했나».
 *
 * <p>{@link PushSender} 를 mocking 해 실제 FCM 호출 없이 본다. 여기서 지키는 것은 셋이다 —
 * <b>받는 사람이 맞나</b>, <b>내용이 안 실리나</b>, <b>안 보내야 할 때 안 보내나</b>.</p>
 */
@Testcontainers
@SpringBootTest
@AutoConfigureMockMvc
class PushNotificationIT {

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

    @MockBean
    private PushSender pushSender;

    @BeforeEach
    void cleanUp() {
        jdbcTemplate.update("DELETE FROM users");
        loginAs("alice-token", "uid-push-alice");
        loginAs("bob-token", "uid-push-bob");
    }

    private void loginAs(String token, String uid) {
        given(tokenVerifier.verify(token)).willReturn(new VerifiedToken(uid, uid + "@example.com", null, null));
    }

    private Long ensureUser(String uid, String nickname) {
        return jdbcTemplate.queryForObject(
                "INSERT INTO users (firebase_uid, nickname) VALUES (?, ?) RETURNING id", Long.class, uid, nickname);
    }

    private void registerDevice(String token, String fcmToken) throws Exception {
        mockMvc.perform(post("/api/devices/token")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"token\":\"" + fcmToken + "\",\"platform\":\"android\"}"))
                .andExpect(status().isNoContent());
    }

    private Long requestMatchAliceToBob(Long bobId) throws Exception {
        String body = mockMvc.perform(post("/api/matches")
                        .header("Authorization", "Bearer alice-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"addresseeId\":" + bobId + "}"))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return objectMapper.readTree(body).get("id").asLong();
    }

    @Test
    void 기기_등록은_토큰의_주인을_지금_사용자로_바꾼다() throws Exception {
        registerDevice("alice-token", "device-1");
        Long aliceId = jdbcTemplate.queryForObject(
                "SELECT user_id FROM device_tokens WHERE token = 'device-1'", Long.class);

        // 같은 폰에 밥이 로그인 — 앨리스의 알림이 이 폰으로 가면 안 된다.
        registerDevice("bob-token", "device-1");
        Long ownerNow = jdbcTemplate.queryForObject(
                "SELECT user_id FROM device_tokens WHERE token = 'device-1'", Long.class);

        assertThat(ownerNow).isNotEqualTo(aliceId);
        assertThat(jdbcTemplate.queryForObject("SELECT count(*) FROM device_tokens", Integer.class)).isEqualTo(1);
    }

    @Test
    void 알림_끄기는_내_토큰만_지운다() throws Exception {
        registerDevice("alice-token", "device-alice");
        registerDevice("bob-token", "device-bob");

        // 밥이 앨리스의 토큰을 지우려 해도 남의 것은 안 지워진다(#52).
        mockMvc.perform(delete("/api/devices/token")
                        .header("Authorization", "Bearer bob-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"token\":\"device-alice\"}"))
                .andExpect(status().isNoContent());
        assertThat(jdbcTemplate.queryForObject(
                "SELECT count(*) FROM device_tokens WHERE token = 'device-alice'", Integer.class)).isEqualTo(1);

        mockMvc.perform(delete("/api/devices/token")
                        .header("Authorization", "Bearer alice-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"token\":\"device-alice\"}"))
                .andExpect(status().isNoContent());
        assertThat(jdbcTemplate.queryForObject(
                "SELECT count(*) FROM device_tokens WHERE token = 'device-alice'", Integer.class)).isZero();
    }

    @Test
    void 인증_없이는_기기를_등록할_수_없다() throws Exception {
        mockMvc.perform(post("/api/devices/token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"token\":\"x\"}"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void 친구_요청은_대상자에게_요청자_닉네임으로_간다() throws Exception {
        Long bobId = ensureUser("uid-push-bob", "밥");
        requestMatchAliceToBob(bobId);

        verify(pushSender).send(eq(bobId), eq("새 친구 요청"), any(), any());
    }

    @Test
    void 수락은_요청자에게_가고_거절은_아무에게도_안_간다() throws Exception {
        Long bobId = ensureUser("uid-push-bob", "밥");
        Long matchId = requestMatchAliceToBob(bobId);
        Long aliceId = jdbcTemplate.queryForObject(
                "SELECT id FROM users WHERE firebase_uid = 'uid-push-alice'", Long.class);

        mockMvc.perform(patch("/api/matches/" + matchId + "/status")
                        .header("Authorization", "Bearer bob-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"status\":\"rejected\"}"))
                .andExpect(status().isOk());
        verify(pushSender, never()).send(eq(aliceId), any(), any(), any());

        mockMvc.perform(patch("/api/matches/" + matchId + "/status")
                        .header("Authorization", "Bearer bob-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"status\":\"accepted\"}"))
                .andExpect(status().isOk());
        verify(pushSender).send(eq(aliceId), eq("친구가 됐어요"), any(), any());
    }

    @Test
    void 새_메시지_알림에는_내용이_실리지_않는다() throws Exception {
        Long bobId = ensureUser("uid-push-bob", "밥");
        Long matchId = requestMatchAliceToBob(bobId);
        mockMvc.perform(patch("/api/matches/" + matchId + "/status")
                        .header("Authorization", "Bearer bob-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"status\":\"accepted\"}"))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/matches/" + matchId + "/messages")
                        .header("Authorization", "Bearer alice-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"content\":\"내일 경복궁 어때?\"}"))
                .andExpect(status().isCreated());

        // 받는 사람은 밥, 문구에는 «보낸 사람»만 — 내용은 잠금화면에 뜨면 안 된다(#134 결정).
        verify(pushSender).send(eq(bobId), eq("새 메시지"), eq("이름 없는 여행자님이 메시지를 보냈어요."),
                eq(Map.of("type", "message", "matchId", String.valueOf(matchId))));
    }
}
