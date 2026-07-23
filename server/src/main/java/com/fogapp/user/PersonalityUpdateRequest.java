package com.fogapp.user;

import java.util.Map;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * 앱(#31)이 채점한 성향 테스트 결과. personalityScores는
 * docs/personality-test-design.md 4.3 포맷(JSON)을 그대로 받아 JSONB로 저장한다.
 */
public record PersonalityUpdateRequest(
        @NotBlank String personalityType,
        @NotNull Map<String, Object> personalityScores
) {
}
