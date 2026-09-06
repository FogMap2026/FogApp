package com.fogapp.tour;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

/**
 * 서비스 키 정규화(#100 후속).
 *
 * <p>여기가 깨지면 증상이 {@code SERVICE_KEY_IS_NOT_REGISTERED_ERROR} 로 나온다 —
 * "키가 잘못 발급됐다"로 읽혀 엉뚱한 곳을 찾게 되는 종류라 테스트로 고정한다.</p>
 */
class TourServiceKeyTest {

    /** 포털의 Decoding 키. base64 원문이라 + / = 가 들어 있다. */
    private static final String DECODING = "abc+def/ghi==";

    /** 같은 키의 Encoding 키. 이미 퍼센트 인코딩돼 있다. */
    private static final String ENCODING = "abc%2Bdef%2Fghi%3D%3D";

    @Test
    void Decoding_키는_퍼센트_인코딩한다() {
        // + 를 그대로 두면 서버가 공백으로 해석해 키가 깨진다.
        assertThat(TourServiceKey.encoded(DECODING)).isEqualTo(ENCODING);
    }

    @Test
    void Encoding_키는_그대로_둔다() {
        // 다시 인코딩하면 % 가 %25 가 되어 이중 인코딩된다 — 실제로 이것 때문에 403 이 났다.
        assertThat(TourServiceKey.encoded(ENCODING)).isEqualTo(ENCODING);
    }

    @Test
    void 어느_쪽을_넣어도_같은_URL이_된다() {
        assertThat(TourServiceKey.encoded(DECODING)).isEqualTo(TourServiceKey.encoded(ENCODING));
    }

    @Test
    void 앞뒤_공백은_지운다() {
        // .env 에 붙여넣을 때 흔히 딸려 온다. 공백이 %20 으로 인코딩되면 키가 달라진다.
        assertThat(TourServiceKey.encoded("  " + ENCODING + "  ")).isEqualTo(ENCODING);
        assertThat(TourServiceKey.encoded("  " + DECODING + "  ")).isEqualTo(ENCODING);
    }

    @Test
    void 키가_없으면_빈_문자열() {
        // 키를 안 넣은 채 배치를 켠 경우. NPE 로 죽는 것보다 빈 값으로 호출해
        // 서버가 주는 "등록되지 않은 서비스키" 를 로그로 보는 편이 낫다.
        assertThat(TourServiceKey.encoded(null)).isEmpty();
        assertThat(TourServiceKey.encoded("")).isEmpty();
        assertThat(TourServiceKey.encoded("   ")).isEmpty();
    }
}
