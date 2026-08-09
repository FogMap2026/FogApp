package com.fogapp.visit;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

import lombok.Getter;
import lombok.Setter;

/**
 * 방문 인증 설정(#48).
 *
 * <p>⚠️ {@code radiusMeters} 는 앱의 근접 감지(#45)가 쓰는 값과 <b>반드시 같아야 한다.</b>
 * 어긋나면 "화면에는 인증 가능이라고 떴는데 서버가 거부"하는, 재현하기 어려운 버그가 된다.
 * 값을 바꿀 때는 앱 쪽 상수도 함께 바꾸고 planning.md Phase 3 합의 항목을 갱신할 것.</p>
 */
@Component
@ConfigurationProperties(prefix = "visit")
@Getter
@Setter
public class VisitProperties {

    /** 인증 가능 반경(m). 팀 합의 전 잠정값 — 확정 시 앱(#45)과 함께 변경할 것. */
    private double radiusMeters = 100;

    /**
     * 인증 사진이 저장되는 Firebase Storage 버킷 (예: {@code fogmap-9355b.firebasestorage.app}).
     *
     * <p>비어 있으면 photoUrl 출처 검증을 건너뛴다(로컬·CI). 단
     * {@code firebase.enabled=true} 인 환경에서는 반드시 설정해야 하며,
     * 없으면 {@link VisitPhotoUrlValidator} 가 기동을 중단시킨다.</p>
     */
    private String storageBucket = "";
}
