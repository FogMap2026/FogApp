package com.fogapp.visit;

/**
 * 사진 업로드 응답(#48).
 *
 * <p>앱은 여기서 받은 {@code photoUrl} 을 그대로 {@code POST /api/visits} 에 넘긴다.
 * 값을 가공하면 인증 단계의 경로 검증에서 거부된다.</p>
 */
public record VisitPhotoResponse(String photoUrl) {
}
