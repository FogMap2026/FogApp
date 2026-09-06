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

    /**
     * data.go.kr 일반 인증키. <b>Encoding·Decoding 어느 쪽이든 된다</b> —
     * {@link TourServiceKey} 가 정규화한다.
     */
    private String serviceKey;

    /**
     * 오퍼레이션 이름 끝에 붙는 버전 숫자(#100). 예: {@code areaBasedList} + {@code "2"}.
     *
     * <p>TourAPI 4.0 부터 엔드포인트가 {@code KorService2} 이고 오퍼레이션도 {@code ...2} 다.
     * base-url 의 버전과 <b>반드시 짝</b>이어야 하며, 한쪽만 바꾸면 404 가 난다.
     * 발급받은 계정이 구버전(KorService1)이면 base-url 과 이 값을 함께 1 로 되돌리면 된다.</p>
     */
    private String operationSuffix = "2";

    private String baseUrl = "https://apis.data.go.kr/B551011/KorService2";

    private String mobileApp = "FogApp";

    private String mobileOs = "ETC";
}
