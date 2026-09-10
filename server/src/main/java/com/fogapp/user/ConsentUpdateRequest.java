package com.fogapp.user;

import jakarta.validation.constraints.AssertTrue;

/**
 * 개인정보·위치정보 수집 동의 요청(#152).
 *
 * <p>둘 다 {@code true}만 허용한다 — 이 앱은 위치 기반이라({@code visits}·{@code footprints}가
 * 안개 걷기·발자취의 핵심), 위치정보 동의 없이는 핵심 기능이 성립하지 않는다. 그래서
 * "부분 동의로 일부 기능만 제한"이 아니라 "전체 동의가 곧 서비스 이용 조건"으로 정했다
 * — #152 to-do의 "동의를 거부하면 어떻게 되는지 정의"에 대한 답이다. 거부하면 앱을 쓸 수
 * 없고, 그 경우 이 엔드포인트를 아예 호출하지 않는다(로그아웃).</p>
 */
public record ConsentUpdateRequest(
        @AssertTrue(message = "개인정보 수집·이용에 동의해야 합니다.")
        boolean privacy,

        @AssertTrue(message = "위치정보 수집·이용에 동의해야 합니다.")
        boolean location
) {
}
