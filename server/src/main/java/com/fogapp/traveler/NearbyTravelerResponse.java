package com.fogapp.traveler;

import java.time.OffsetDateTime;

import com.fogapp.traveler.TravelerPositionRepository.NearbyTravelerRow;

/**
 * 주변 익명 여행자 한 명(#133). {@code userId}·닉네임·프로필 이미지를 절대
 * 담지 않는다 — 담는 순간 "저 여행자"가 "그 사람"이 되어 익명이 깨진다.
 *
 * <p>{@code lat}/{@code lng} 는 <b>스팟의 좌표</b>다(원래 공개 정보). 여행자 본인의
 * 정밀 좌표는 애초에 저장하지 않으므로 내려줄 수도 없다.</p>
 */
public record NearbyTravelerResponse(Long spotId, double lat, double lng, OffsetDateTime seenAt) {

    public static NearbyTravelerResponse from(NearbyTravelerRow row) {
        return new NearbyTravelerResponse(row.getSpotId(), row.getLat(), row.getLng(), row.getSeenAt());
    }
}
