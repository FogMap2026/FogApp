package com.fogapp.tour;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.List;

import org.junit.jupiter.api.Test;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * TourAPI 응답 정제 로직 단위 테스트(#5). 외부 호출 없이 파싱만 검증한다.
 */
class TourResponseParserTest {

    private final ObjectMapper mapper = new ObjectMapper();

    private JsonNode json(String s) throws JsonProcessingException {
        return mapper.readTree(s);
    }

    @Test
    void 배열_응답을_정제한다_mapx는_lng_mapy는_lat() throws Exception {
        JsonNode root = json("""
                {"response":{"body":{"items":{"item":[
                  {"contentid":"126508","contenttypeid":"12","title":"불국사","addr1":"경북 경주시",
                   "areacode":"35","sigungucode":"2","mapx":"129.3320","mapy":"35.7900","firstimage":"http://img"},
                  {"contentid":"264570","title":"경복궁","mapx":"","mapy":""}
                ]},"numOfRows":2,"pageNo":1,"totalCount":2}}}
                """);

        List<TourSpotItem> items = TourResponseParser.parse(root);

        assertThat(items).hasSize(2);
        TourSpotItem first = items.get(0);
        assertThat(first.contentId()).isEqualTo("126508");
        assertThat(first.title()).isEqualTo("불국사");
        assertThat(first.lng()).isEqualTo(129.3320);
        assertThat(first.lat()).isEqualTo(35.7900);
        // 좌표가 빈 문자열이면 null
        assertThat(items.get(1).lat()).isNull();
        assertThat(items.get(1).lng()).isNull();
    }

    @Test
    void 결과가_한건이면_item이_배열이_아니어도_정제한다() throws Exception {
        JsonNode root = json("""
                {"response":{"body":{"items":{"item":
                  {"contentid":"1","title":"단건","mapx":"127.0","mapy":"37.0"}
                }}}}
                """);

        List<TourSpotItem> items = TourResponseParser.parse(root);

        assertThat(items).hasSize(1);
        assertThat(items.get(0).contentId()).isEqualTo("1");
    }

    @Test
    void 결과가_없으면_빈_목록을_반환한다() throws Exception {
        JsonNode root = json("""
                {"response":{"body":{"items":""}}}
                """);

        assertThat(TourResponseParser.parse(root)).isEmpty();
    }

    @Test
    void contentId나_title이_없는_항목은_버린다() throws Exception {
        JsonNode root = json("""
                {"response":{"body":{"items":{"item":[
                  {"title":"아이디없음","mapx":"127.0","mapy":"37.0"},
                  {"contentid":"2","mapx":"127.0","mapy":"37.0"}
                ]}}}}
                """);

        assertThat(TourResponseParser.parse(root)).isEmpty();
    }

    // ── 소개글 파싱 (#100) ────────────────────────────────────────────────

    @Test
    void 공통정보_응답에서_소개글을_뽑는다() throws Exception {
        JsonNode root = json("""
                {"response":{"header":{"resultCode":"0000"},"body":{"items":{"item":[
                  {"contentid":"126508","title":"경복궁","overview":"조선왕조 제일의 법궁이다."}
                ]}}}}
                """);

        assertThat(TourResponseParser.parseOverview(root)).isEqualTo("조선왕조 제일의 법궁이다.");
    }

    @Test
    void 항목이_배열이_아니어도_소개글을_뽑는다() throws Exception {
        // 상세조회는 1건이라 item 이 단일 객체로 오는 경우가 흔하다.
        JsonNode root = json("""
                {"response":{"body":{"items":{"item":
                  {"contentid":"126508","overview":"단일 객체로 온 소개글"}
                }}}}
                """);

        assertThat(TourResponseParser.parseOverview(root)).isEqualTo("단일 객체로 온 소개글");
    }

    @Test
    void 소개글이_비어_있으면_null이다() throws Exception {
        // 빈 문자열을 그대로 저장하면 "채워진 것"으로 오인돼 다음 실행이 건너뛴다.
        JsonNode root = json("""
                {"response":{"body":{"items":{"item":[{"contentid":"1","overview":"  "}]}}}}
                """);

        assertThat(TourResponseParser.parseOverview(root)).isNull();
    }

    @Test
    void 결과가_없으면_소개글은_null이다() throws Exception {
        assertThat(TourResponseParser.parseOverview(json("""
                {"response":{"body":{"items":""}}}
                """))).isNull();
        assertThat(TourResponseParser.parseOverview(null)).isNull();
    }

    // ── 오류 응답 (#100 후속) ─────────────────────────────────────────────
    // 이 API 는 오류도 HTTP 200 으로 돌려준다. 조용히 0건으로 지나가면
    // "수집할 게 없다" 와 구분되지 않아, KorService2 전환 때 원인 찾기가 오래 걸렸다.

    @Test
    void 파라미터_오류는_예외로_드러낸다() throws Exception {
        // KorService2 로 옮기며 실제로 받은 응답. listYN 은 이 버전에 없는 파라미터다.
        JsonNode root = json("""
                {"responseTime":"2026-09-03T16:59:12.891","resultCode":"10",
                 "resultMsg":"INVALID_REQUEST_PARAMETER_ERROR(listYN)"}
                """);

        assertThatThrownBy(() -> TourResponseParser.parse(root))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("resultCode=10")
                .hasMessageContaining("listYN");
    }

    @Test
    void header_안에_있는_오류_코드도_잡는다() throws Exception {
        JsonNode root = json("""
                {"response":{"header":{"resultCode":"99","resultMsg":"UNKNOWN_ERROR"}}}
                """);

        assertThatThrownBy(() -> TourResponseParser.parse(root))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("resultCode=99");
    }

    @Test
    void 일일_한도_소진은_전용_예외로_구분한다() throws Exception {
        // 다른 실패와 달라야 한다 — 남은 건도 전부 실패하므로 호출부가 그 실행을 멈춘다.
        JsonNode root = json("""
                {"response":{"header":{"resultCode":"22",
                 "resultMsg":"LIMITED_NUMBER_OF_SERVICE_REQUESTS_EXCEEDS_ERROR"}}}
                """);

        assertThatThrownBy(() -> TourResponseParser.parse(root))
                .isInstanceOf(TourApiQuotaExceededException.class)
                .hasMessageContaining("일일 호출 한도");
    }

    @Test
    void 결과_없음은_오류가_아니라_빈_목록이다() throws Exception {
        // NODATA 는 정상이다 — 그 지역에 스팟이 없을 뿐이라 예외로 만들면 배치가 멈춘다.
        JsonNode root = json("""
                {"response":{"header":{"resultCode":"03","resultMsg":"NODATA_ERROR"}}}
                """);

        assertThat(TourResponseParser.parse(root)).isEmpty();
        assertThat(TourResponseParser.parseOverview(root)).isNull();
    }
}
