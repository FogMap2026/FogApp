package com.fogapp.visit;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * 고아 인증 사진 정리를 주기적으로 실행한다(#76).
 *
 * <p>{@code visit.photo-cleanup.enabled=true} 일 때만 등록된다. 기본은 꺼져 있어
 * 로컬·CI·테스트에서 예상치 못하게 파일이 사라지지 않는다 — 켜는 것은 배포 환경의 선택이다.</p>
 *
 * <p>정리 로직 자체는 {@link VisitPhotoCleaner}에 있다. 실행 시점(스케줄)과 무엇을 지울지를
 * 분리해 두어야 테스트에서 시간을 기다리지 않고 정리 동작만 검증할 수 있다.</p>
 */
@Component
@EnableScheduling
@ConditionalOnProperty(name = "visit.photo-cleanup.enabled", havingValue = "true")
public class VisitPhotoCleanupRunner {

    private final VisitPhotoCleaner cleaner;

    public VisitPhotoCleanupRunner(VisitPhotoCleaner cleaner) {
        this.cleaner = cleaner;
    }

    /** 기본 매일 04:10. 사용자가 적은 시간대를 골랐다. */
    @Scheduled(cron = "${visit.photo-cleanup.cron:0 10 4 * * *}")
    public void run() {
        cleaner.clean();
    }
}
