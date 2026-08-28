package com.fogapp.tour;

import java.net.URI;
import java.util.List;

import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.util.UriComponentsBuilder;

import com.fasterxml.jackson.databind.JsonNode;

/**
 * 한국관광공사 TourAPI 클라이언트(#5, #100).
 *
 * <p>실제 외부 호출부라 CI에서는 검증하지 않는다(키·네트워크 필요). 응답 정제는
 * {@link TourResponseParser}로 분리해 단위 테스트하고, 적재는 {@link SpotUpserter}로 분리해
 * Testcontainers로 검증한다.
 *
 * <p><b>KorService2(TourAPI 4.0) 기준이다.</b> 오퍼레이션 이름 끝의 버전 숫자가 base-url 의
 * 버전과 짝이라, 둘 중 하나만 바꾸면 404 가 난다. 그래서 숫자를 문자열에 박지 않고
 * {@link TourProperties#getOperationSuffix()} 로 함께 움직이게 한다.</p>
 *
 * <p>서비스 키는 <b>디코딩 키</b>를 넣어야 한다. 아래 {@code .encode()} 가 한 번 인코딩하므로,
 * 포털의 Encoding 키를 그대로 넣으면 이중 인코딩되어 {@code SERVICE_KEY_IS_NOT_REGISTERED_ERROR}
 * 가 난다 — 키가 멀쩡한데 등록이 안 됐다고 나오는 경우 대부분 이것이다.</p>
 */
@Component
public class TourApiClient {

    private final RestClient restClient;
    private final TourProperties properties;

    public TourApiClient(RestClient.Builder restClientBuilder, TourProperties properties) {
        this.restClient = restClientBuilder.build();
        this.properties = properties;
    }

    /** 지역기반 관광정보 조회. 목록만 주고 소개글({@code overview})은 주지 않는다. */
    public List<TourSpotItem> fetchAreaBased(String areaCode, int pageNo, int numOfRows) {
        URI uri = base("areaBasedList")
                .queryParam("listYN", "Y")
                .queryParam("arrange", "A")
                .queryParam("numOfRows", numOfRows)
                .queryParam("pageNo", pageNo)
                .queryParam("areaCode", areaCode)
                .encode()
                .build()
                .toUri();

        return TourResponseParser.parse(get(uri));
    }

    /**
     * 공통정보 조회 — <b>소개글({@code overview})을 얻는 유일한 경로</b>(#100).
     *
     * <p>스팟 1건당 1회 호출이라 목록 수집보다 훨씬 비싸다. 호출량 관리는
     * {@link SpotOverviewCollector} 가 한다.</p>
     *
     * @return 소개글. 항목이 없거나 소개글이 비어 있으면 null
     */
    public String fetchOverview(String contentId) {
        URI uri = base("detailCommon")
                .queryParam("contentId", contentId)
                .encode()
                .build()
                .toUri();

        return TourResponseParser.parseOverview(get(uri));
    }

    /** 공통 질의 파라미터를 세운다. 오퍼레이션 이름 끝의 버전 숫자는 설정에서 붙인다. */
    private UriComponentsBuilder base(String operation) {
        return UriComponentsBuilder
                .fromHttpUrl(properties.getBaseUrl() + "/" + operation + properties.getOperationSuffix())
                .queryParam("serviceKey", properties.getServiceKey())
                .queryParam("MobileOS", properties.getMobileOs())
                .queryParam("MobileApp", properties.getMobileApp())
                .queryParam("_type", "json");
    }

    private JsonNode get(URI uri) {
        return restClient.get().uri(uri).retrieve().body(JsonNode.class);
    }
}
