package com.fogapp.visit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fogapp.auth.TokenVerifier;
import com.fogapp.auth.VerifiedToken;
import com.fogapp.spot.Spot;
import com.fogapp.spot.SpotRepository;

/**
 * 인증 사진 업로드·조회 엔드포인트(#48)의 접근 통제를 검증한다.
 *
 * <p>핵심은 <b>남의 사진을 볼 수 없다</b>는 것이다(#68 리뷰). 파일명이 예측 불가능하다는 것만으로는
 * 방어가 되지 않는다 — URL 이 어떤 경로로든 새어나가면 로그인한 누구나 열람할 수 있게 되기 때문이다.</p>
 *
 * <p>저장 경로는 {@code build/} 아래로 돌려 저장소를 더럽히지 않는다.</p>
 */
@Testcontainers
@SpringBootTest
@AutoConfigureMockMvc
@TestPropertySource(properties = "visit.photo-storage-path=build/test-visit-photos")
class VisitPhotoControllerIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres =
            new PostgreSQLContainer<>(DockerImageName.parse("postgis/postgis:16-3.4")
                    .asCompatibleSubstituteFor("postgres"));

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private TokenVerifier tokenVerifier;

    @Autowired
    private SpotRepository spotRepository;

    /**
     * 업로드는 실제로 존재하는 스팟에만 허용된다(#76) — 하드코딩한 id 를 쓰면
     * 스팟 존재 검증에 걸려 404 가 된다. 테스트마다 스팟을 만들어 그 id 를 쓴다.
     */
    private long spotId;

    @BeforeEach
    void createSpot() {
        Spot spot = spotRepository.save(new Spot(
                "PHOTO-IT-" + System.nanoTime(), "12", "사진테스트", "주소", null,
                "1", "1", null, null, null, null, 37.5665, 126.9780));
        spotId = spot.getId();
    }

    private void loginAs(String token, String uid) {
        given(tokenVerifier.verify(token)).willReturn(new VerifiedToken(uid, uid + "@example.com", null, null));
    }

    private static MockMultipartFile jpeg() {
        return new MockMultipartFile("file", "photo.jpg", "image/jpeg",
                new byte[]{(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, 1, 2, 3});
    }

    /** 업로드하고 응답의 photoUrl 을 돌려준다. */
    private String upload(String token, long spotId) throws Exception {
        String body = mockMvc.perform(multipart("/api/visits/photo")
                        .file(jpeg())
                        .param("spotId", String.valueOf(spotId))
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return objectMapper.readTree(body).get("photoUrl").asText();
    }

    @Test
    void 업로드하면_본인_UID_경로의_URL을_돌려준다() throws Exception {
        loginAs("alice-token", "uid-alice");

        String photoUrl = upload("alice-token", spotId);

        assertThat(photoUrl).startsWith("/api/visits/photos/uid-alice/" + spotId + "/");
    }

    @Test
    void 본인_사진은_조회할_수_있다() throws Exception {
        loginAs("alice-token", "uid-alice");
        String photoUrl = upload("alice-token", spotId);

        mockMvc.perform(get(photoUrl).header("Authorization", "Bearer alice-token"))
                .andExpect(status().isOk());
    }

    @Test
    void 남의_사진은_조회할_수_없다() throws Exception {
        loginAs("alice-token", "uid-alice");
        String photoUrl = upload("alice-token", spotId);

        // URL 을 알아도 남의 것이면 막혀야 한다 — 파일명 추측 불가에만 기대지 않는다.
        loginAs("bob-token", "uid-bob");
        mockMvc.perform(get(photoUrl).header("Authorization", "Bearer bob-token"))
                .andExpect(status().isForbidden());
    }

    @Test
    void 인증_없이는_업로드할_수_없다() throws Exception {
        mockMvc.perform(multipart("/api/visits/photo")
                        .file(jpeg())
                        .param("spotId", String.valueOf(spotId)))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void 인증_없이는_사진을_조회할_수_없다() throws Exception {
        loginAs("alice-token", "uid-alice");
        String photoUrl = upload("alice-token", spotId);

        mockMvc.perform(get(photoUrl))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void 없는_사진은_404다() throws Exception {
        loginAs("alice-token", "uid-alice");

        mockMvc.perform(get("/api/visits/photos/uid-alice/42/1712345678901-0a1b2c3d4e5f6071.jpg")
                        .header("Authorization", "Bearer alice-token"))
                .andExpect(status().isNotFound());
    }
}
