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
            //    사용자는 다시 시도할 텐데 우리 쪽엔 이미 아무것도 없다.
            //
            // 🔴 그래서 로그 «등급»이 이 실패의 유일한 출구다. warn 이면 묻힌다 —
            //    남는 것은 우리가 약속한 파기의 일부(이메일)이고, 사람이 손으로
            //    지워야 한다. uid 를 실어야 그게 가능하다(#182).
            log.error("인증 계정 삭제 실패 — 수동 삭제 필요 uid={} : {}", firebaseUid, e.toString());
            return false;
        }
    }
}
