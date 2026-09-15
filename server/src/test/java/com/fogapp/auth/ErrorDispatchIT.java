package com.fogapp.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.BDDMockito.given;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

/**
 * 서버 오류가 «401 인증이 필요합니다»로 위장되지 않는지 검증한다(#221).
 *
 * <p>⚠️ <b>MockMvc 로는 이 버그가 재현되지 않는다.</b> MockMvc 는 서블릿 컨테이너의
 * {@code /error} 재디스패치를 흉내 내지 않기 때문에, 위장이 일어나는 경로 자체를
 * 지나가지 않는다. 그래서 {@code RANDOM_PORT} 로 실제 Tomcat 을 띄우고 HTTP 로 친다.
 * 이 테스트를 MockMvc 로 «간소화»하면 버그가 돌아와도 초록불이 켜진다.</p>
 */
@Testcontainers
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class ErrorDispatchIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres =
            new PostgreSQLContainer<>(DockerImageName.parse("postgis/postgis:16-3.4")
                    .asCompatibleSubstituteFor("postgres"));

    @Autowired
    private TestRestTemplate rest;

    @MockBean
    private TokenVerifier tokenVerifier;

    private ResponseEntity<String> getWithToken(String path, String token) {
        HttpHeaders headers = new HttpHeaders();
        if (token != null) {
            headers.setBearerAuth(token);
        }
        return rest.exchange(path, HttpMethod.GET, new HttpEntity<>(headers), String.class);
    }

    /**
     * 핵심 회귀 테스트. 로그인한 사용자가 없는 경로를 부르면 <b>404</b> 가 와야 한다.
     *
     * <p>고치기 전에는 여기서 401 이 왔다 — 배포되지 않은 엔드포인트
     * ({@code /api/journeys}·{@code /api/travelers})가 앱에서 «로그인 문제»로 보였던 이유다.</p>
     */
    @Test
    void 로그인한_사용자가_없는_경로를_부르면_401이_아니라_404() {
        given(tokenVerifier.verify("good-token"))
                .willReturn(new VerifiedToken("uid-error-dispatch", "err@example.com", "오류", null));

        ResponseEntity<String> res = getWithToken("/api/this-endpoint-does-not-exist", "good-token");

        assertThat(res.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    /** "/error" 를 열었다고 보호 자원이 열리면 안 된다 — 보안 회귀 방지. */
    @Test
    void 토큰_없이_보호된_경로를_부르면_여전히_401() {
        ResponseEntity<String> res = getWithToken("/api/profile", null);

        assertThat(res.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    /**
     * 미인증 요청은 없는 경로여도 401 이어야 한다. 404 가 새어 나가면 로그인 없이
     * «어떤 경로가 존재하는지» 를 탐색할 수 있게 된다. 필터 단계에서 재디스패치 전에
     * 막히므로 "/error" 허용과 무관하게 401 이 유지된다.
     */
    @Test
    void 토큰_없이_없는_경로를_불러도_404가_새지_않고_401() {
        ResponseEntity<String> res = getWithToken("/api/this-endpoint-does-not-exist", null);

        assertThat(res.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }
}
