package com.fogapp.user;

import java.time.OffsetDateTime;
import java.util.Map;

import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * 내 프로필 응답(#4, 5-3).
 *
 * <p>{@code personalityType}·{@code personalityScores}는 성향 테스트를 아직 안 했으면
 * 각각 null·빈 Map이다 — 화면에서 "테스트 유도" 분기에 쓸 것.</p>
 *
 * <p>{@code personalityScores}는 저장된 JSONB 원문을 그대로 내려주지 않는다.
 * {@link PersonalityScoreParser}로 축별 0~100 점수만 뽑아 {@code Map<축, 점수>}로 준다 —
 * 매칭 유사도 계산({@code MatchService})이 쓰는 것과 같은 파서라 표현이 어긋나지 않는다.</p>
 */
public record ProfileResponse(
        Long id,
        String email,
        String nickname,
        String profileImageUrl,
        String personalityType,
        Map<String, Integer> personalityScores,
        OffsetDateTime createdAt
) {
    public static ProfileResponse from(User user, ObjectMapper objectMapper) {
        return new ProfileResponse(
                user.getId(),
                user.getEmail(),
                user.getNickname(),
                user.getProfileImageUrl(),
                user.getPersonalityType(),
                PersonalityScoreParser.parseAxisScores(objectMapper, user.getPersonalityScores()),
                user.getCreatedAt());
    }
}
