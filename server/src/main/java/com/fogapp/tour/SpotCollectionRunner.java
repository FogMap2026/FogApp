package com.fogapp.tour;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * 기동 시 스팟 수집을 1회 실행하는 배치 러너(#5).
 * {@code tour.collect.on-startup=true} 일 때만 활성화된다(기본 off — CI/일반 실행에는 영향 없음).
 * 재실행해도 content_id 업서트라 중복 적재되지 않는다.
 */
@Component
@ConditionalOnProperty(name = "tour.collect.on-startup", havingValue = "true")
public class SpotCollectionRunner implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(SpotCollectionRunner.class);

    private final SpotCollectionService collectionService;
    private final CollectProperties properties;

    public SpotCollectionRunner(SpotCollectionService collectionService, CollectProperties properties) {
        this.collectionService = collectionService;
        this.properties = properties;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (properties.getAreaCodes().isEmpty()) {
            log.warn("tour.collect.on-startup=true 이지만 area-codes 가 비어 있어 수집을 건너뜁니다.");
            return;
        }
        log.info("스팟 수집 배치 시작: 지역 {}", properties.getAreaCodes());
        collectionService.collectAreas(
                properties.getAreaCodes(), properties.getMaxPages(), properties.getNumOfRows());
    }
}
