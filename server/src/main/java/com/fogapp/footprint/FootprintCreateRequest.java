package com.fogapp.footprint;

/**
 * 발자취 작성 요청(#114).
 *
 * <p>{@code lat}·{@code lng} 는 글귀를 남기는 자리다. 좌표가 없으면 지도에 뜨지 않고
 * 반경 조회에서도 빠진다 — 스팟 상세 목록에만 남는다.</p>
 *
 * <p>⚠️ <b>좌표 범위 검증과 "내 주변 10m" 규칙은 아직 없다</b>(#115). 지금은 받은 값을
 * 그대로 저장한다.</p>
 */
public record FootprintCreateRequest(
        Long spotId,
        String content,
        String photoUrl,
        Double lat,
        Double lng
) {
}
