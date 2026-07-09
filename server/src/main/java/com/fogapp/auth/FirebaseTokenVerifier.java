package com.fogapp.auth;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseAuthException;
import com.google.firebase.auth.FirebaseToken;

/**
 * Firebase Admin SDK로 ID 토큰을 검증하는 실제 구현. {@code firebase.enabled=true} 일 때만 주입된다.
 * {@link FirebaseConfig}가 FirebaseApp을 먼저 초기화하도록 의존한다.
 */
@Component
@ConditionalOnProperty(name = "firebase.enabled", havingValue = "true")
public class FirebaseTokenVerifier implements TokenVerifier {

    // FirebaseApp 초기화(FirebaseConfig) 이후 생성되도록 생성자 의존을 둔다.
    public FirebaseTokenVerifier(com.google.firebase.FirebaseApp firebaseApp) {
        // FirebaseAuth.getInstance()는 초기화된 FirebaseApp이 필요하다.
    }

    @Override
    public VerifiedToken verify(String idToken) {
        try {
            FirebaseToken decoded = FirebaseAuth.getInstance().verifyIdToken(idToken);
            return new VerifiedToken(
                    decoded.getUid(),
                    decoded.getEmail(),
                    decoded.getName(),
                    decoded.getPicture());
        } catch (FirebaseAuthException e) {
            throw new InvalidTokenException("Firebase 토큰 검증 실패: " + e.getMessage(), e);
        }
    }
}
