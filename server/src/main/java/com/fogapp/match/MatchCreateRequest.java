package com.fogapp.match;

import jakarta.validation.constraints.NotNull;

public record MatchCreateRequest(
        @NotNull Long requesterId,
        @NotNull Long addresseeId
) {
}
