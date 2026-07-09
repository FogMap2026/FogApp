package com.fogapp.tour;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

import lombok.Getter;
import lombok.Setter;

/**
 * TourAPI 접속 설정(#5). 서비스 키는 환경 변수(TOUR_API_SERVICE_KEY)로 주입한다.
 */
@Component
@ConfigurationProperties(prefix = "tour.api")
@Getter
@Setter
public class TourProperties {

    /** data.go.kr 일반 인증키(Decoding 키 사용 권장 — 클라이언트가 URL 인코딩한다). */
    private String serviceKey;

    private String baseUrl = "https://apis.data.go.kr/B551011/KorService1";

    private String mobileApp = "FogApp";

    private String mobileOs = "ETC";
}
