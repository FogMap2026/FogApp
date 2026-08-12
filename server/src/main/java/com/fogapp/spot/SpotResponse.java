package com.fogapp.spot;

/**
 * 지도가 소비하는 스팟 응답(#7, #50). 지도 로드에 필요한 좌표·명칭·주소·이미지를 담는다.
 *
 * <p>{@code unlocked} 는 <b>요청한 사용자 기준</b>으로 계산된다 — 그 사용자가 이 스팟을
 * 인증(visits)했는지 여부다. 같은 스팟이라도 사용자마다 값이 다르다.</p>
 *
 * <p>{@code overview}(소개)는 <b>해금 전에는 서버가 아예 내려주지 않는다</b>(#50).
 * 앱에서만 가리면 API 를 직접 호출해 우회할 수 있어 "탐험의 보상"이 성립하지 않는다.
 * 명칭·주소는 그대로 내려준다 — 어디로 갈지 정하는 데 필요한 정보이고, 앱이 잠긴 스팟에서는
 * 이미 일반 문구로 대체해 표시한다.</p>
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
        String overview,
        Double lat,
        Double lng,
        boolean unlocked
) {
    /**
     * 스팟을 응답으로 바꾼다.
     *
     * <p>{@code unlocked} 를 반드시 받는다 — 기본값 false 짜리 오버로드를 두면 호출부가
     * 사용자 판정을 잊어도 컴파일이 통과해, 모두에게 영원히 잠긴 응답이 조용히 나간다.
     * 실제로 그 상태가 #50 을 막고 있었다.</p>
     */
    public static SpotResponse from(Spot spot, boolean unlocked) {
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
                unlocked ? spot.getOverview() : null,
                spot.getLat(),
                spot.getLng(),
                unlocked);
    }
}
