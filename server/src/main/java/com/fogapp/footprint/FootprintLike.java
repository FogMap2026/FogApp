package com.fogapp.footprint;

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
 * 발자취 좋아요·공감(#23). footprints.like_count 는 이 테이블 기준 캐시 카운트다.
 */
@Entity
@Table(name = "footprint_likes")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class FootprintLike {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "footprint_id", nullable = false)
    private Long footprintId;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private OffsetDateTime createdAt;

    public FootprintLike(Long footprintId, Long userId) {
        this.footprintId = footprintId;
        this.userId = userId;
    }
}
