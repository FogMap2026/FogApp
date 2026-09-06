package com.fogapp.tour;

import java.net.URI;
import java.util.List;

import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpClientErrorException;
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
 * <p><b>서비스 키는 Encoding·Decoding 어느 쪽을 넣어도 된다.</b>
 * {@link TourServiceKey} 가 정규화하고, 여기서는 {@code build(true)} 로 <b>다시 인코딩하지
 * 않는다.</b> 예전에는 {@code .encode()} 로 일괄 인코딩해서, Encoding 키를 넣으면
 * {@code %2B} 가 {@code %252B} 로 이중 인코딩돼 {@code SERVICE_KEY_IS_NOT_REGISTERED_ERROR}
 * 가 났다 — 키가 멀쩡한데 등록이 안 됐다고 나와 원인을 찾기 어려운 종류였다.</p>
 *
 * <p>⚠️ {@code build(true)} 는 "이미 인코딩된 값"으로 취급한다는 뜻이다. 여기서 쓰는 나머지
 * 파라미터는 숫자·ASCII 상수뿐이라 안전하지만, <b>한글이나 공백이 들어가는 파라미터를
 * 추가할 때는 직접 인코딩해서 넘겨야 한다.</b></p>
 */
@Component
public class TourApiClient {

    private final RestClient restClient;
    private final TourProperties properties;

    public TourApiClient(RestClient.Builder restClientBuilder, TourProperties properties) {
        this.restClient = restClientBuilder.build();
        this.properties = properties;
    }

    /**
     * 지역기반 관광정보 조회. 목록만 주고 소개글({@code overview})은 주지 않는다.
     *
     * <p>⚠️ <b>{@code listYN} 을 보내면 안 된다.</b> KorService1 에는 있었지만 KorService2 에서
     * 없어졌고, 보내면 {@code resultCode: "10"} 과 함께
     * {@code INVALID_REQUEST_PARAMETER_ERROR(listYN)} 이 온다.</p>
     *
     * <p>이때 <b>HTTP 는 200 이라 예외가 나지 않는다.</b> 파서가 항목을 못 찾아 빈 목록을
     * 돌려주고, 로그에는 "신규 0, 갱신 0, 스킵 0" 만 남는다 — <b>수집할 게 없는 것과 구분되지
     * 않는다.</b> 파라미터를 추가·변경할 때는 응답 본문의 {@code resultCode} 를 직접 확인할 것.</p>
     */
    public List<TourSpotItem> fetchAreaBased(String areaCode, int pageNo, int numOfRows) {
        URI uri = base("areaBasedList")
                .queryParam("arrange", "A")
                .queryParam("numOfRows", numOfRows)
                .queryParam("pageNo", pageNo)
                .queryParam("areaCode", areaCode)
                // 이미 인코딩된 것으로 취급한다 — 서비스 키를 다시 인코딩하면 깨진다.
                .build(true)
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
                .build(true)
                .toUri();

        return TourResponseParser.parseOverview(get(uri));
    }

    /** 공통 질의 파라미터를 세운다. 오퍼레이션 이름 끝의 버전 숫자는 설정에서 붙인다. */
    private UriComponentsBuilder base(String operation) {
        return UriComponentsBuilder
                .fromHttpUrl(properties.getBaseUrl() + "/" + operation + properties.getOperationSuffix())
                .queryParam("serviceKey", TourServiceKey.encoded(properties.getServiceKey()))
                .queryParam("MobileOS", properties.getMobileOs())
                .queryParam("MobileApp", properties.getMobileApp())
                .queryParam("_type", "json");
    }

    private JsonNode get(URI uri) {
        try {
            return restClient.get().uri(uri).retrieve().body(JsonNode.class);
        } catch (HttpClientErrorException.TooManyRequests e) {
            // 한도 소진은 다른 실패와 다르다 — 다음 건도 반드시 실패한다.
            // 호출부가 "그 건만 넘기고 계속" 하지 않도록 구분해서 올린다.
            throw new TourApiQuotaExceededException("관광공사 API 일일 호출 한도를 소진했습니다.", e);
        }
    }
}
