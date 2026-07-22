package com.fogapp.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fogapp.user.User;
import com.fogapp.user.UserRepository;

/**
 * 인증 필터 → 사용자 업서트 → 프로필 API 전체 흐름을 실제 PostGIS에 대해 검증(#4).
 * 토큰 검증기(TokenVerifier)만 mocking 하여 Firebase 자격증명 없이도 인증 경로를 시험한다.
 */
@Testcontainers
@SpringBootTest
@AutoConfigureMockMvc
class ProfileControllerIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres =
            new PostgreSQLContainer<>(DockerImageName.parse("postgis/postgis:16-3.4")
                    .asCompatibleSubstituteFor("postgres"));

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private TokenVerifier tokenVerifier;

    @Test
    void 토큰_없이_프로필_조회하면_401() throws Exception {
        mockMvc.perform(get("/api/profile"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void 유효한_토큰이면_최초_조회시_사용자가_생성되고_프로필을_반환한다() throws Exception {
        given(tokenVerifier.verify("good-token"))
                .willReturn(new VerifiedToken("uid-alice", "alice@example.com", "앨리스", null));

        mockMvc.perform(get("/api/profile").header("Authorization", "Bearer good-token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.email").value("alice@example.com"))
                .andExpect(jsonPath("$.nickname").value("앨리스"));

        assertThat(userRepository.findByFirebaseUid("uid-alice")).isPresent();
    }

    @Test
    void 무효한_토큰이면_401() throws Exception {
        given(tokenVerifier.verify("bad-token"))
                .willThrow(new InvalidTokenException("만료된 토큰"));

        mockMvc.perform(get("/api/profile").header("Authorization", "Bearer bad-token"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void 프로필_닉네임을_수정할_수_있다() throws Exception {
        given(tokenVerifier.verify("bob-token"))
                .willReturn(new VerifiedToken("uid-bob", "bob@example.com", null, null));

        mockMvc.perform(patch("/api/profile")
                        .header("Authorization", "Bearer bob-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"nickname\":\"밥\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.nickname").value("밥"));

        assertThat(userRepository.findByFirebaseUid("uid-bob").orElseThrow().getNickname())
                .isEqualTo("밥");
    }

    @Test
    void 성향_테스트_결과를_저장할_수_있다() throws Exception {
        given(tokenVerifier.verify("carol-token"))
                .willReturn(new VerifiedToken("uid-carol", "carol@example.com", null, null));

        mockMvc.perform(patch("/api/profile/personality")
                        .header("Authorization", "Bearer carol-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "personalityType": "PRI",
                                  "personalityScores": {
                                    "version": 1,
                                    "axes": {
                                      "spontaneity": {"score": 72, "pole": "P"},
                                      "restVsRoam": {"score": 35, "pole": "R"},
                                      "extraversion": {"score": 58, "pole": "I"}
                                    }
                                  }
                                }
                                """))
                .andExpect(status().isNoContent());

        User saved = userRepository.findByFirebaseUid("uid-carol").orElseThrow();
        assertThat(saved.getPersonalityType()).isEqualTo("PRI");

        // jsonb는 원본 텍스트 포맷(공백·키 순서)을 그대로 보존하지 않으므로,
        // 문자열 그대로 비교하지 않고 JSON으로 파싱해 값만 검증한다.
        JsonNode scores = objectMapper.readTree(saved.getPersonalityScores());
        assertThat(scores.at("/axes/spontaneity/pole").asText()).isEqualTo("P");
        assertThat(scores.at("/axes/spontaneity/score").asInt()).isEqualTo(72);
    }

    @Test
    void 성향_유형이_비어있으면_400() throws Exception {
        given(tokenVerifier.verify("dave-token"))
                .willReturn(new VerifiedToken("uid-dave", "dave@example.com", null, null));

        mockMvc.perform(patch("/api/profile/personality")
                        .header("Authorization", "Bearer dave-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"personalityType\":\"\",\"personalityScores\":{}}"))
                .andExpect(status().isBadRequest());
    }
}
