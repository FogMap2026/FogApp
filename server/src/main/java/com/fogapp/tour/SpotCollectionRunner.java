package com.fogapp.tour;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * 기동 시 스팟 수집을 1회 실행하는 배치 러너(#5, #100).
 * {@code tour.collect.on-startup=true} 일 때만 활성화된다(기본 off — CI/일반 실행에는 영향 없음).
 * 재실행해도 content_id 업서트라 중복 적재되지 않는다.
 *
 * <p><b>2단계다.</b> ① 지역별 목록 수집 → ② 소개글이 빈 스팟만 상세조회로 채움.
 * 목록 API 가 소개글을 주지 않아 나눠야 하며, 소개글은 해금 화면이 보여줄 유일한 내용이라
 * ②가 빠지면 스팟을 정복해도 빈 화면이 열린다.</p>
 */
@Component
@ConditionalOnProperty(name = "tour.collect.on-startup", havingValue = "true")
public class SpotCollectionRunner implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(SpotCollectionRunner.class);

    private final SpotCollectionService collectionService;
    private final SpotOverviewCollector overviewCollector;
    private final CollectProperties properties;

    public SpotCollectionRunner(SpotCollectionService collectionService,
                                SpotOverviewCollector overviewCollector,
                                CollectProperties properties) {
        this.collectionService = collectionService;
        this.overviewCollector = overviewCollector;
        this.properties = properties;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (properties.getAreaCodes().isEmpty()) {
            log.warn("tour.collect.on-startup=true 이지만 area-codes 가 비어 있어 수집을 건너뜁니다.");
            return;
        }

        // 수집은 부가 작업이다. 실패해도 서버는 떠야 한다.
        //
        // 예전에는 여기서 예외가 그대로 나가 ApplicationRunner 가 터졌고, Spring Boot 가
        // 기동 자체를 포기했다. docker-compose 의 restart: unless-stopped 와 겹치면
        // "서비스 키가 틀렸다" 는 이유로 서버가 무한 재시작 루프에 빠진다 —
        // API 도 계속 두드리게 된다. 실제로 그렇게 한 번 막혔다.
        try {
            log.info("스팟 수집 배치 시작: 지역 {}", properties.getAreaCodes());
            collectionService.collectAreas(
                    properties.getAreaCodes(), properties.getMaxPages(), properties.getNumOfRows());

            // 목록 API 는 소개글을 주지 않는다. 해금 보상이 비지 않도록 상세조회로 이어서 채운다(#100).
            overviewCollector.fillMissing(properties.getOverviewMaxPerRun());
        } catch (Exception e) {
            log.error("스팟 수집 배치가 실패했습니다. 서버는 계속 뜹니다 — spots 가 비어 있으면 "
                    + "지도에 마커가 없고 정복률이 --% 로 나옵니다. 원인: {}", e.toString(), e);
        }
    }
}
