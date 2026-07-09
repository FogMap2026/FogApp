package com.fogapp.auth;

/** ID 토큰 검증 실패(만료·위조·미설정 등). 인증 필터에서 401로 변환한다. */
public class InvalidTokenException extends RuntimeException {

    public InvalidTokenException(String message) {
        super(message);
    }

    public InvalidTokenException(String message, Throwable cause) {
        super(message, cause);
    }
}
