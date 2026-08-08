package com.fogapp.conquest;

import org.springframework.util.StringUtils;

/**
 * 지역별 정복률(#51). 지역 단위는 시/군/구다.
 *
 * @param regionCode   지역 식별자 {@code "{areaCode}-{sigunguCode}"} (예: {@code "35-2"}).
 *                     시군구 코드가 없는 스팟 묶음은 {@code "{areaCode}-"} 가 된다.
 * @param regionName   표시용 이름 (예: {@code "경상북도 경주시"}). 뽑지 못하면 {@code regionCode} 로 폴백.
 * @param totalSpots   해당 지역의 전체 스팟 수 (분모)
 * @param visitedSpots 내가 인증한 스팟 수 (분자)
 * @param rate         정복률 0.0~1.0. 표시 반올림은 앱이 한다.
 */
public record ConquestResponse(
        String regionCode,
        String regionName,
        long totalSpots,
        long visitedSpots,
        double rate
) {
    public static ConquestResponse from(ConquestRow row) {
        String code = row.getAreaCode() + "-" + (row.getSigunguCode() == null ? "" : row.getSigunguCode());

        long total = row.getTotalSpots();
        // GROUP BY 특성상 total 이 0 인 그룹은 나올 수 없지만, 0 나눗셈은 방어해 둔다.
        double rate = total == 0 ? 0 : (double) row.getVisitedSpots() / total;

        return new ConquestResponse(code, buildName(row, code), total, row.getVisitedSpots(), rate);
    }

    /**
     * 관광공사 데이터는 주소 품질 편차가 커서 addr1 이 비어 있는 스팟이 있다.
     * 이름을 못 만들면 앱이 코드라도 표시할 수 있게 폴백한다.
     */
    private static String buildName(ConquestRow row, String fallback) {
        String sido = row.getSidoName();
        String sigungu = row.getSigunguName();

        if (!StringUtils.hasText(sido)) {
            return fallback;
        }
        return StringUtils.hasText(sigungu) ? sido + " " + sigungu : sido;
    }
}
