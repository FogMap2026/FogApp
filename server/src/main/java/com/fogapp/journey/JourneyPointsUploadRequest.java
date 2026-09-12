package com.fogapp.journey;

import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;

/**
 * 궤적 batch 업로드(#131).
 *
 * <p><b>점 하나마다 POST 하지 않는다.</b> 위치가 15m 마다 갱신되므로 걷는 내내 요청이
 * 쏟아진다 — 발자취 반경 조회(#115)에 스로틀을 둔 것과 같은 이유다. 앱이 모아 보낸다.</p>
 *
 * <p>🔴 <b>개수 상한을 서버가 강제한다.</b> 앱이 오래 끊겼다 붙으면 수천 개를 한 번에
 * 밀어올릴 수 있는데, 그건 앱 버그일 때 <b>서버가 먼저 죽는</b> 구조다.
 * {@code SpotQueryService.MAX_RADIUS_METERS}(20km)·발자취 최대 200건과 같은 성격이다.</p>
 */
public record JourneyPointsUploadRequest(
        @NotEmpty(message = "points 가 비어 있습니다.")
        @Size(max = JourneyPointsUploadRequest.MAX_POINTS,
              message = "한 번에 올릴 수 있는 궤적은 " + JourneyPointsUploadRequest.MAX_POINTS + "개까지입니다.")
        @Valid List<JourneyPointRequest> points) {

    public static final int MAX_POINTS = 200;
}
