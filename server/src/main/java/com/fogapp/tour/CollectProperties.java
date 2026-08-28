package com.fogapp.tour;

import java.util.List;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

import lombok.Getter;
import lombok.Setter;

/**
 * 스팟 수집 배치 설정(#5). on-startup=true 일 때만 기동 시 자동 수집한다(기본 off).
 */
@Component
@ConfigurationProperties(prefix = "tour.collect")
@Getter
@Setter
public class CollectProperties {

    private boolean onStartup = false;

    /** 수집할 지역 코드 목록(예: 1=서울, 6=부산, 39=제주). */
    private List<String> areaCodes = List.of();

    private int numOfRows = 100;

    private int maxPages = 10;

    /**
     * 한 번 실행에 소개글을 채울 최대 스팟 수(#100).
     *
     * <p>상세조회는 스팟 1건당 1회라 목록 수집과 비용이 다르다 — 목록 1,000건을 받으면
     * 상세도 1,000회다. 일일 트래픽 한도에 한 번에 다 쓰지 않도록 묶어 두고, 남은 것은
     * 다음 실행이 이어서 채운다.</p>
     */
    private int overviewMaxPerRun = 200;
}
