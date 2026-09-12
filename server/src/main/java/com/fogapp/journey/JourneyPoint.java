package com.fogapp.journey;

import java.time.OffsetDateTime;

import org.hibernate.annotations.CreationTimestamp;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * 사용자가 지나간 자리(#131) — 안개를 15m 반경으로 걷는 데 쓴다.
 *
 * <p>안개가 걷히는 축이 둘이다. <b>인증한 스팟</b>은 150m 로 {@code visits} 에 남고,
 * <b>걸어온 자리</b>는 15m 로 여기 남는다. 그전까지 궤적은 앱 메모리에만 있어
 * <b>앱을 끄면 사라졌다.</b></p>
 *
 * <p>🔴 <b>정복률과는 무관하다.</b> 정복률은 {@code visits} 로 계산한다
 * ({@code GET /api/conquest}). 걸어서 걷힌 안개가 정복으로 세어지면 사진 인증을 할
 * 이유가 없어진다 — 「도달 → <b>인증</b> → 해제」가 이 게임의 규칙이다.</p>
 *
 * <p>{@code recordedAt} 은 <b>단말이 측위한 시각</b>이지 서버 도착 시각이 아니다.
 * batch 로 모아 올리므로 둘이 크게 벌어질 수 있고, {@code (user_id, recorded_at)}
 * 유니크가 <b>재전송을 멱등하게</b> 만든다.</p>
 *
 * <p>{@code geom} 은 애플리케이션이 채우지 않는다 — spots(V2)·visits(V4)·footprints(V5)
 * 와 동일하게 DB 트리거({@code trg_journey_points_set_geom}, V9)가 채운다. 그래서
 * 엔티티에 필드를 두지 않는다.</p>
 */
@Entity
@Table(name = "journey_points")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class JourneyPoint {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(nullable = false)
    private Double lat;

    @Column(nullable = false)
    private Double lng;

    @Column(name = "recorded_at", nullable = false)
    private OffsetDateTime recordedAt;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private OffsetDateTime createdAt;

    public JourneyPoint(Long userId, Double lat, Double lng, OffsetDateTime recordedAt) {
        this.userId = userId;
        this.lat = lat;
        this.lng = lng;
        this.recordedAt = recordedAt;
    }
}
