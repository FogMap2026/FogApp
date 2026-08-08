package com.fogapp.visit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

/**
 * 인증 사진 URL 출처 검증(#56 리뷰 후속). 컨테이너 없이 순수 로직만 본다.
 */
class VisitPhotoUrlValidatorTest {

    private static final String BUCKET = "fogmap-9355b.firebasestorage.app";
    private static final String UID = "abc123UID";
    private static final Long SPOT_ID = 42L;

    private static VisitPhotoUrlValidator validator(String bucket, boolean firebaseEnabled) {
        VisitProperties props = new VisitProperties();
        props.setStorageBucket(bucket);
        return new VisitPhotoUrlValidator(props, firebaseEnabled);
    }

    private static String downloadUrl(String objectPath) {
        // Firebase 다운로드 URL은 객체 경로를 퍼센트 인코딩해 담는다.
        return "https://firebasestorage.googleapis.com/v0/b/" + BUCKET + "/o/"
                + objectPath.replace("/", "%2F") + "?alt=media&token=6f0c6d1e-abc";
    }

    @Nested
    class 버킷이_설정된_경우 {

        private final VisitPhotoUrlValidator sut = validator(BUCKET, false);

        @Test
        void 본인_경로면_통과한다() {
            String url = downloadUrl("visits/" + UID + "/" + SPOT_ID + "/1712345678901.jpg");

            assertThatCode(() -> sut.validate(url, UID, SPOT_ID)).doesNotThrowAnyException();
        }

        @Test
        void 남의_UID_경로면_거부한다() {
            String url = downloadUrl("visits/SOMEONE_ELSE/" + SPOT_ID + "/1.jpg");

            assertThatThrownBy(() -> sut.validate(url, UID, SPOT_ID))
                    .isInstanceOf(IllegalArgumentException.class);
        }

        @Test
        void 다른_스팟_경로면_거부한다() {
            String url = downloadUrl("visits/" + UID + "/999/1.jpg");

            assertThatThrownBy(() -> sut.validate(url, UID, SPOT_ID))
                    .isInstanceOf(IllegalArgumentException.class);
        }

        @Test
        void 외부_호스트면_거부한다() {
            assertThatThrownBy(() -> sut.validate("https://evil.com/aaa.jpg", UID, SPOT_ID))
                    .isInstanceOf(IllegalArgumentException.class);
        }

        @Test
        void 다른_버킷이면_거부한다() {
            String url = "https://firebasestorage.googleapis.com/v0/b/other-bucket.app/o/"
                    + ("visits/" + UID + "/" + SPOT_ID + "/1.jpg").replace("/", "%2F");

            assertThatThrownBy(() -> sut.validate(url, UID, SPOT_ID))
                    .isInstanceOf(IllegalArgumentException.class);
        }

        @Test
        void visits_밖의_경로면_거부한다() {
            String url = downloadUrl("public/" + UID + "/" + SPOT_ID + "/1.jpg");

            assertThatThrownBy(() -> sut.validate(url, UID, SPOT_ID))
                    .isInstanceOf(IllegalArgumentException.class);
        }

        @Test
        void UID_접두사만_같은_경로를_통과시키지_않는다() {
            // visits/abc123UIDEXTRA/... 가 visits/abc123UID/ 로 오인되면 안 된다.
            String url = downloadUrl("visits/" + UID + "EXTRA/" + SPOT_ID + "/1.jpg");

            assertThatThrownBy(() -> sut.validate(url, UID, SPOT_ID))
                    .isInstanceOf(IllegalArgumentException.class);
        }

        @Test
        void 스팟ID_접두사만_같은_경로를_통과시키지_않는다() {
            // spotId=42 인데 421 경로가 통과하면 안 된다.
            String url = downloadUrl("visits/" + UID + "/421/1.jpg");

            assertThatThrownBy(() -> sut.validate(url, UID, SPOT_ID))
                    .isInstanceOf(IllegalArgumentException.class);
        }

        @Test
        void URL_형식이_아니면_거부한다() {
            assertThatThrownBy(() -> sut.validate("not a url at all", UID, SPOT_ID))
                    .isInstanceOf(IllegalArgumentException.class);
        }
    }

    @Nested
    class 버킷이_비어있는_경우 {

        private final VisitPhotoUrlValidator sut = validator("", false);

        @Test
        void 검증이_꺼진다() {
            assertThat(sut.isEnabled()).isFalse();
        }

        @Test
        void 어떤_URL도_통과시킨다() {
            assertThatCode(() -> sut.validate("https://evil.com/aaa.jpg", UID, SPOT_ID))
                    .doesNotThrowAnyException();
        }

        @Test
        void firebase가_켜져_있으면_기동을_중단한다() {
            // 검증이 꺼진 채로 실제 서비스가 뜨는 것을 막는다.
            assertThatThrownBy(() -> validator("", true))
                    .isInstanceOf(IllegalStateException.class)
                    .hasMessageContaining("visit.storage-bucket");
        }
    }
}
