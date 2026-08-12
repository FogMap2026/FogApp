package com.fogapp.visit;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.HexFormat;
import java.util.Locale;
import java.util.regex.Pattern;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

/**
 * 인증 사진을 서버 디스크에 보관한다(#48, 팀 결정 B안).
 *
 * <p>Firebase Storage 가 무료 요금제에서 막혀 사진만 서버가 직접 저장한다. 그래서
 * Storage Security Rules 가 해 주던 일(본인 경로 강제·용량 제한·형식 제한)을
 * <b>이 클래스가 대신</b> 한다.</p>
 *
 * <p>저장 경로: {@code {root}/{firebaseUid}/{spotId}/{생성된 파일명}}
 * — 파일명은 <b>서버가 만든다.</b> 클라이언트가 준 이름을 쓰면 {@code ../} 로
 * 루트 밖에 쓸 수 있다.</p>
 */
@Component
public class VisitPhotoStorage {

    private static final Logger log = LoggerFactory.getLogger(VisitPhotoStorage.class);

    /** 경로에 들어갈 수 있는 안전한 문자만 허용한다 — 경로 이탈(../)·구분자 삽입 차단. */
    private static final Pattern SAFE_SEGMENT = Pattern.compile("[A-Za-z0-9._-]{1,128}");

    /** 저장 파일명. {timestamp}-{난수}.{확장자} 형태만 만든다. */
    private static final Pattern STORED_FILE_NAME = Pattern.compile("\\d{1,19}-[0-9a-f]{16}\\.(jpg|png|webp)");

    private final Path root;
    private final long maxBytes;

    public VisitPhotoStorage(VisitProperties properties) {
        this.root = Paths.get(properties.getPhotoStoragePath()).toAbsolutePath().normalize();
        this.maxBytes = properties.getMaxPhotoBytes();
    }

    /**
     * 사진을 저장하고 {@code photoUrl} 로 쓸 <b>상대 경로</b>를 돌려준다.
     *
     * <p>절대 URL 이 아니라 상대 경로인 이유: 호스트가 로컬·배포에서 달라지는데
     * DB에 절대 URL을 박으면 환경이 바뀔 때 이미 저장된 행이 전부 깨진다.</p>
     *
     * @return {@code /api/visits/photos/{uid}/{spotId}/{파일명}}
     * @throws IllegalArgumentException 빈 파일·용량 초과·이미지가 아닌 경우
     */
    public String store(String firebaseUid, Long spotId, MultipartFile file) {
        requireSafeSegment(firebaseUid, "사용자 식별자");

        if (file == null || file.isEmpty()) {
            throw new IllegalArgumentException("업로드할 사진이 없습니다.");
        }
        if (file.getSize() > maxBytes) {
            throw new IllegalArgumentException(
                    "사진 용량은 " + (maxBytes / (1024 * 1024)) + "MB 이하만 업로드할 수 있습니다.");
        }

        // 확장자·Content-Type 은 클라이언트가 마음대로 보낼 수 있다. 실제 바이트로 판정한다.
        ImageType type = sniff(file);

        String fileName = System.currentTimeMillis() + "-" + randomHex() + "." + type.extension();
        Path dir = resolveDir(firebaseUid, String.valueOf(spotId));
        requireInsideRoot(dir);

        try {
            Files.createDirectories(dir);
            try (InputStream in = file.getInputStream()) {
                Files.copy(in, dir.resolve(fileName), StandardCopyOption.REPLACE_EXISTING);
            }
            // 스팟당 1장만 남긴다(#76). 정복은 visits (user_id, spot_id) 유니크로 1인 1회라
            // 한 사람이 한 스팟에 여러 장을 가질 이유가 없다. 이걸로 한 사용자의 최대 사용량이
            // "스팟 수 × 장당 상한"으로 묶이고, 재업로드가 누적되지 않는다.
            //
            // 순서가 중요하다 — 새 파일을 쓴 "뒤에" 지운다. 반대로 하면 복사가 실패했을 때
            // 새 사진도 옛 사진도 없는 상태가 된다(#79 리뷰).
            deleteOtherPhotos(dir, fileName);
        } catch (IOException e) {
            throw new IllegalStateException("사진을 저장하지 못했습니다.", e);
        }

        return "/api/visits/photos/" + firebaseUid + "/" + spotId + "/" + fileName;
    }

    /**
     * 저장된 사진을 읽는다. 경로 조각은 모두 검증하며, 최종 경로가 루트 밖이면 거부한다.
     *
     * @throws IllegalArgumentException 경로 조각이 안전하지 않을 때
     */
    public Resource load(String firebaseUid, String spotId, String fileName) {
        requireSafeSegment(firebaseUid, "사용자 식별자");
        requireSafeSegment(spotId, "스팟 식별자");
        if (!STORED_FILE_NAME.matcher(fileName).matches()) {
            // 서버가 만든 형식이 아니면 볼 것도 없다.
            throw new IllegalArgumentException("사진 파일명이 올바르지 않습니다.");
        }

        Path target = resolveDir(firebaseUid, spotId).resolve(fileName).normalize();
        requireInsideRoot(target);
        return new FileSystemResource(target);
    }

