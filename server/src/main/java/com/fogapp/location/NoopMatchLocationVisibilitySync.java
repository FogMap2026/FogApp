package com.fogapp.location;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * {@code firebase.enabled=false}일 때(로컬 개발·CI 기본값) 주입되는 아무 일도 안 하는
 * 구현. {@link com.fogapp.auth.DisabledTokenVerifier}와 같은 이유다 — Firestore
 * 자격증명이 없는 환경에서도 {@link com.fogapp.match.MatchService}가 컴파일·실행돼야 한다.
 */
@Component
@ConditionalOnProperty(name = "firebase.enabled", havingValue = "false", matchIfMissing = true)
public class NoopMatchLocationVisibilitySync implements MatchLocationVisibilitySync {

    @Override
    public void grant(String userAFirebaseUid, String userBFirebaseUid) {
        // 아무 일도 하지 않는다.
    }

    @Override
    public void revoke(String userAFirebaseUid, String userBFirebaseUid) {
        // 아무 일도 하지 않는다.
    }
}
