package com.fogapp.traveler;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;

/**
 * 위치 게시 요청(#133). {@code userId} 는 담지 않는다 — 인증 필터가 세운 현재
 * 사용자로만 저장한다(#52 에서 발자취·매칭이 겪은 문제와 같은 이유).
 *
 * <p>좌표 자체는 응답에도, DB 에도 남지 않는다 — 서버가 가장 가까운 스팟으로
 * 환산해 그 id 만 저장한다.</p>
 */
public record TravelerPositionRequest(
        @NotNull @DecimalMin("-90") @DecimalMax("90") Double lat,
        @NotNull @DecimalMin("-180") @DecimalMax("180") Double lng
) {
}
