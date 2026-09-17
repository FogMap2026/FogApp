package com.fogapp.push;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** 기기 등록·해제 요청. 사용자는 담지 않는다 — 인증 토큰의 사용자로만 저장한다(#52). */
public record DeviceTokenRequest(
        @NotBlank @Size(max = 255) String token,
        @Pattern(regexp = "android|ios", message = "platform 은 android/ios 중 하나여야 합니다.") String platform
) {
    /** 앱이 안 보내면 android 로 본다 — 지금 출품 범위가 Android 뿐이다(#137). */
    public String platformOrDefault() {
        return platform == null || platform.isBlank() ? "android" : platform;
    }
}
