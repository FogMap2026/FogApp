package com.fogapp.visit;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * 참조되지 않는 인증 사진을 걷어낸다(#76).
 *
 * <p>업로드({@code POST /api/visits/photo})와 인증({@code POST /api/visits})이 분리돼 있어,
 * 업로드 후 인증이 422(반경 밖)·409(중복 인증)로 실패하면 <b>사진만 남는다.</b>
 * 서버 디스크에 보관하므로 이런 고아 파일이 쌓이면 용량을 잠식한다.</p>
 *
 * <p>⚠️ <b>유예 시간이 핵심이다.</b> 방금 올린 사진은 아직 인증 전이라 정상적으로 참조가 없다.
 * 유예 없이 지우면 사용자가 사진을 확인하는 동안 파일이 사라져, 인증이 "왜인지 모르게" 실패한다.
 * 그래서 {@code retentionHours} 보다 오래된 파일만 대상으로 한다.</p>
 *
 * <p>실행은 {@link VisitPhotoCleanupRunner}가 맡는다 — 이 클래스는 언제 도는지 모르고,
 * 무엇을 지울지만 안다(테스트에서 직접 호출하기 위함).</p>
 */
@Component
public class VisitPhotoCleaner {

    private static final Logger log = LoggerFactory.getLogger(VisitPhotoCleaner.class);

    private final VisitPhotoStorage storage;
    private final VisitRepository visitRepository;
    private final VisitProperties properties;

    public VisitPhotoCleaner(VisitPhotoStorage storage,
                             VisitRepository visitRepository,
                             VisitProperties properties) {
        this.storage = storage;
        this.visitRepository = visitRepository;
        this.properties = properties;
    }

    /**
     * 고아 사진을 지운다.
     *
     * @return 지운 파일 수
     */
    public int clean() {
        Path root = storage.root();
        if (!Files.isDirectory(root)) {
            return 0;
        }

        Instant cutoff = Instant.now().minus(Duration.ofHours(properties.getPhotoRetentionHours()));
        List<Path> candidates = new ArrayList<>();

        try (var files = Files.walk(root)) {
            files.filter(Files::isRegularFile)
                    .filter(p -> isOlderThan(p, cutoff))
                    .forEach(candidates::add);
        } catch (IOException e) {
            log.warn("인증 사진 디렉터리를 훑지 못했습니다: {}", root, e);
            return 0;
        }

        int deleted = 0;
        for (Path file : candidates) {
            // DB가 이 파일을 가리키고 있으면 정상 인증 사진이다.
            if (visitRepository.existsByPhotoUrl(storage.toPhotoUrl(file))) {
                continue;
            }
            try {
                Files.deleteIfExists(file);
                deleted++;
            } catch (IOException e) {
                log.warn("고아 인증 사진을 지우지 못했습니다: {}", file, e);
            }
        }

        if (deleted > 0) {
            log.info("고아 인증 사진 {}건을 정리했습니다 (기준: {}시간 이상 경과 + visits 미참조).",
                    deleted, properties.getPhotoRetentionHours());
        }
        return deleted;
    }

    private static boolean isOlderThan(Path file, Instant cutoff) {
        try {
            return Files.getLastModifiedTime(file).toInstant().isBefore(cutoff);
        } catch (IOException e) {
            // 시각을 읽지 못하면 건드리지 않는다 — 지우는 쪽으로 기울면 안 된다.
            log.warn("파일 시각을 읽지 못해 정리 대상에서 제외합니다: {}", file, e);
            return false;
        }
    }
}
