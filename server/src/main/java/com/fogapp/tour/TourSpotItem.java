package com.fogapp.tour;

/**
 * TourAPI 지역기반관광정보(areaBasedList) 응답의 item 한 건을 정제한 값.
 * mapx=경도(lng), mapy=위도(lat) 로 매핑한다.
 */
public record TourSpotItem(
        String contentId,
        String contentTypeId,
        String title,
        String addr1,
        String addr2,
        String areaCode,
        String sigunguCode,
        String tel,
        String firstImage,
        String firstImage2,
        Double lat,
        Double lng
) {
}
