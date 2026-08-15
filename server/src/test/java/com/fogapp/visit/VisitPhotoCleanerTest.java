package com.fogapp.visit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.attribute.FileTime;
import java.time.Duration;
import java.time.Instant;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.mock.web.MockMultipartFile;

/**
 * 고아 인증 사진 정리(#76).
 *
 * <p>이 테스트가 지키는 것은 "지운다"가 아니라 <b>"함부로 지우지 않는다"</b>에 가깝다.
 * 정리 배치가 인증 대기 중인 사진이나 이미 인증된 사진을 지우면 사용자 데이터가 사라진다.</p>
 */
class VisitPhotoCleanerTest {

    private static final String UID = "abc123UID";
    private static final Long SPOT_ID = 42L;
    private static final long RETENTION_HOURS = 24;

    @TempDir
    Path tempDir;

    private VisitPhotoStorage storage;
    private VisitRepository visitRepository;
    private VisitPhotoCleaner sut;

    @BeforeEach
    void setUp() {
        VisitProperties props = new VisitProperties();
        props.setPhotoStoragePath(tempDir.toString());
        props.setPhotoRetentionHours(RETENTION_HOURS);
        storage = new VisitPhotoStorage(props);
        visitRepository = mock(VisitRepository.class);
        when(visitRepository.existsByPhotoUrl(anyString())).thenReturn(false);
        sut = new VisitPhotoCleaner(storage, visitRepository, props);
    }

    private static MockMultipartFile jpeg() {
        return new MockMultipartFile("file", "photo.jpg", "image/jpeg",
                new byte[]{(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, 1, 2, 3});
    }

    /** 업로드한 사진을 "오래된" 것으로 만든다 — 유예 시간을 실제로 기다리지 않기 위해. */
    private String storeAged(Long spotId, Duration age) throws IOException {
        String photoUrl = storage.store(UID, spotId, jpeg());
        Path file = fileOf(photoUrl);
        Files.setLastModifiedTime(file, FileTime.from(Instant.now().minus(age)));
        return photoUrl;
    }

    private Path fileOf(String photoUrl) {
        String relative = photoUrl.substring("/api/visits/photos/".length());
        return tempDir.resolve(relative.replace('/', java.io.File.separatorChar));
    }

    @Test
    void 유예_시간이_지난_고아_사진은_지운다() throws IOException {
        String photoUrl = storeAged(SPOT_ID, Duration.ofHours(RETENTION_HOURS + 1));

        assertThat(sut.clean()).isEqualTo(1);
        assertThat(Files.exists(fileOf(photoUrl))).isFalse();
    }

    @Test
    void 방금_올린_사진은_참조가_없어도_남긴다() throws IOException {
        // 핵심. 업로드와 인증이 분리돼 있어 인증 직전의 사진은 정상적으로 참조가 없다.
        // 여기서 지우면 사용자는 이유를 알 수 없는 인증 실패를 겪는다.
        String photoUrl = storeAged(SPOT_ID, Duration.ofHours(1));

        assertThat(sut.clean()).isZero();
        assertThat(Files.exists(fileOf(photoUrl))).isTrue();
    }

    @Test
    void 인증에_쓰인_사진은_아무리_오래돼도_남긴다() throws IOException {
        String photoUrl = storeAged(SPOT_ID, Duration.ofDays(365));
        when(visitRepository.existsByPhotoUrl(photoUrl)).thenReturn(true);

        assertThat(sut.clean()).isZero();
        assertThat(Files.exists(fileOf(photoUrl))).isTrue();
    }

    @Test
    void 참조_판정에_쓰는_URL은_업로드가_돌려준_URL과_같다() throws IOException {
        // 둘이 어긋나면 모든 사진이 고아로 보여 통째로 지워진다 — 조용히 터지는 종류의 버그다.
        String photoUrl = storage.store(UID, SPOT_ID, jpeg());

        assertThat(storage.toPhotoUrl(fileOf(photoUrl))).isEqualTo(photoUrl);
    }

    @Test
    void 저장_디렉터리가_없으면_아무_일도_하지_않는다() throws IOException {
        VisitProperties props = new VisitProperties();
        props.setPhotoStoragePath(tempDir.resolve("아직-없음").toString());
        VisitPhotoCleaner cleaner =
                new VisitPhotoCleaner(new VisitPhotoStorage(props), visitRepository, props);

        assertThat(cleaner.clean()).isZero();
    }
}
