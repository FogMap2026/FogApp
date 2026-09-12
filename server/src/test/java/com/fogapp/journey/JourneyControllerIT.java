package com.fogapp.journey;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

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
 * 걸어온 자리(#131)의 저장·조회.
 *
 * <p>핵심은 <b>멱등</b>이다. 앱이 batch 로 모아 올리는데 네트워크가 끊겼다 붙으면 같은
 * 묶음을 다시 보낸다 — 그때 점이 두 겹으로 쌓이면 안개 구멍이 중복되고, 무엇보다
 * 「걸어온 거리」가 부풀어 보인다.</p>
 */
@Testcontainers
@SpringBootTest
@AutoConfigureMockMvc
class JourneyControllerIT {

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

    private void loginAs(String token, String uid) {
        given(tokenVerifier.verify(token)).willReturn(new VerifiedToken(uid, uid + "@example.com", null, null));
    }

    private String point(double lat, double lng, String recordedAt) {
        return "{\"lat\":" + lat + ",\"lng\":" + lng + ",\"recordedAt\":\"" + recordedAt + "\"}";
    }

    private org.springframework.test.web.servlet.ResultActions upload(String token, String... points)
            throws Exception {
        return mockMvc.perform(post("/api/journeys/points")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"points\":[" + String.join(",", points) + "]}"));
    }

    @Test
    void 궤적을_올리면_저장되고_내_것만_돌려준다() throws Exception {
        loginAs("alice-token", "uid-j-alice");
        loginAs("bob-token", "uid-j-bob");

        upload("alice-token",
                point(37.5665, 126.9780, "2026-09-10T01:00:00Z"),
                point(37.5666, 126.9781, "2026-09-10T01:00:15Z"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.received").value(2))
                .andExpect(jsonPath("$.saved").value(2));

        upload("bob-token", point(35.1796, 129.0756, "2026-09-10T01:00:00Z"))
                .andExpect(status().isOk());

        // 밥의 점이 같은 시각이어도 앨리스 조회에 섞이지 않는다 —
        // 유니크가 (user_id, recorded_at) 이라 시각만으로는 충돌하지 않는다.
        mockMvc.perform(get("/api/journeys").header("Authorization", "Bearer alice-token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2));
    }

    @Test
    void 같은_묶음을_다시_보내도_중복_저장되지_않는다() throws Exception {
        // 🔑 batch 업로드는 재전송이 일어난다. 앱이 「이미 보냈는지」를 추적하는 것보다
        //    서버가 멱등하게 받는 편이 훨씬 싸다 — 앱은 마음 편히 다시 보내면 된다.
        loginAs("carol-token", "uid-j-carol");
        String p1 = point(37.1, 127.1, "2026-09-10T02:00:00Z");
        String p2 = point(37.2, 127.2, "2026-09-10T02:00:15Z");

        upload("carol-token", p1, p2).andExpect(jsonPath("$.saved").value(2));

        // 그대로 재전송 — saved 0 이지만 «실패가 아니다». 이미 다 있다는 뜻이다.
        upload("carol-token", p1, p2)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.received").value(2))
                .andExpect(jsonPath("$.saved").value(0));

        Integer stored = jdbcTemplate.queryForObject(
                "SELECT count(*) FROM journey_points jp JOIN users u ON u.id = jp.user_id"
                        + " WHERE u.firebase_uid = ?",
                Integer.class, "uid-j-carol");
        assertThat(stored).isEqualTo(2);
    }

    @Test
    void 좌표_이상치는_거르되_나머지는_살린다() throws Exception {
        // GPS 가 한 번 튀었다고 묶음 전체를 400 으로 되돌리면, 앱은 같은 묶음을 계속
        // 재전송하다 영영 못 올린다 — 그 구간의 걸어온 자리가 통째로 사라진다.
        loginAs("dave-token", "uid-j-dave");

        upload("dave-token",
                point(37.5, 127.0, "2026-09-10T03:00:00Z"),
                point(999.0, 127.0, "2026-09-10T03:00:15Z"),   // 위도 범위 밖
                point(37.6, 127.1, "2026-09-10T03:00:30Z"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.received").value(3))
                .andExpect(jsonPath("$.saved").value(2));
    }

    @Test
    void 상한을_넘는_묶음은_400이다() throws Exception {
        // 앱이 오래 끊겼다 붙으면 수천 개를 한 번에 밀어올릴 수 있다. 상한이 없으면
        // 그건 «앱 버그일 때 서버가 먼저 죽는» 구조다.
        loginAs("erin-token", "uid-j-erin");
        String[] tooMany = new String[JourneyPointsUploadRequest.MAX_POINTS + 1];
        for (int i = 0; i < tooMany.length; i++) {
            tooMany[i] = point(37.5, 127.0, String.format("2026-09-10T04:%02d:%02dZ", i / 60, i % 60));
        }

        upload("erin-token", tooMany).andExpect(status().isBadRequest());
    }

    @Test
    void 빈_묶음은_400이다() throws Exception {
        loginAs("frank-token", "uid-j-frank");

        upload("frank-token").andExpect(status().isBadRequest());
    }

    @Test
    void geom은_트리거가_채운다() throws Exception {
        // 애플리케이션이 아니라 DB 가 채운다(spots V2 · visits V4 · footprints V5 와 동일).
        // 적재 경로가 늘어나도 geom 누락이 생기지 않게 하려는 것이다.
        loginAs("grace-token", "uid-j-grace");
        upload("grace-token", point(37.5665, 126.9780, "2026-09-10T05:00:00Z"))
                .andExpect(status().isOk());

        Integer withGeom = jdbcTemplate.queryForObject(
                "SELECT count(*) FROM journey_points jp JOIN users u ON u.id = jp.user_id"
                        + " WHERE u.firebase_uid = ? AND jp.geom IS NOT NULL",
                Integer.class, "uid-j-grace");
        assertThat(withGeom).isEqualTo(1);
    }

    @Test
    void 인증_없이는_접근할_수_없다() throws Exception {
        mockMvc.perform(get("/api/journeys")).andExpect(status().isUnauthorized());
        mockMvc.perform(post("/api/journeys/points")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"points\":[]}"))
                .andExpect(status().isUnauthorized());
    }
}
