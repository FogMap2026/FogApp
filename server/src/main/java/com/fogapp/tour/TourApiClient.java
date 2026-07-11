package com.fogapp.tour;

import java.net.URI;
import java.util.List;

import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.util.UriComponentsBuilder;

import com.fasterxml.jackson.databind.JsonNode;

/**
 * 한국관광공사 지역기반관광정보 조회 클라이언트(#5).
 *
 * <p>실제 외부 호출부라 CI에서는 검증하지 않는다(키·네트워크 필요). 응답 정제는
 * {@link TourResponseParser}로 분리해 단위 테스트하고, 적재는 {@link SpotUpserter}로 분리해
 * Testcontainers로 검증한다.
 */
@Component
public class TourApiClient {

    private final RestClient restClient;
    private final TourProperties properties;

    public TourApiClient(RestClient.Builder restClientBuilder, TourProperties properties) {
        this.restClient = restClientBuilder.build();
        this.properties = properties;
    }

    public List<TourSpotItem> fetchAreaBased(String areaCode, int pageNo, int numOfRows) {
        URI uri = UriComponentsBuilder.fromHttpUrl(properties.getBaseUrl() + "/areaBasedList1")
                .queryParam("serviceKey", properties.getServiceKey())
                .queryParam("MobileOS", properties.getMobileOs())
                .queryParam("MobileApp", properties.getMobileApp())
                .queryParam("_type", "json")
                .queryParam("listYN", "Y")
                .queryParam("arrange", "A")
                .queryParam("numOfRows", numOfRows)
                .queryParam("pageNo", pageNo)
                .queryParam("areaCode", areaCode)
                .encode()
                .build()
                .toUri();

        JsonNode body = restClient.get()
                .uri(uri)
                .retrieve()
                .body(JsonNode.class);

        return TourResponseParser.parse(body);
    }
}
