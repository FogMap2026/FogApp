package com.fogapp.user;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
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
 * 회원 탈퇴(#182) — 방침 4장이 약속한 「탈퇴하는 즉시 계정과 관련 정보를 파기」.
 *
 * <p>그전까지 이행 수단은 <b>운영 DB 에 손으로 치는 SQL</b> 뿐이었다. {@code WHERE} 절
 * 하나 틀리면 남의 계정이 날아가고 되돌릴 수 없다.</p>
 *
 * <p>여기서 지키는 것은 둘이다 — <b>내 것만 지운다</b>, 그리고 <b>관련 정보가 남지 않는다</b>.</p>
 */
@Testcontainers
@SpringBootTest
@AutoConfigureMockMvc
class WithdrawalIT {

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

    /** 로그인시켜 users 행을 만든다(인증 필터가 업서트한다). */
    private Long signUp(String token, String uid) throws Exception {
        loginAs(token, uid);
        mockMvc.perform(get("/api/profile").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk());
        return jdbcTemplate.queryForObject(
                "SELECT id FROM users WHERE firebase_uid = ?", Long.class, uid);
    }

    private Long createSpot() {
        return jdbcTemplate.queryForObject(
                "INSERT INTO spots (content_id, title, lat, lng) VALUES (?, ?, 37.5, 127.0) RETURNING id",
                Long.class, "wd-" + System.nanoTime(), "탈퇴 테스트 스팟");
    }

    @Test
    void 탈퇴하면_계정과_관련_정보가_함께_사라진다() throws Exception {
        Long userId = signUp("wd-alice", "uid-wd-alice");
        Long spotId = createSpot();

        // 관련 정보를 만들어 둔다 — 전부 ON DELETE CASCADE 로 따라가야 한다.
        // 🔴 journey_points 는 «여기 없다» — 그 표는 #131(PR #192)의 V9 가 만든다.
        //    dev 에 없는 표를 여기서 넣으면 CI 가 「탈퇴가 깨졌다」가 아니라
        //    「표가 없다」로 운다. 그 단언은 표를 «만드는» PR 이 진다.
        jdbcTemplate.update(
                "INSERT INTO visits (user_id, spot_id, photo_url, lat, lng) VALUES (?, ?, ?, 37.5, 127.0)",
                userId, spotId, "/api/visits/photos/uid-wd-alice/" + spotId + "/x.jpg");
        jdbcTemplate.update(
                "INSERT INTO footprints (user_id, content, lat, lng) VALUES (?, ?, 37.5, 127.0)",
                userId, "탈퇴 전 글귀");
        // traveler_positions(#133, V10)는 이 PR이 만드는 표라 여기서 단언한다 — #192의
        // journey_points와 같은 원칙(PGH0621, PR #201 리뷰).
        jdbcTemplate.update(
                "INSERT INTO traveler_positions (user_id, nearest_spot_id) VALUES (?, ?)", userId, spotId);

        mockMvc.perform(delete("/api/profile").header("Authorization", "Bearer wd-alice"))
                .andExpect(status().isNoContent());

        assertThat(countOf("users", "id", userId)).isZero();
        assertThat(countOf("visits", "user_id", userId)).isZero();
        assertThat(countOf("footprints", "user_id", userId)).isZero();
        assertThat(countOf("traveler_positions", "user_id", userId)).isZero();
    }

    @Test
    void 남의_계정은_건드리지_않는다() throws Exception {
        // 🔴 지우는 대상은 «인증 필터가 세운 현재 사용자» 뿐이다. 경로나 본문으로
        //    userId 를 받지 않는다 — #52 에서 발자취·매칭이 겪은 문제와 같은 자리다.
        Long bob = signUp("wd-bob", "uid-wd-bob");
        Long carol = signUp("wd-carol", "uid-wd-carol");
        jdbcTemplate.update(
                "INSERT INTO footprints (user_id, content, lat, lng) VALUES (?, ?, 37.5, 127.0)",
                carol, "캐롤 글귀");

        mockMvc.perform(delete("/api/profile").header("Authorization", "Bearer wd-bob"))
                .andExpect(status().isNoContent());

        assertThat(countOf("users", "id", bob)).isZero();
        assertThat(countOf("users", "id", carol)).isEqualTo(1);
        assertThat(countOf("footprints", "user_id", carol)).isEqualTo(1);
    }

    @Test
    void 탈퇴하면_동행_이력도_양쪽에서_사라진다() throws Exception {
        // matches 는 requester_id·addressee_id 둘 다 users 를 참조한다. 한쪽만
        // CASCADE 였다면 「상대는 있는데 나는 없는」 행이 남는다.
        Long dave = signUp("wd-dave", "uid-wd-dave");
        Long erin = signUp("wd-erin", "uid-wd-erin");
        jdbcTemplate.update(
                "INSERT INTO matches (requester_id, addressee_id, status) VALUES (?, ?, 'pending')",
                dave, erin);

        mockMvc.perform(delete("/api/profile").header("Authorization", "Bearer wd-erin"))
                .andExpect(status().isNoContent());

        Integer left = jdbcTemplate.queryForObject(
                "SELECT count(*) FROM matches WHERE requester_id = ? OR addressee_id = ?",
                Integer.class, dave, dave);
        assertThat(left).isZero();
    }

    @Test
    void 인증_없이는_탈퇴할_수_없다() throws Exception {
        mockMvc.perform(delete("/api/profile").contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isUnauthorized());
    }

    private Integer countOf(String table, String column, Long value) {
        return jdbcTemplate.queryForObject(
                "SELECT count(*) FROM " + table + " WHERE " + column + " = ?", Integer.class, value);
    }
}
