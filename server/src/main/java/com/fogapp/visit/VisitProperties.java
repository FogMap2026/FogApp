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
     * 인증 사진을 저장할 디렉터리. 서버가 직접 보관한다(팀 결정 B안).
     *
     * <p>Firebase Storage 는 무료(Spark) 요금제에서 버킷 생성이 막혀 사용하지 않는다.
     * 로그인(Firebase Auth)·푸시(FCM)는 그대로 쓰고 <b>사진만</b> 서버에 둔다.</p>
     *
     * <p>⚠️ 배포 시 이 경로를 <b>영속 볼륨</b>에 마운트해야 한다. 컨테이너 재시작으로
     * 사라지면 이미 인증된 방문의 사진이 통째로 유실된다(Phase 7 배포 구성 항목).</p>
     */
    private String photoStoragePath = "./data/visit-photos";

    /** 인증 사진 1장당 허용 최대 바이트. 앱이 업로드 전에 리사이즈·압축하는 것을 전제로 한다. */
    private long maxPhotoBytes = 5L * 1024 * 1024;

    /**
     * 인증되지 않은 사진을 남겨두는 시간(시간 단위, #76).
     *
     * <p>업로드와 인증이 분리돼 있어, 방금 올린 사진은 아직 참조가 없는 게 정상이다.
     * 이 시간이 지난 뒤에도 {@code visits}가 가리키지 않으면 고아로 보고 정리한다.
     * 너무 짧으면 사용자가 사진을 확인하는 동안 파일이 사라진다.</p>
     */
    private long photoRetentionHours = 24;

    /** 고아 사진 정리 배치 설정(#76). */
    private final PhotoCleanup photoCleanup = new PhotoCleanup();

    @Getter
    @Setter
    public static class PhotoCleanup {

        /** 기본 off — 로컬·CI 에서 파일이 예고 없이 사라지지 않게 한다. 배포 환경에서 켠다. */
        private boolean enabled = false;

        private String cron = "0 10 4 * * *";
    }
}
