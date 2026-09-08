package com.fogapp.footprint;

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
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fogapp.auth.TokenVerifier;
import com.fogapp.auth.VerifiedToken;
import com.fogapp.user.User;

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

        // 발자취 횟수는 사용자당 관리되는데(#116), @SpringBootTest 는 메서드 간 롤백이 없어
        // 같은 uid("uid-alice" 등)가 테스트를 넘나들며 횟수를 계속 소진한다. 그러면 앞선
        // 테스트가 몇 개를 썼느냐에 따라 뒤 테스트가 429 로 깨진다 — 실제로 7건이 그렇게 깨졌다.
        // 매번 기본값으로 되돌려 각 테스트가 같은 조건에서 시작하게 한다.
        jdbcTemplate.update("UPDATE users SET footprint_quota = ?", User.DEFAULT_FOOTPRINT_QUOTA);
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
    void 발자취_응답에_작성자_닉네임과_프로필이_담긴다() throws Exception {
        // #71: userId 만 내려주면 앱이 사용자마다 프로필을 따로 조회해야 하는데,
        // GET /api/profile 은 본인 것만 주므로 남의 프로필을 볼 방법 자체가 없다.
        loginAs("alice-token", "uid-alice");
        createFootprintAs("alice-token", "앨리스 글");
        jdbcTemplate.update(
                "UPDATE users SET nickname = ?, profile_image_url = ? WHERE firebase_uid = ?",
                "앨리스", "https://cdn.example.com/alice.png", "uid-alice");

        mockMvc.perform(get("/api/footprints?spotId=" + spotId)
                        .header("Authorization", "Bearer alice-token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].authorNickname").value("앨리스"))
                .andExpect(jsonPath("$[0].authorProfileImageUrl").value("https://cdn.example.com/alice.png"));
    }

    @Test
    void 닉네임이_없는_작성자도_목록이_내려간다() throws Exception {
        // 가입 직후 닉네임을 정하지 않은 사용자가 있다. 작성자 이름을 못 찾았다고
        // 목록 전체가 실패하면 안 된다 — 화면에서 대체 문구를 쓰게 null 로 내려보낸다.
        loginAs("dave-token", "uid-dave");
        createFootprintAs("dave-token", "닉네임 없는 글");
        jdbcTemplate.update("UPDATE users SET nickname = NULL WHERE firebase_uid = ?", "uid-dave");

        mockMvc.perform(get("/api/footprints?spotId=" + spotId)
                        .header("Authorization", "Bearer dave-token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].authorNickname").doesNotExist())
                .andExpect(jsonPath("$[0].content").value("닉네임 없는 글"));
    }

    @Test
    void 발자취가_없는_스팟은_빈_목록을_돌려준다() throws Exception {
        // 작성자 조회가 IN () 으로 깨지지 않는지 확인한다.
        loginAs("alice-token", "uid-alice");
        Long emptySpotId = jdbcTemplate.queryForObject(
                "INSERT INTO spots (content_id, title) VALUES (?, ?) RETURNING id",
                Long.class, "content-empty-" + System.nanoTime(), "빈 스팟");

        mockMvc.perform(get("/api/footprints?spotId=" + emptySpotId)
                        .header("Authorization", "Bearer alice-token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(0));
    }

    /** 좌표를 붙여 발자취를 만든다(#115). */
    private void createAt(String token, String content, double lat, double lng) throws Exception {
        mockMvc.perform(post("/api/footprints")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"content\":\"" + content + "\",\"lat\":" + lat + ",\"lng\":" + lng + "}"))
                .andExpect(status().isCreated());
    }

    // ── 반경 조회 (#115) ──────────────────────────────────────────────────

    @Test
    void 반경_안의_발자취만_가까운_순으로_돌려준다() throws Exception {
        loginAs("alice-token", "uid-alice");
        createAt("alice-token", "여기 계단 힘들다", 37.5665, 126.9780);   // 중심
        createAt("alice-token", "부산에서", 35.1796, 129.0756);           // 반경 밖

        mockMvc.perform(get("/api/footprints/nearby?lat=37.5665&lng=126.9780&radius=50")
                        .header("Authorization", "Bearer alice-token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].content").value("여기 계단 힘들다"))
                .andExpect(jsonPath("$[0].lat").value(37.5665))
                .andExpect(jsonPath("$.length()").value(1));
    }

    @Test
    void 좌표가_없는_발자취는_반경_조회에_안_뜬다() throws Exception {
        // 예전 글이나 좌표 이상치는 geom 이 NULL 이라 자연히 빠진다 —
        // 스팟 상세 목록에는 계속 남는다.
        loginAs("bob-token", "uid-bob");
        mockMvc.perform(post("/api/footprints")
                        .header("Authorization", "Bearer bob-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"spotId\":" + spotId + ",\"content\":\"좌표 없는 글\"}"))
                .andExpect(status().isCreated());

        mockMvc.perform(get("/api/footprints/nearby?lat=37.5665&lng=126.9780&radius=1000")
                        .header("Authorization", "Bearer bob-token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.content == '좌표 없는 글')]").isEmpty());
    }

    @Test
    void 반경_상한을_넘으면_400이다() throws Exception {
        // 상한이 없으면 radius=999999 한 번으로 전국 발자취를 긁어갈 수 있다.
        loginAs("alice-token", "uid-alice");

        mockMvc.perform(get("/api/footprints/nearby?lat=37.5&lng=127.0&radius=999999")
                        .header("Authorization", "Bearer alice-token"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void nearby_경로가_단건_조회에_먹히지_않는다() throws Exception {
        // GET /{id} 와 GET /nearby 가 같은 자리에 있다. "nearby" 가 id 로 해석되면
        // 400 이 나면서 반경 조회가 통째로 죽는다.
        loginAs("alice-token", "uid-alice");

        mockMvc.perform(get("/api/footprints/nearby?lat=37.5&lng=127.0&radius=50")
                        .header("Authorization", "Bearer alice-token"))
                .andExpect(status().isOk());
    }

    @Test
    void 좌표_범위를_벗어나면_작성이_400이다() throws Exception {
        // 범위 밖 좌표는 PostGIS geography 캐스팅에서 예외가 되어 500 이 된다 — 먼저 거른다.
        loginAs("alice-token", "uid-alice");

        mockMvc.perform(post("/api/footprints")
                        .header("Authorization", "Bearer alice-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"content\":\"이상치\",\"lat\":999,\"lng\":999}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void 위도만_보내면_400이다() throws Exception {
        loginAs("alice-token", "uid-alice");

        mockMvc.perform(post("/api/footprints")
                        .header("Authorization", "Bearer alice-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"content\":\"반쪽 좌표\",\"lat\":37.5}"))
                .andExpect(status().isBadRequest());
    }

    // ── 작성 횟수 제한 (#116) ────────────────────────────────────────────

    @Test
    void 횟수를_다_쓰면_429다() throws Exception {
        // 기본 3회. 무제한이면 한 자리에서 수십 개를 쏟아부어 길목이 도배된다.
        loginAs("erin-token", "uid-erin");
        for (int i = 0; i < 3; i++) {
            createAt("erin-token", "글" + i, 37.5665, 126.9780);
        }

        mockMvc.perform(post("/api/footprints")
                        .header("Authorization", "Bearer erin-token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"content\":\"네 번째\",\"lat\":37.5665,\"lng\":126.9780}"))
                .andExpect(status().isTooManyRequests());
    }

    @Test
    void 남은_횟수가_프로필에_보인다() throws Exception {
        // 앱이 버튼을 비활성화하고 이유를 안내하려면 이 값이 필요하다.
        loginAs("frank-token", "uid-frank");
        createAt("frank-token", "하나 썼다", 37.5665, 126.9780);

        mockMvc.perform(get("/api/profile").header("Authorization", "Bearer frank-token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.footprintQuota").value(2));
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

    @Test
    void 좋아요를_누른_사용자에게만_likedByMe가_true다() throws Exception {
        // #72: 배치 조회가 사용자별로 정확히 갈리는지 확인한다.
        loginAs("alice-token", "uid-alice");
        Long footprintId = createFootprintAs("alice-token", "앨리스 글");

        loginAs("bob-token", "uid-bob");
        mockMvc.perform(post("/api/footprints/" + footprintId + "/likes")
                        .header("Authorization", "Bearer bob-token"))
                .andExpect(status().isNoContent());

        // 좋아요를 누른 밥은 true
        mockMvc.perform(get("/api/footprints?spotId=" + spotId)
                        .header("Authorization", "Bearer bob-token"))
                .andExpect(jsonPath("$[0].likedByMe").value(true));

        // 좋아요를 안 누른 캐롤은 같은 발자취라도 false
        loginAs("carol-token", "uid-carol");
        mockMvc.perform(get("/api/footprints?spotId=" + spotId)
                        .header("Authorization", "Bearer carol-token"))
                .andExpect(jsonPath("$[0].likedByMe").value(false));
    }

    @Test
    void 단건_조회도_likedByMe를_포함한다() throws Exception {
        loginAs("alice-token", "uid-alice");
        Long footprintId = createFootprintAs("alice-token", "앨리스 글");

        mockMvc.perform(post("/api/footprints/" + footprintId + "/likes")
                        .header("Authorization", "Bearer alice-token"))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/footprints/" + footprintId)
                        .header("Authorization", "Bearer alice-token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.likedByMe").value(true));
    }
}
