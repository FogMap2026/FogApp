package com.fogapp.footprint;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
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
 * 발자취 작성·수정·삭제·좋아요가 인증된 본인 명의로만 되는지 검증한다(#52).
 * 토큰 검증기(TokenVerifier)만 mocking 하여 Firebase 자격증명 없이도 인증 경로를 시험한다.
 */
@Testcontainers
@SpringBootTest
@AutoConfigureMockMvc
class FootprintControllerIT {

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

    private Long spotId;

    @BeforeEach
    void setUp() {
        spotId = jdbcTemplate.queryForObject(
                "INSERT INTO spots (content_id, title) VALUES (?, ?) RETURNING id",
                Long.class, "content-" + System.nanoTime(), "테스트 스팟");
    }

    private void loginAs(String token, String uid) {
        given(tokenVerifier.verify(token)).willReturn(new VerifiedToken(uid, uid + "@example.com", null, null));
    }

    private Long createFootprintAs(String token, String content) throws Exception {
        String body = mockMvc.perform(post("/api/footprints")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"spotId\":" + spotId + ",\"content\":\"" + content + "\"}"))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return objectMapper.readTree(body).get("id").asLong();
    }

    @Test
    void 발자취_작성자는_로그인한_본인으로_기록된다() throws Exception {
        loginAs("alice-token", "uid-alice");

        mockMvc.perform(post("/api/footprints")
                        .header("Authorization", "Bearer alice-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"spotId\":" + spotId + ",\"content\":\"앨리스 발자취\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.content").value("앨리스 발자취"));
    }

    @Test
    void 다른_사람이_작성한_발자취는_수정할_수_없다() throws Exception {
        loginAs("alice-token", "uid-alice");
        Long footprintId = createFootprintAs("alice-token", "앨리스 글");

        loginAs("bob-token", "uid-bob");
        mockMvc.perform(patch("/api/footprints/" + footprintId)
                        .header("Authorization", "Bearer bob-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"content\":\"밥이 몰래 수정\"}"))
                .andExpect(status().isForbidden());
    }

    @Test
    void 다른_사람이_작성한_발자취는_삭제할_수_없다() throws Exception {
        loginAs("alice-token", "uid-alice");
        Long footprintId = createFootprintAs("alice-token", "앨리스 글");

        loginAs("bob-token", "uid-bob");
        mockMvc.perform(delete("/api/footprints/" + footprintId)
                        .header("Authorization", "Bearer bob-token"))
                .andExpect(status().isForbidden());
    }

    @Test
    void 본인_발자취는_수정할_수_있다() throws Exception {
        loginAs("alice-token", "uid-alice");
        Long footprintId = createFootprintAs("alice-token", "앨리스 글");

        mockMvc.perform(patch("/api/footprints/" + footprintId)
                        .header("Authorization", "Bearer alice-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"content\":\"앨리스가 직접 수정\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content").value("앨리스가 직접 수정"));
    }

    @Test
    void 좋아요는_로그인한_사용자_명의로_기록된다() throws Exception {
        loginAs("alice-token", "uid-alice");
        Long footprintId = createFootprintAs("alice-token", "앨리스 글");

        loginAs("bob-token", "uid-bob");
        mockMvc.perform(post("/api/footprints/" + footprintId + "/likes")
                        .header("Authorization", "Bearer bob-token"))
                .andExpect(status().isNoContent());

        Integer likeCount = jdbcTemplate.queryForObject(
                "SELECT like_count FROM footprints WHERE id = ?", Integer.class, footprintId);
        assertThat(likeCount).isEqualTo(1);

        Integer bobLikeRows = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM footprint_likes fl JOIN users u ON u.id = fl.user_id "
                        + "WHERE fl.footprint_id = ? AND u.firebase_uid = 'uid-bob'",
                Integer.class, footprintId);
        assertThat(bobLikeRows).isEqualTo(1);
    }

    @Test
    void 인증_없이_발자취를_작성할_수_없다() throws Exception {
        mockMvc.perform(post("/api/footprints")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"spotId\":" + spotId + ",\"content\":\"익명 글\"}"))
                .andExpect(status().isUnauthorized());
    }
}
