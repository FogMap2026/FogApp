package com.fogapp.visit;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;

/**
 * 인증 사진 URL 출처 검증(#48). 컨테이너 없이 순수 로직만 본다.
 *
 * <p>사진을 서버가 직접 보관하므로(팀 결정 B안), 검증 대상은 Firebase 다운로드 URL이 아니라
 * 업로드 응답이 돌려준 상대 경로 {@code /api/visits/photos/{uid}/{spotId}/{파일}} 이다.</p>
 */
class VisitPhotoUrlValidatorTest {

    private static final String UID = "abc123UID";
    private static final Long SPOT_ID = 42L;

    private final VisitPhotoUrlValidator sut = new VisitPhotoUrlValidator();

    private static String photoUrl(String uid, Object spotId, String fileName) {
        return "/api/visits/photos/" + uid + "/" + spotId + "/" + fileName;
    }

    @Test
    void 본인_경로면_통과한다() {
        String url = photoUrl(UID, SPOT_ID, "1712345678901-0a1b2c3d4e5f6071.jpg");

        assertThatCode(() -> sut.validate(url, UID, SPOT_ID)).doesNotThrowAnyException();
    }

    @Test
    void 남의_UID_경로면_거부한다() {
        String url = photoUrl("SOMEONE_ELSE", SPOT_ID, "1.jpg");

        assertThatThrownBy(() -> sut.validate(url, UID, SPOT_ID))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void 다른_스팟_경로면_거부한다() {
        String url = photoUrl(UID, 999, "1.jpg");

        assertThatThrownBy(() -> sut.validate(url, UID, SPOT_ID))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void 외부_URL이면_거부한다() {
        // 서버가 보관하므로 외부 호스트 URL은 인증 근거가 될 수 없다.
        assertThatThrownBy(() -> sut.validate("https://evil.com/aaa.jpg", UID, SPOT_ID))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void 절대_URL_형태면_거부한다() {
        // 호스트가 붙은 형태는 받지 않는다 — 업로드 응답 그대로만 통과시킨다.
        String url = "https://api.fogapp.example.com" + photoUrl(UID, SPOT_ID, "1.jpg");

        assertThatThrownBy(() -> sut.validate(url, UID, SPOT_ID))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void visits_사진_경로가_아니면_거부한다() {
        assertThatThrownBy(() -> sut.validate("/api/footprints/photos/" + UID + "/1.jpg", UID, SPOT_ID))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void 경로_이탈_시도를_거부한다() {
        String url = "/api/visits/photos/" + UID + "/" + SPOT_ID + "/../../other/1/1.jpg";

        assertThatThrownBy(() -> sut.validate(url, UID, SPOT_ID))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void UID_접두사만_같은_경로를_통과시키지_않는다() {
        // visits/abc123UIDEXTRA/... 가 visits/abc123UID/ 로 오인되면 안 된다.
        String url = photoUrl(UID + "EXTRA", SPOT_ID, "1.jpg");

        assertThatThrownBy(() -> sut.validate(url, UID, SPOT_ID))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void 스팟ID_접두사만_같은_경로를_통과시키지_않는다() {
        // spotId=42 인데 421 경로가 통과하면 안 된다.
        String url = photoUrl(UID, 421, "1.jpg");

        assertThatThrownBy(() -> sut.validate(url, UID, SPOT_ID))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void 하위_디렉터리를_더_판_경로는_거부한다() {
        String url = photoUrl(UID, SPOT_ID, "sub/1.jpg");

        assertThatThrownBy(() -> sut.validate(url, UID, SPOT_ID))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void 파일명이_없으면_거부한다() {
        String url = photoUrl(UID, SPOT_ID, "");

        assertThatThrownBy(() -> sut.validate(url, UID, SPOT_ID))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void photoUrl이_비면_거부한다() {
        assertThatThrownBy(() -> sut.validate("", UID, SPOT_ID))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
