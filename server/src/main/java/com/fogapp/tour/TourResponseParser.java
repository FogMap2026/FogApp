package com.fogapp.tour;

import java.util.ArrayList;
import java.util.List;

import com.fasterxml.jackson.databind.JsonNode;

/**
 * TourAPI(_type=json) 응답 JSON을 {@link TourSpotItem} 목록으로 정제한다.
 *
 * <p>응답 구조: {@code response.body.items.item[]} — 결과가 없으면 items 가 빈 문자열이거나
 * item 이 없을 수 있고, 결과가 1건이면 item 이 배열이 아닌 단일 객체로 온다. 두 경우 모두 처리한다.
 */
public final class TourResponseParser {

    private TourResponseParser() {
    }

    public static List<TourSpotItem> parse(JsonNode root) {
        List<TourSpotItem> result = new ArrayList<>();
        if (root == null) {
            return result;
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
