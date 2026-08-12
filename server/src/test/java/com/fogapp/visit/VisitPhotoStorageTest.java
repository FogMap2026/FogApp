package com.fogapp.visit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.stream.Stream;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.core.io.Resource;
import org.springframework.mock.web.MockMultipartFile;

/**
 * 인증 사진 저장(#48). Storage Security Rules 가 하던 방어를 서버가 대신하므로,
 * 그 방어가 실제로 서는지 확인한다 — 본인 경로 강제·용량·형식·경로 이탈.
 */
class VisitPhotoStorageTest {

    private static final String UID = "abc123UID";
    private static final Long SPOT_ID = 42L;

    @TempDir
    Path tempDir;

    private VisitPhotoStorage sut;

    @BeforeEach
    void setUp() {
        sut = storageWithMaxBytes(5L * 1024 * 1024);
    }

    private VisitPhotoStorage storageWithQuota(long maxBytesPerUser) {
        VisitProperties props = new VisitProperties();
        props.setPhotoStoragePath(tempDir.toString());
        props.setMaxPhotoBytesPerUser(maxBytesPerUser);
        return new VisitPhotoStorage(props);
    }

    // ── 용량 상한·정리 (#76) ─────────────────────────────────────────────

    @Test
    void 같은_스팟에_재업로드하면_이전_사진은_지워진다() throws Exception {
        String first = sut.store(UID, SPOT_ID, jpeg(new byte[]{1}));
        String second = sut.store(UID, SPOT_ID, jpeg(new byte[]{2}));

        assertThat(first).isNotEqualTo(second);

        Path dir = tempDir.resolve(UID).resolve(String.valueOf(SPOT_ID));
        try (Stream<Path> files = Files.list(dir)) {
            // 스팟당 1장만 남는다 — 재업로드가 쌓이면 디스크가 무한정 늘어난다.
            assertThat(files.filter(Files::isRegularFile).toList()).hasSize(1);
        }
    }

    @Test
    void 다른_스팟의_사진은_지우지_않는다() throws Exception {
        sut.store(UID, SPOT_ID, jpeg(new byte[]{1}));
        sut.store(UID, 99L, jpeg(new byte[]{2}));

        assertThat(Files.list(tempDir.resolve(UID).resolve(String.valueOf(SPOT_ID))).count()).isEqualTo(1);
        assertThat(Files.list(tempDir.resolve(UID).resolve("99")).count()).isEqualTo(1);
    }

    @Test
    void 사용자_총_용량을_넘으면_거부한다() {
        VisitPhotoStorage tight = storageWithQuota(40);
        tight.store(UID, 1L, jpeg(new byte[20]));   // 23바이트

        assertThatThrownBy(() -> tight.store(UID, 2L, jpeg(new byte[20])))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("총 용량");
    }

    @Test
    void 같은_스팟_덮어쓰기는_상한_근처에서도_허용한다() {
        // 교체될 파일을 사용량에서 빼지 않으면, 상한에 닿은 순간 덮어쓰기조차 막힌다.
        VisitPhotoStorage tight = storageWithQuota(40);
        tight.store(UID, SPOT_ID, jpeg(new byte[20]));

        assertThatCode(() -> tight.store(UID, SPOT_ID, jpeg(new byte[20])))
                .doesNotThrowAnyException();
    }

    @Test
    void 다른_사용자의_사용량은_내_상한에_포함되지_않는다() {
        VisitPhotoStorage tight = storageWithQuota(40);
        tight.store("otherUser", 1L, jpeg(new byte[20]));

        assertThatCode(() -> tight.store(UID, 1L, jpeg(new byte[20])))
                .doesNotThrowAnyException();
    }

    private VisitPhotoStorage storageWithMaxBytes(long maxBytes) {
        VisitProperties props = new VisitProperties();
        props.setPhotoStoragePath(tempDir.toString());
        props.setMaxPhotoBytes(maxBytes);
        return new VisitPhotoStorage(props);
    }

    private static MockMultipartFile jpeg(byte[] tail) {
        byte[] head = {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF};
        byte[] bytes = new byte[head.length + tail.length];
        System.arraycopy(head, 0, bytes, 0, head.length);
        System.arraycopy(tail, 0, bytes, head.length, tail.length);
        return new MockMultipartFile("file", "photo.jpg", "image/jpeg", bytes);
    }

    private static MockMultipartFile png() {
        byte[] bytes = {(byte) 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3, 4};
        return new MockMultipartFile("file", "photo.png", "image/png", bytes);
    }