    /** 파일명에서 Content-Type 을 되돌린다(서빙 시 사용). */
    public String contentTypeOf(String fileName) {
        String lower = fileName.toLowerCase(Locale.ROOT);
        if (lower.endsWith(".png")) {
            return "image/png";
        }
        if (lower.endsWith(".webp")) {
            return "image/webp";
        }
        return "image/jpeg";
    }

    /**
     * 같은 스팟 디렉터리에서 방금 쓴 파일을 뺀 나머지를 지운다(#76).
     *
     * <p>반드시 새 파일을 <b>쓴 뒤에</b> 부른다. 먼저 지우면 복사가 실패했을 때
     * 새 사진도 옛 사진도 없는 상태가 된다.</p>
     *
     * <p>지우지 못한 파일이 있어도 업로드는 계속한다 — 정리 실패로 인증 자체를 막을 이유는 없다.
     * 남은 파일은 {@link VisitPhotoCleaner}가 나중에 걷어간다.</p>
     */
    private void deleteOtherPhotos(Path dir, String keepFileName) throws IOException {
        if (!Files.isDirectory(dir)) {
            return;
        }
        try (var entries = Files.list(dir)) {
            entries.filter(Files::isRegularFile)
                    .filter(p -> !p.getFileName().toString().equals(keepFileName))
                    .forEach(p -> {
                        try {
                            Files.deleteIfExists(p);
                        } catch (IOException e) {
                            log.warn("이전 인증 사진을 지우지 못했습니다: {}", p, e);
                        }
                    });
        }
    }

    /** 저장 루트. 고아 파일 정리(#76)가 훑을 대상이다. */
    Path root() {
        return root;
    }

    /** 파일 경로를 {@code photoUrl} 형태로 되돌린다. 고아 판정 시 DB 값과 대조하는 데 쓴다(#76). */
    String toPhotoUrl(Path file) {
        Path relative = root.relativize(file.normalize());
        return "/api/visits/photos/" + relative.toString().replace(java.io.File.separatorChar, '/');
    }

    private Path resolveDir(String firebaseUid, String spotId) {
        return root.resolve(firebaseUid).resolve(spotId).normalize();
    }

    private static void requireSafeSegment(String value, String what) {
        // "." 과 ".." 는 SAFE_SEGMENT 문자 집합만으로는 걸러지지 않는다(둘 다 허용 문자로만 이뤄짐).
        // 상위 디렉터리로 올라가는 가장 흔한 수단이라 명시적으로 막는다.
        if (value == null || !SAFE_SEGMENT.matcher(value).matches()
                || ".".equals(value) || "..".equals(value)) {
            throw new IllegalArgumentException(what + "가 올바르지 않습니다.");
        }
    }

    /** 최종 경로가 저장 루트 밖이면 거부한다. 세그먼트 검사를 뚫었을 때의 마지막 방어선. */
    private void requireInsideRoot(Path path) {
        if (!path.normalize().startsWith(root)) {
            throw new IllegalArgumentException("허용되지 않은 사진 경로입니다.");
        }
    }

    private static String randomHex() {
        byte[] bytes = new byte[8];
        new java.security.SecureRandom().nextBytes(bytes);
        return HexFormat.of().formatHex(bytes);
    }

    /**
     * 매직 바이트로 이미지 형식을 판정한다. 확장자를 바꾼 실행 파일 등이 올라오는 것을 막는다.
     */
    private static ImageType sniff(MultipartFile file) {
        byte[] head = new byte[12];
        int read;
        try (InputStream in = file.getInputStream()) {
            read = in.readNBytes(head, 0, head.length);
        } catch (IOException e) {
            throw new IllegalStateException("사진을 읽지 못했습니다.", e);
        }

        if (read >= 3 && (head[0] & 0xFF) == 0xFF && (head[1] & 0xFF) == 0xD8 && (head[2] & 0xFF) == 0xFF) {
            return ImageType.JPEG;
        }
        if (read >= 8 && (head[0] & 0xFF) == 0x89 && head[1] == 'P' && head[2] == 'N' && head[3] == 'G'
                && (head[4] & 0xFF) == 0x0D && (head[5] & 0xFF) == 0x0A
                && (head[6] & 0xFF) == 0x1A && (head[7] & 0xFF) == 0x0A) {
            return ImageType.PNG;
        }
        if (read >= 12 && head[0] == 'R' && head[1] == 'I' && head[2] == 'F' && head[3] == 'F'
                && head[8] == 'W' && head[9] == 'E' && head[10] == 'B' && head[11] == 'P') {
            return ImageType.WEBP;
        }
        throw new IllegalArgumentException("JPEG·PNG·WebP 이미지만 업로드할 수 있습니다.");
    }

    private enum ImageType {
        JPEG("jpg"), PNG("png"), WEBP("webp");

        private final String extension;

        ImageType(String extension) {
            this.extension = extension;
        }

        String extension() {
            return extension;
        }
    }
}
