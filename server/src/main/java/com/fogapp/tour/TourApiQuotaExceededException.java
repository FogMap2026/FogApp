package com.fogapp.tour;

/**
 * 관광공사 API 일일 호출 한도를 소진했을 때(#100 후속).
 *
 * <p><b>다른 실패와 구분해야 하는 이유:</b> 보통의 실패는 그 건만 넘기고 계속 가는 게 맞다 —
 * 소개글이 없는 스팟 하나 때문에 나머지를 포기할 이유가 없다. 그런데 한도 소진은
 * <b>다음 건도 100% 실패</b>한다. 계속 두드려도 채워지는 건 없고 로그만 수백 줄 쌓인다.</p>
 *
 * <p>그래서 이 예외만은 잡아서 넘기지 않고 <b>그 실행을 즉시 멈춘다.</b>
 * 한도는 매일 초기화되므로 남은 것은 다음 날 실행이 이어서 채운다.</p>
 *
 * <p>응답은 두 형태로 온다 — HTTP 429, 또는 HTTP 200 본문의 {@code resultCode: "22"}
 * ({@code LIMITED_NUMBER_OF_SERVICE_REQUESTS_EXCEEDS_ERROR}). 양쪽 다 이 예외로 모은다.</p>
 */
public class TourApiQuotaExceededException extends RuntimeException {

    public TourApiQuotaExceededException(String message) {
        super(message);
    }

    public TourApiQuotaExceededException(String message, Throwable cause) {
        super(message, cause);
    }
}