    private static MockMultipartFile webp() {
        byte[] bytes = {'R', 'I', 'F', 'F', 0, 0, 0, 0, 'W', 'E', 'B', 'P'};
        return new MockMultipartFile("file", "photo.webp", "image/webp", bytes);
    }

    @Test
    void 저장하면_본인_경로의_상대_URL을_돌려준다() {
        String photoUrl = sut.store(UID, SPOT_ID, jpeg(new byte[]{1, 2, 3}));

        assertThat(photoUrl).startsWith("/api/visits/photos/" + UID + "/" + SPOT_ID + "/");
        // 인증 단계 검증과 형식이 맞아야 한다 — 둘이 어긋나면 업로드는 되는데 인증이 안 된다.
        new VisitPhotoUrlValidator().validate(photoUrl, UID, SPOT_ID);
    }

    @Test
    void 저장된_파일을_다시_읽을_수_있다() throws IOException {
        String photoUrl = sut.store(UID, SPOT_ID, jpeg(new byte[]{9, 9, 9}));
        String fileName = photoUrl.substring(photoUrl.lastIndexOf('/') + 1);

        Resource loaded = sut.load(UID, String.valueOf(SPOT_ID), fileName);

        assertThat(loaded.exists()).isTrue();
        assertThat(Files.readAllBytes(loaded.getFile().toPath()))
                .containsExactly((byte) 0xFF, (byte) 0xD8, (byte) 0xFF, 9, 9, 9);
    }

    @Test
    void 클라이언트_파일명은_쓰지_않는다() {
        // 파일명을 그대로 쓰면 ../ 로 루트 밖에 쓸 수 있다. 서버가 만든 이름이어야 한다.
        MockMultipartFile evil = new MockMultipartFile(
                "file", "../../evil.jpg", "image/jpeg",
                new byte[]{(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, 0});

        String photoUrl = sut.store(UID, SPOT_ID, evil);

        assertThat(photoUrl).doesNotContain("..").doesNotContain("evil");
    }

    @Test
    void PNG와_WebP도_저장된다() {
        assertThat(sut.store(UID, SPOT_ID, png())).endsWith(".png");
        assertThat(sut.store(UID, SPOT_ID, webp())).endsWith(".webp");
    }

    @Test
    void 이미지가_아니면_거부한다() {
        // 확장자·Content-Type 을 이미지로 위장해도 실제 바이트로 판정한다.
        MockMultipartFile disguised = new MockMultipartFile(
                "file", "photo.jpg", "image/jpeg", "#!/bin/sh\necho pwned".getBytes());

        assertThatThrownBy(() -> sut.store(UID, SPOT_ID, disguised))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void 용량을_넘으면_거부한다() {
        VisitPhotoStorage small = storageWithMaxBytes(10);

        assertThatThrownBy(() -> small.store(UID, SPOT_ID, jpeg(new byte[64])))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void 빈_파일은_거부한다() {
        MockMultipartFile empty = new MockMultipartFile("file", "photo.jpg", "image/jpeg", new byte[0]);

        assertThatThrownBy(() -> sut.store(UID, SPOT_ID, empty))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void 경로에_쓸_수_없는_식별자는_거부한다() {
        assertThatThrownBy(() -> sut.store("../escape", SPOT_ID, jpeg(new byte[]{1})))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void 상위_디렉터리_식별자는_거부한다() {
        // ".." 는 허용 문자(마침표)로만 이뤄져 문자 집합 검사만으로는 통과한다 — 별도로 막아야 한다.
        assertThatThrownBy(() -> sut.store("..", SPOT_ID, jpeg(new byte[]{1})))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> sut.store(".", SPOT_ID, jpeg(new byte[]{1})))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void 저장_경로는_루트를_벗어나지_않는다() throws IOException {
        sut.store(UID, SPOT_ID, jpeg(new byte[]{1}));

        // 루트 바로 아래 {uid}/{spotId}/ 구조만 생겨야 한다.
        try (var paths = Files.walk(tempDir)) {
            assertThat(paths.allMatch(p -> p.normalize().startsWith(tempDir))).isTrue();
        }
        assertThat(Files.isDirectory(tempDir.resolve(UID).resolve(String.valueOf(SPOT_ID)))).isTrue();
    }

    @Test
    void 읽을_때도_경로_이탈을_막는다() {
        assertThatThrownBy(() -> sut.load("..", "..", "1712345678901-0a1b2c3d4e5f6071.jpg"))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void 서버가_만든_형식이_아닌_파일명은_거부한다() {
        assertThatThrownBy(() -> sut.load(UID, String.valueOf(SPOT_ID), "passwd"))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
