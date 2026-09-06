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
 * 발자취 — <b>길목마다 남기는 짧은 글귀</b>(#114, 재설계).
 *
 * <p>원래는 스팟에 남기는 리뷰였다. 지금은 <b>좌표에 붙는다</b> — 스팟이 아닌 길 위 어디에나
 * 남길 수 있고, 지나가던 사람이 지도에서 발견해 읽는다. 설계 근거와 반경 값은
 * {@code docs/footprint-redesign.md} 참고.</p>
 *
 * <p>{@code spotId} 는 여전히 선택적이다. 스팟에서 쓴 글은 채워지고(스팟 상세 목록이 이 값을 쓴다),
 * 길목 글귀는 비어 있다.</p>
 *
 * <p>{@code geom} 은 애플리케이션이 채우지 않는다 — spots·visits 와 동일하게 DB 트리거
 * ({@code trg_footprints_set_geom}, V5)가 lat/lng 로부터 채운다. 그래서 엔티티에 필드를 두지 않는다.</p>
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

    /**
     * 글귀를 남긴 자리(#114).
     *
     * <p>기존 행은 연결된 스팟 좌표로 소급해 채웠다(V5). 스팟이 없거나 스팟 좌표도 없으면
     * null 로 남고, 그런 행은 <b>반경 조회에서 자연히 빠진다.</b></p>
     */
    private Double lat;

    private Double lng;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private OffsetDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private OffsetDateTime updatedAt;

    public Footprint(Long userId, Long spotId, String content, String photoUrl, Double lat, Double lng) {
        this.userId = userId;
        this.spotId = spotId;
        this.content = content;
        this.photoUrl = photoUrl;
        this.lat = lat;
        this.lng = lng;
    }

    public void update(String content, String photoUrl) {
        this.content = content;
        this.photoUrl = photoUrl;
    }
}
