package com.fogapp.spot;

/**
 * 지도가 소비하는 스팟 응답(#7). 지도 로드에 필요한 좌표·명칭·주소·이미지를 담는다.
 *
 * <p>{@code unlocked}(해금 여부)는 현재 항상 false 다. 방문 인증(Phase 3, visits 테이블)이
 * 붙으면 현재 사용자 기준으로 계산해 채운다 — 앱과의 응답 계약을 미리 확정해 두기 위해 필드는 지금 포함한다.
 */
public record SpotResponse(
        Long id,
        String contentId,
        String contentTypeId,
        String title,
        String addr1,
        String addr2,
        String areaCode,
        String sigunguCode,
        String firstImage,
        Double lat,
        Double lng,
        boolean unlocked
) {
    public static SpotResponse from(Spot spot) {
        return new SpotResponse(
                spot.getId(),
                spot.getContentId(),
                spot.getContentTypeId(),
                spot.getTitle(),
                spot.getAddr1(),
                spot.getAddr2(),
                spot.getAreaCode(),
                spot.getSigunguCode(),
                spot.getFirstImage(),
                spot.getLat(),
                spot.getLng(),
                false);
    }
}
