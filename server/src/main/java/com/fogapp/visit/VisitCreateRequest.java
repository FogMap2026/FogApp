package com.fogapp.visit;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * 방문 인증 요청(#48).
 *
 * <p>⚠️ userId 필드는 <b>일부러 없다.</b> 현재 사용자는 인증 필터가 세운 {@code AuthUser} 에서만
 * 얻는다. 클라이언트가 보낸 userId 를 믿으면 남의 명의로 정복 기록을 남길 수 있다(#52 참고).</p>
 *
 * <p>사진은 앱이 Storage 에 먼저 올리고 URL 만 넘긴다 — 서버는 바이너리를 받지 않는다.</p>
 *
 * <p>lat/lng 의 범위 검증은 {@link VisitService} 가 한다 — 서비스를 직접 부르는 경로에서도
 * 같은 규칙이 적용돼야 하고, 범위를 벗어난 좌표는 PostGIS 캐스팅 단계에서 500 이 되기 때문이다.</p>
 */
public record VisitCreateRequest(
        @NotNull Long spotId,
        @NotBlank String photoUrl,
        @NotNull Double lat,
        @NotNull Double lng
) {
}
