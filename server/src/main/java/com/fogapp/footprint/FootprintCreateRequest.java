package com.fogapp.footprint;

import jakarta.validation.constraints.NotNull;

public record FootprintCreateRequest(
        @NotNull Long userId,
        Long spotId,
        String content,
        String photoUrl
) {
}
