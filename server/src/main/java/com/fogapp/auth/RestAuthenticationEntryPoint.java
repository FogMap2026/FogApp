package com.fogapp.auth;

import java.io.IOException;

import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

/**
 * 인증 없이 보호된 경로에 접근했을 때 401 JSON을 반환한다(스프링 시큐리티 기본 리다이렉트/폼 대신).
 */
@Component
public class RestAuthenticationEntryPoint implements AuthenticationEntryPoint {

    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response,
                         AuthenticationException authException) throws IOException {
        FirebaseAuthFilter.writeUnauthorized(response, "인증이 필요합니다.");
    }
}
