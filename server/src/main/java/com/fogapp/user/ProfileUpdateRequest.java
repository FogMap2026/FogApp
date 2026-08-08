package com.fogapp.user;

import jakarta.validation.constraints.Size;

public record ProfileUpdateRequest(
        @Size(max = 50, message = "닉네임은 50자 이하여야 합니다.")
        String nickname,
        String profileImageUrl
) {
}
