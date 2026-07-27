package com.fogapp.match;

import java.util.Map;

import com.fogapp.user.PersonalityScoreParser;

/**
 * 성향 축 점수(0~100) 벡터 간 유클리드 거리 기반 유사도(docs/personality-test-design.md 5장).
 */
public final class PersonalitySimilarity {

    private static final double MAX_DISTANCE = Math.sqrt(PersonalityScoreParser.AXES.size() * Math.pow(100, 2));

    private PersonalitySimilarity() {
    }

    /** 두 사용자 모두 모든 축 점수를 가지고 있어야 유사도를 계산할 수 있다. */
    public static boolean hasAllAxes(Map<String, Integer> axisScores) {
        return axisScores.keySet().containsAll(PersonalityScoreParser.AXES);
    }

    /**
     * @return 0~1 유사도(1에 가까울수록 성향이 비슷함)
     * @throws IllegalArgumentException 두 Map 중 하나라도 축이 모자랄 때
     */
    public static double similarity(Map<String, Integer> a, Map<String, Integer> b) {
        if (!hasAllAxes(a) || !hasAllAxes(b)) {
            throw new IllegalArgumentException("두 사용자 모두 모든 축(spontaneity/restVsRoam/extraversion) 점수가 필요합니다.");
        }

        double sumSquares = 0;
        for (String axis : PersonalityScoreParser.AXES) {
            double diff = a.get(axis) - b.get(axis);
            sumSquares += diff * diff;
        }

        double distance = Math.sqrt(sumSquares);
        return 1 - (distance / MAX_DISTANCE);
    }
}
