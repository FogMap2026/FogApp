package com.fogapp.traveler;

import java.time.OffsetDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * 주변 여행자 익명 표시(#133, 6-3)를 위한 최신 위치 한 건.
 *
 * <p>{@code userId} 가 그대로 기본키다 — 이용자별로 행이 <b>많아야 하나</b>다. 이력
 * 테이블이 아니다(신고 접수본 "이용자별 최신 위치 1건만 유지"). 행이 있으면 공유
 * 중, 없으면 꺼짐(opt-in) — 별도 boolean 플래그를 두지 않는다.</p>
 *
 * <p>좌표는 담지 않는다. {@code nearestSpotId} 로만 환산해 저장한다 — #133 설계의
 * "스팟 기준"이 저장 형태 자체로 강제된다.</p>
 */
@Entity
@Table(name = "traveler_positions")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class TravelerPosition {

    @Id
    @Column(name = "user_id")
    private Long userId;

    @Column(name = "nearest_spot_id", nullable = false)
    private Long nearestSpotId;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    public TravelerPosition(Long userId, Long nearestSpotId, OffsetDateTime updatedAt) {
        this.userId = userId;
        this.nearestSpotId = nearestSpotId;
        this.updatedAt = updatedAt;
    }
}
