package com.fogapp.footprint;

public record FootprintUpdateRequest(
        String content,
        String photoUrl
) {
}
