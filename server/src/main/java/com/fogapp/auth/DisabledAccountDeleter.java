package com.fogapp.auth;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * Firebase 가 꺼져 있을 때(기본값·CI) 주입된다. 아무것도 지우지 않되 <b>조용히 넘어가지 않는다</b>.
 *
 * <p>탈퇴 자체를 막지는 않는다 — 우리 DB 의 개인정보는 지워져야 하고, 그게 방침이 약속한
 * 파기의 본체다. 다만 인증 계정이 남았다는 사실은 로그에 남긴다.</p>
 */
@Component
@ConditionalOnProperty(name = "firebase.enabled", havingValue = "false", matchIfMissing = true)
public class DisabledAccountDeleter implements AuthAccountDeleter {

    private static final Logger log = LoggerFactory.getLogger(DisabledAccountDeleter.class);

    @Override
    public boolean delete(String firebaseUid) {
        log.warn("인증 계정 삭제 건너뜀 (firebase.enabled=false) uid={}", firebaseUid);
        return false;
    }
}
