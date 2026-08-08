package com.fogapp.visit;

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
 * 방문 인증 기록(#48). 스팟에 실제로 도달해 사진을 찍었다는 사실을 남긴다.
 *
 * <p>{@code visits (user_id, spot_id)} 유니크로 한 사용자당 스팟 1회만 정복된다(V1 스키마).
 * 이 행이 생기는 것이 안개 해제(3-5)·스팟 해금(3-6)·정복률(3-7)의 공통 기준점이다.</p>
 *
 * <p>{@code geom} 은 애플리케이션이 채우지 않는다 — spots 와 동일하게 DB 트리거
 * ({@code trg_visits_set_geom}, V4)가 lat/lng 로부터 채운다. 이유는 ERD.md 설계 노트 참고.</p>
 */
@Entity
@Table(name = "visits")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Visit {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "spot_id", nullable = false)
    private Long spotId;

    /** 인증 사진 URL(Storage). 업로드는 앱이 먼저 끝내고 URL만 넘긴다. */
    @Column(name = "photo_url", nullable = false)
    private String photoUrl;

    /** 인증 당시 사용자 위치. 서버가 스팟 반경 안인지 검증한 뒤에만 저장된다. */
    private Double lat;

    private Double lng;

    /**
     * 인증 시각. DB에도 {@code DEFAULT now()} 가 있지만 애플리케이션에서 채운다 —
     * DB 기본값에 맡기면 저장 직후 엔티티가 이 값을 모르고, 생성 응답에 null 이 담긴다.
     */
    @CreationTimestamp
    @Column(name = "verified_at", updatable = false)
    private OffsetDateTime verifiedAt;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private OffsetDateTime createdAt;

    public Visit(Long userId, Long spotId, String photoUrl, Double lat, Double lng) {
        this.userId = userId;
        this.spotId = spotId;
        this.photoUrl = photoUrl;
        this.lat = lat;
        this.lng = lng;
    }
}
