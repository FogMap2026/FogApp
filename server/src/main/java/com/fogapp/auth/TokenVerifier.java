package com.fogapp.auth;

/**
 * ID 토큰 검증 추상화. 실제 구현은 Firebase({@link FirebaseTokenVerifier}),
 * 미설정 환경(개발/CI)에서는 {@link DisabledTokenVerifier}가 주입된다.
 * 테스트는 이 인터페이스를 mocking 해 인증 흐름만 검증한다.
 */
public interface TokenVerifier {

    /**
     * @param idToken Authorization 헤더의 Bearer 토큰
     * @return 검증된 사용자 정보
     * @throws InvalidTokenException 토큰이 유효하지 않거나 검증기를 사용할 수 없을 때
     */
    VerifiedToken verify(String idToken);
}
