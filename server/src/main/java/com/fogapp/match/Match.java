package com.fogapp.match;

import java.time.OffsetDateTime;

import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

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
 * 성향 매칭(동행) 요청 — 뼈대(#1-8). 성향 유사도 계산(3-8)이 score를 채운다.
 */
@Entity
@Table(name = "matches")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Match {

    public static final String STATUS_PENDING = "pending";
    public static final String STATUS_ACCEPTED = "accepted";
    public static final String STATUS_REJECTED = "rejected";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "requester_id", nullable = false)
    private Long requesterId;

    @Column(name = "addressee_id", nullable = false)
    private Long addresseeId;

    @Column(nullable = false)
    private String status = STATUS_PENDING;

    private Double score;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private OffsetDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private OffsetDateTime updatedAt;

    public Match(Long requesterId, Long addresseeId) {
        if (requesterId.equals(addresseeId)) {
            throw new IllegalArgumentException("requesterId와 addresseeId는 같을 수 없습니다.");
        }
        this.requesterId = requesterId;
        this.addresseeId = addresseeId;
    }

    public void updateStatus(String status) {
        this.status = status;
    }
}
