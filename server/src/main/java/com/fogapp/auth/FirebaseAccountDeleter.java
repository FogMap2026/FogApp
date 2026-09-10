package com.fogapp.auth;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseAuthException;

/** Firebase Admin SDK 로 인증 계정을 지운다. {@code firebase.enabled=true} 일 때만 주입된다. */
@Component
@ConditionalOnProperty(name = "firebase.enabled", havingValue = "true")
public class FirebaseAccountDeleter implements AuthAccountDeleter {

    private static final Logger log = LoggerFactory.getLogger(FirebaseAccountDeleter.class);

    // FirebaseApp 초기화(FirebaseConfig) 이후 생성되도록 생성자 의존을 둔다.
    public FirebaseAccountDeleter(com.google.firebase.FirebaseApp firebaseApp) {
    }

    @Override
    public boolean delete(String firebaseUid) {
        try {
            FirebaseAuth.getInstance().deleteUser(firebaseUid);
            log.info("인증 계정 삭제 uid={}", firebaseUid);
            return true;
        } catch (FirebaseAuthException e) {
            // 🔑 여기서 예외를 던지면 «DB 는 지워졌는데 탈퇴가 실패한 것처럼» 보인다.
            //    사용자는 다시 시도할 텐데 우리 쪽엔 이미 아무것도 없다. 로그만 남긴다.
            log.warn("인증 계정 삭제 실패 uid={} : {}", firebaseUid, e.toString());
            return false;
        }
    }
}
