package com.fogapp.auth;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * Firebase가 꺼져 있을 때(기본값·CI) 주입되는 검증기. 어떤 토큰도 통과시키지 않는다.
 * 실제 인증은 {@code firebase.enabled=true} 로 켜서 {@link FirebaseTokenVerifier}를 사용한다.
 */
@Component
@ConditionalOnProperty(name = "firebase.enabled", havingValue = "false", matchIfMissing = true)
public class DisabledTokenVerifier implements TokenVerifier {

    @Override
    public VerifiedToken verify(String idToken) {
        throw new InvalidTokenException("토큰 검증기가 비활성화되어 있습니다(firebase.enabled=false).");
    }
}
