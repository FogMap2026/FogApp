package com.fogapp.journey;

import java.time.OffsetDateTime;

/**
 * 궤적 한 점(#131).
 *
 * <p>앱은 이 좌표들로 안개 구멍을 복원한다 — 서버는 「어디를 지나갔는가」만 돌려주고,
 * 반경(15m)·격자 스냅은 앱의 {@code FogOverlayController} 가 정한다. 반경을 서버가
 * 정하면 앱을 고칠 때마다 서버를 같이 배포해야 한다.</p>
 */
public record JourneyPointResponse(Double lat, Double lng, OffsetDateTime recordedAt) {

    public static JourneyPointResponse from(JourneyPoint point) {
        return new JourneyPointResponse(point.getLat(), point.getLng(), point.getRecordedAt());
    }
}
