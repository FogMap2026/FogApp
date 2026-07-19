package com.fogapp.auth;

import java.io.IOException;
import java.util.List;

import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;

import com.fogapp.user.User;
import com.fogapp.user.UserService;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

/**
 * Authorization: Bearer &lt;idToken&gt; 헤더를 검증해 현재 사용자를 SecurityContext에 세운다(#4).
 *
 * <ul>
 *   <li>토큰 없음 → 그대로 통과(보호된 경로는 SecurityConfig의 EntryPoint가 401)</li>
 *   <li>토큰 있음·유효 → 사용자 업서트 후 인증 설정</li>
 *   <li>토큰 있음·무효 → 즉시 401</li>
 * </ul>
 *
 * <p>일부러 {@code @Component}로 등록하지 않는다. 스프링 부트가 컨텍스트의 {@code Filter} 빈을
 * 서블릿 컨테이너에 {@code /*} 로 자동 등록하면, Security 체인 안에서 한 번(SecurityConfig의
 * {@code addFilterBefore}) + 서블릿 레벨에서 한 번, 총 두 번 실행된다. 이를 막기 위해
 * {@link SecurityConfig}에서 직접 인스턴스를 생성해 체인에만 등록한다.</p>
 */
public class FirebaseAuthFilter extends OncePerRequestFilter {

    private static final String BEARER_PREFIX = "Bearer ";

    private final TokenVerifier tokenVerifier;
    private final UserService userService;

    public FirebaseAuthFilter(TokenVerifier tokenVerifier, UserService userService) {
        this.tokenVerifier = tokenVerifier;
        this.userService = userService;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        String header = request.getHeader("Authorization");
        if (header == null || !header.startsWith(BEARER_PREFIX)) {
            filterChain.doFilter(request, response);
            return;
        }

        String idToken = header.substring(BEARER_PREFIX.length()).trim();
        try {
            VerifiedToken verified = tokenVerifier.verify(idToken);
            User user = userService.upsertFromToken(verified);
            AuthUser principal = new AuthUser(user.getId(), user.getFirebaseUid(), user.getEmail());

            var authentication = new UsernamePasswordAuthenticationToken(
                    principal, null, List.of(new SimpleGrantedAuthority("ROLE_USER")));
            SecurityContextHolder.getContext().setAuthentication(authentication);

            filterChain.doFilter(request, response);
        } catch (InvalidTokenException e) {
            SecurityContextHolder.clearContext();
            writeUnauthorized(response, "유효하지 않은 토큰입니다.");
        }
    }

    static void writeUnauthorized(HttpServletResponse response, String message) throws IOException {
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setContentType("application/json;charset=UTF-8");
        response.getWriter().write("{\"message\":\"" + message + "\"}");
    }
}
