package com.fogapp.user;

import java.time.OffsetDateTime;

public record ProfileResponse(
        Long id,
        String email,
        String nickname,
        String profileImageUrl,
        OffsetDateTime createdAt
) {
    public static ProfileResponse from(User user) {
        return new ProfileResponse(
                user.getId(),
                user.getEmail(),
                user.getNickname(),
                user.getProfileImageUrl(),
                user.getCreatedAt());
    }
}
