package com.fogapp.footprint;

public record FootprintCreateRequest(
        Long spotId,
        String content,
        String photoUrl
) {
}
