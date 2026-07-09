package com.fogapp.match;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record MatchStatusUpdateRequest(
        @NotBlank
        @Pattern(regexp = "pending|accepted|rejected", message = "status는 pending/accepted/rejected 중 하나여야 합니다.")
        String status
) {
}
