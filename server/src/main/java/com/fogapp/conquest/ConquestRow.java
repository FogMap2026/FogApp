package com.fogapp.conquest;

/**
 * 정복률 집계 쿼리의 행 투영(#51). 네이티브 쿼리의 따옴표 별칭과 이름이 일치해야 한다.
 */
public interface ConquestRow {

    String getAreaCode();

    /** 시/군/구 코드. 관광공사 데이터에 비어 있는 스팟이 있어 null 일 수 있다. */
    String getSigunguCode();

    /** 대표 시/도 이름 (예: 경상북도). spots.addr1 의 첫 토큰. */
    String getSidoName();

    /** 대표 시/군/구 이름 (예: 경주시). spots.addr1 의 두 번째 토큰. */
    String getSigunguName();

    long getTotalSpots();

    long getVisitedSpots();
}
