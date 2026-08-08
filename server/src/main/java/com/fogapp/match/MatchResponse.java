package com.fogapp.match;

import java.time.OffsetDateTime;

public record MatchResponse(
        Long id,
        Long requesterId,
        Long addresseeId,
        String status,
        Double score,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {
    public static MatchResponse from(Match match) {
        return new MatchResponse(
                match.getId(),
                match.getRequesterId(),
                match.getAddresseeId(),
                match.getStatus(),
                match.getScore(),
                match.getCreatedAt(),
                match.getUpdatedAt()
        );
    }
}
