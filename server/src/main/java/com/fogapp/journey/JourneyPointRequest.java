package com.fogapp.journey;

import java.time.OffsetDateTime;

import jakarta.validation.constraints.NotNull;

/** 올릴 궤적 한 점(#131). 좌표 범위는 서비스가 본다 — 이상치는 «거르되 나머지는 살린다». */
public record JourneyPointRequest(
        @NotNull Double lat,
        @NotNull Double lng,
        @NotNull OffsetDateTime recordedAt) {
}
