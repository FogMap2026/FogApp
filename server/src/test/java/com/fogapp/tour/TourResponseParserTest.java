package com.fogapp.tour;

import static org.assertj.core.api.Assertions.assertThat;

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
}
