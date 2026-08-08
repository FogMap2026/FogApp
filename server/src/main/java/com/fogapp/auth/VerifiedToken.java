package com.fogapp.auth;

/**
 * 검증이 끝난 ID 토큰에서 뽑아낸 사용자 정보. Firebase 타입을 상위 계층에 노출하지 않기 위한 경계 DTO.
 */
public record VerifiedToken(
        String uid,
        String email,
        String name,
        String picture
) {
}
