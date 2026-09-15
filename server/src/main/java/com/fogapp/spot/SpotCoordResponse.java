package com.fogapp.spot;

/**
 * 스팟의 id 와 좌표만(#223). 안개 구역 나누기가 전국 스팟을 한 번에 받을 때 쓴다 —
 * 제목·주소·소개를 다 실으면 12,600건이 수 MB 인데, 이 셋만이면 500KB 남짓이다.
 */
public record SpotCoordResponse(long id, double lat, double lng) {
}
