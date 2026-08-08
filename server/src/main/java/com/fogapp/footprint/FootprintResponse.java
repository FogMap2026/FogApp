package com.fogapp.footprint;

import java.time.OffsetDateTime;

public record FootprintResponse(
        Long id,
        Long userId,
        Long spotId,
        String content,
        String photoUrl,
        int likeCount,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {
    public static FootprintResponse from(Footprint footprint) {
        return new FootprintResponse(
                footprint.getId(),
                footprint.getUserId(),
                footprint.getSpotId(),
                footprint.getContent(),
                footprint.getPhotoUrl(),
                footprint.getLikeCount(),
                footprint.getCreatedAt(),
                footprint.getUpdatedAt()
        );
    }
}
