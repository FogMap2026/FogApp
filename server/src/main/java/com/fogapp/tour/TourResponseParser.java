package com.fogapp.tour;

import java.util.ArrayList;
import java.util.List;

import com.fasterxml.jackson.databind.JsonNode;

/**
 * TourAPI(_type=json) 응답 JSON을 {@link TourSpotItem} 목록으로 정제한다.
 *
 * <p>응답 구조: {@code response.body.items.item[]} — 결과가 없으면 items 가 빈 문자열이거나
 * item 이 없을 수 있고, 결과가 1건이면 item 이 배열이 아닌 단일 객체로 온다. 두 경우 모두 처리한다.
 *
 * <p>⚠️ <b>이 API 는 오류도 HTTP 200 으로 돌려준다.</b> 잘못된 파라미터를 보내면
 * {@code {"resultCode":"10","resultMsg":"INVALID_REQUEST_PARAMETER_ERROR(listYN)"}} 같은 본문이
 * 200 으로 온다. 예외가 나지 않으니 그냥 두면 <b>항목 0건으로 조용히 지나가고</b>, 로그에는
 * "신규 0, 갱신 0, 스킵 0" 만 남아 <b>수집할 게 없는 것과 구분되지 않는다.</b>
 * 실제로 KorService2 전환 때 이것 때문에 원인을 찾는 데 오래 걸렸다.
 * 그래서 {@link #requireOk} 로 본문의 결과 코드를 먼저 확인한다.</p>
 */
public final class TourResponseParser {

    /** 정상 응답 코드. 오퍼레이션에 따라 "0000" 또는 "00" 으로 온다. */
    private static final List<String> OK_CODES = List.of("0000", "00");

    /** 조건에 맞는 결과가 없다는 뜻 — 오류가 아니라 빈 목록이다. */
    private static final List<String> NO_DATA_CODES = List.of("0003", "03");

    private TourResponseParser() {
    }

    public static List<TourSpotItem> parse(JsonNode root) {
        List<TourSpotItem> result = new ArrayList<>();
        if (root == null) {
            return result;
        }
        if (!requireOk(root)) {
            return result; // 결과 없음(NODATA)
        }
        JsonNode items = root.path("response").path("body").path("items");
        if (!items.isObject() || !items.has("item")) {
            return result; // 결과 없음
        }
        JsonNode itemNode = items.get("item");
        if (itemNode.isArray()) {
            for (JsonNode node : itemNode) {
                addIfValid(result, node);
            }
        } else if (itemNode.isObject()) {
            addIfValid(result, itemNode);
        }
        return result;
    }

    /**
     * 공통정보 조회 응답에서 소개글만 뽑는다(#100).
     *
     * <p>목록 응답과 구조는 같지만 항목이 1건이라 {@code item} 이 배열이 아닌 단일 객체로 오는
     * 경우가 흔하다 — 양쪽 다 처리한다.</p>
     *
     * @return 소개글. 항목이 없거나 {@code overview} 가 비어 있으면 null
     */
    public static String parseOverview(JsonNode root) {
        if (root == null) {
            return null;
        }
        if (!requireOk(root)) {
            return null; // 결과 없음(NODATA)
        }
        JsonNode items = root.path("response").path("body").path("items");
        if (!items.isObject() || !items.has("item")) {
            return null;
        }
        JsonNode itemNode = items.get("item");
        JsonNode first = itemNode.isArray()
                ? (itemNode.isEmpty() ? null : itemNode.get(0))
                : itemNode;
        return first == null ? null : text(first, "overview");
    }

    /**
     * 응답 본문의 결과 코드를 확인한다. 오류면 예외를 던져 <b>조용히 지나가지 않게</b> 한다.
     *
     * <p>결과 코드는 두 자리에 나온다 — 정상 응답은 {@code response.header.resultCode},
     * 파라미터 오류 같은 경우는 <b>최상위</b>에 {@code resultCode} 가 온다. 둘 다 본다.</p>
     *
     * @return 항목을 읽어도 되면 true, 결과 없음(NODATA)이면 false
     * @throws IllegalStateException 그 밖의 오류 코드
     */
    private static boolean requireOk(JsonNode root) {
        String code = firstText(root.path("resultCode"), root.path("response").path("header").path("resultCode"));
        if (code == null || OK_CODES.contains(code)) {
            return true;
        }
        if (NO_DATA_CODES.contains(code)) {
            return false;
        }
        String message = firstText(root.path("resultMsg"), root.path("response").path("header").path("resultMsg"));
        throw new IllegalStateException(
                "TourAPI 오류 응답 (HTTP 200): resultCode=" + code + ", resultMsg=" + message);
    }

    private static String firstText(JsonNode... candidates) {
        for (JsonNode node : candidates) {
            if (node != null && node.isTextual() && !node.asText().isBlank()) {
                return node.asText().trim();
            }
        }
        return null;
    }

    private static void addIfValid(List<TourSpotItem> result, JsonNode node) {
        String contentId = text(node, "contentid");
        String title = text(node, "title");
        if (contentId == null || title == null) {
            return; // 식별자/이름 없는 항목은 버린다
        }
        result.add(new TourSpotItem(
                contentId,
                text(node, "contenttypeid"),
                title,
                text(node, "addr1"),
                text(node, "addr2"),
                text(node, "areacode"),
                text(node, "sigungucode"),
                text(node, "tel"),
                text(node, "firstimage"),
                text(node, "firstimage2"),
                parseCoord(text(node, "mapy")),
                parseCoord(text(node, "mapx"))));
    }

    /** 값이 없거나 빈 문자열이면 null 로 정규화한다. */
    private static String text(JsonNode node, String field) {
        JsonNode v = node.get(field);
        if (v == null || v.isNull()) {
            return null;
        }
        String s = v.asText().trim();
        return s.isEmpty() ? null : s;
    }

    private static Double parseCoord(String raw) {
        if (raw == null) {
            return null;
        }
        try {
            return Double.parseDouble(raw);
        } catch (NumberFormatException e) {
            return null;
        }
    }
}
