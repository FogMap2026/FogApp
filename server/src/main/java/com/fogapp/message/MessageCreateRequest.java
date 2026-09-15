package com.fogapp.message;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** 메시지 보내기. 보낸 사람은 담지 않는다 — 인증 토큰의 사용자로만 저장한다(#52). */
public record MessageCreateRequest(
        @NotBlank(message = "메시지 내용이 비어 있습니다.")
        @Size(max = Message.MAX_LENGTH, message = "메시지는 " + Message.MAX_LENGTH + "자 이하여야 합니다.")
        String content
) {
}
