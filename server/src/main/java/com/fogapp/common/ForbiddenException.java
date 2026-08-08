package com.fogapp.common;

/** 인증은 됐지만 해당 리소스에 대한 권한이 없을 때(#52) — 예: 남의 발자취 수정, 남의 매칭 상태 변경 시도. */
public class ForbiddenException extends RuntimeException {

    public ForbiddenException(String message) {
        super(message);
    }
}
