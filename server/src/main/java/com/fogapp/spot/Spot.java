package com.fogapp.spot;

import java.time.OffsetDateTime;

import org.locationtech.jts.geom.Point;

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
 * 관광공사 스팟(#5로 수집). geom 은 DB 트리거(V2 마이그레이션)가 lat/lng 로부터 채우므로
 * 애플리케이션에서는 쓰지 않고 읽기 전용으로만 다룬다.
 */
@Entity
@Table(name = "spots")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Spot {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "content_id", nullable = false, unique = true)
    private String contentId;

    @Column(name = "content_type_id")
    private String contentTypeId;

    @Column(nullable = false)
    private String title;

    private String addr1;
    private String addr2;

    @Column(name = "area_code")
    private String areaCode;

    @Column(name = "sigungu_code")
    private String sigunguCode;

    private String tel;

    @Column(name = "first_image")
    private String firstImage;

    @Column(name = "first_image2")
    private String firstImage2;

    private String overview;

    private Double lat;
    private Double lng;

    // DB 트리거가 lat/lng 으로부터 채운다 — 애플리케이션에서 직접 쓰지 않도록 읽기 전용으로 매핑.
    @Column(insertable = false, updatable = false)
    private Point geom;

    @Column(name = "created_at", insertable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", insertable = false, updatable = false)
    private OffsetDateTime updatedAt;

    public Spot(String contentId, String contentTypeId, String title, String addr1, String addr2,
                String areaCode, String sigunguCode, String tel, String firstImage, String firstImage2,
                String overview, Double lat, Double lng) {
        this.contentId = contentId;
        this.contentTypeId = contentTypeId;
        this.title = title;
        this.addr1 = addr1;
        this.addr2 = addr2;
        this.areaCode = areaCode;
        this.sigunguCode = sigunguCode;
        this.tel = tel;
        this.firstImage = firstImage;
        this.firstImage2 = firstImage2;
        this.overview = overview;
        this.lat = lat;
        this.lng = lng;
    }
}
