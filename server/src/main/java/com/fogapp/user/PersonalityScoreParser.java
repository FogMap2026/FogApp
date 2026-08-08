package com.fogapp.user;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * users.personality_scores(JSON 문자열, docs/personality-test-design.md 4.3 포맷)에서
 * 축별 0~100 점수만 뽑아낸다. 매칭 유사도 계산(#37) 등 원본 JSON 구조를 몰라도 되게 한다.
 */
public final class PersonalityScoreParser {

    public static final List<String> AXES = List.of("spontaneity", "restVsRoam", "extraversion");

    private PersonalityScoreParser() {
    }

    /**
     * @return 축 이름 -> 0~100 점수. personalityScoresJson이 null이거나 파싱할 수 없으면 빈 Map.
     */
    public static Map<String, Integer> parseAxisScores(ObjectMapper objectMapper, String personalityScoresJson) {
        if (personalityScoresJson == null) {
            return Map.of();
        }
        try {
            JsonNode axes = objectMapper.readTree(personalityScoresJson).path("axes");
            Map<String, Integer> result = new LinkedHashMap<>();
            for (String axis : AXES) {
                JsonNode score = axes.path(axis).path("score");
                if (score.isInt()) {
                    result.put(axis, score.asInt());
                }
            }
            return result;
        } catch (Exception e) {
            return Map.of();
        }
    }
}
