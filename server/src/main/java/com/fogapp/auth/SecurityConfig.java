package com.fogapp.auth;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

import com.fogapp.user.UserService;

/**
 * 무상태(stateless) REST 보안 설정(#4). Firebase 토큰 필터로 인증하며, 세션/CSRF/폼로그인은 사용하지 않는다.
 * 공개 경로: 헬스체크. 그 외 /api/** 는 인증 필요.
 *
 * <p>참고: {@code anyRequest().authenticated()}로 인해 다른 트랙에서 추가되는 API
 * (예: {@code /api/footprints}, {@code /api/matches})도 인증이 필요해진다. 공개가 필요한
 * 경로가 생기면 아래 {@code requestMatchers(...).permitAll()}에 명시적으로 추가한다.</p>
 */
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    private final TokenVerifier tokenVerifier;
    private final UserService userService;
    private final RestAuthenticationEntryPoint authenticationEntryPoint;

    public SecurityConfig(TokenVerifier tokenVerifier,
                          UserService userService,
                          RestAuthenticationEntryPoint authenticationEntryPoint) {
        this.tokenVerifier = tokenVerifier;
        this.userService = userService;
        this.authenticationEntryPoint = authenticationEntryPoint;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        // @Component로 등록하지 않고 직접 생성한다 — 서블릿 컨테이너 자동 등록으로 인한
        // 필터 이중 실행을 막기 위함(FirebaseAuthFilter 클래스 주석 참고).
        FirebaseAuthFilter firebaseAuthFilter = new FirebaseAuthFilter(tokenVerifier, userService);
        http
                .csrf(csrf -> csrf.disable())
                .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        // ⚠️ "/error" 를 빼지 말 것(#221).
                        //
                        // 컨트롤러에서 예외(500)·없는 경로(404)·업로드 용량 초과(413)가 나면
                        // 서블릿 컨테이너가 요청을 "/error" 로 «재디스패치»한다. 그런데
                        // FirebaseAuthFilter 는 OncePerRequestFilter 라 그 재디스패치에서
                        // 다시 돌지 않고, SecurityContext 가 비어 있는 채로 여기 도달한다.
                        // "/error" 가 인증을 요구하면 RestAuthenticationEntryPoint 가
                        // «인증이 필요합니다(401)»로 답해서, 서버의 모든 오류가 401 로
                        // 위장된다 — 앱에서는 로그인 문제로밖에 안 보인다.
                        //
                        // 여기를 열어도 보호 자원이 새지 않는다. 미인증 요청은 필터 단계에서
                        // 이미 401 로 막히고(재디스패치 전), "/error" 는 원래 요청의 상태
                        // 코드를 그대로 돌려줄 뿐이다. 응답 본문은 Spring 기본값이라
                        // 메시지·스택트레이스를 싣지 않는다(server.error.include-* 미설정).
                        .requestMatchers("/api/health", "/error").permitAll()
                        .anyRequest().authenticated())
                .exceptionHandling(eh -> eh.authenticationEntryPoint(authenticationEntryPoint))
                .addFilterBefore(firebaseAuthFilter, UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }
}
