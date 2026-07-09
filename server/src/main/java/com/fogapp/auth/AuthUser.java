package com.fogapp.auth;

/**
 * 인증된 현재 사용자. 인증 필터가 SecurityContext의 principal로 세우고,
 * 컨트롤러는 {@code @AuthenticationPrincipal AuthUser}로 주입받는다.
 */
public record AuthUser(
        Long userId,
        String firebaseUid,
        String email
) {
}
