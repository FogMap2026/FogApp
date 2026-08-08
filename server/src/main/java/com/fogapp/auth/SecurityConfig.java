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
                        .requestMatchers("/api/health").permitAll()
                        .anyRequest().authenticated())
                .exceptionHandling(eh -> eh.authenticationEntryPoint(authenticationEntryPoint))
                .addFilterBefore(firebaseAuthFilter, UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }
}
