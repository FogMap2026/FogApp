package com.fogapp.footprint;

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
 * 발자취(텍스트·사진 기록) — 뼈대(#1-8). 좋아요·공감은 2-7에서 반응 테이블과 함께 확장한다.
 */
@Entity
@Table(name = "footprints")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Footprint {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "spot_id")
    private Long spotId;

    private String content;

    @Column(name = "photo_url")
    private String photoUrl;

    @Column(name = "like_count", nullable = false)
    private int likeCount = 0;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private OffsetDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private OffsetDateTime updatedAt;

    public Footprint(Long userId, Long spotId, String content, String photoUrl) {
        this.userId = userId;
        this.spotId = spotId;
        this.content = content;
        this.photoUrl = photoUrl;
    }

    public void update(String content, String photoUrl) {
        this.content = content;
        this.photoUrl = photoUrl;
    }
}
