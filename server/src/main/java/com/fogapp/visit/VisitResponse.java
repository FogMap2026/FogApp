package com.fogapp.visit;

import java.time.OffsetDateTime;

public record VisitResponse(
        Long id,
        Long userId,
        Long spotId,
        String photoUrl,
        Double lat,
        Double lng,
        OffsetDateTime verifiedAt
) {
    public static VisitResponse from(Visit visit) {
        return new VisitResponse(
                visit.getId(),
                visit.getUserId(),
                visit.getSpotId(),
                visit.getPhotoUrl(),
                visit.getLat(),
                visit.getLng(),
                visit.getVerifiedAt()
        );
    }
}
