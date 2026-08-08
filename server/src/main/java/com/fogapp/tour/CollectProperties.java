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
}
