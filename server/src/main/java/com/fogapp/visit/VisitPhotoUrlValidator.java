package com.fogapp.visit;

import java.net.URI;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

/**
 * 인증 사진 URL이 <b>본인이 올린 것</b>인지 검증한다 (#56 리뷰 후속).
 *
 * <p>서버는 사진 바이너리를 받지 않고 URL만 저장하므로, Storage Security Rules
 * (`app/storage.rules`)가 업로드를 본인 경로로 잠가도 <b>서버가 그 경로를 요구하지 않으면
 * 우회된다</b> — 아무 URL이나 넣어도 인증이 성립해 "사진으로 방문을 인증한다"는 성질이 깨진다.
 * 이 검증이 Rules 와 짝을 이뤄 그 구멍을 닫는다.</p>
 *
 * <p>기대 형태 (Firebase Storage 다운로드 URL):</p>
 * <pre>
 * https://firebasestorage.googleapis.com/v0/b/{bucket}/o/visits%2F{firebaseUid}%2F{spotId}%2F{file}?alt=media&amp;token=...
 * </pre>
 *
 * <p>버킷이 설정되지 않으면 검증을 건너뛴다(로컬·CI). 다만 인증이 실제로 켜진
 * 환경({@code firebase.enabled=true})에서는 버킷 설정을 <b>강제</b>해 조용히
 * 무방비가 되는 것을 막는다 — 기동 시점에 실패한다.</p>
 */
@Component
public class VisitPhotoUrlValidator {

    private static final String STORAGE_HOST = "firebasestorage.googleapis.com";

    private final String bucket;

    public VisitPhotoUrlValidator(VisitProperties properties,
                                  @Value("${firebase.enabled:false}") boolean firebaseEnabled) {
        this.bucket = properties.getStorageBucket();

        if (firebaseEnabled && !StringUtils.hasText(this.bucket)) {
            throw new IllegalStateException(
                    "firebase.enabled=true 인데 visit.storage-bucket 이 비어 있습니다. "
                            + "인증 사진 URL 검증이 꺼진 채로 뜨는 것을 막기 위해 기동을 중단합니다. "
                            + "(예: fogmap-9355b.firebasestorage.app)");
        }
    }

    /** 검증이 켜져 있는지. 버킷 미설정 시 꺼진다. */
    public boolean isEnabled() {
        return StringUtils.hasText(bucket);
    }

    /**
     * {@code photoUrl} 이 기대 버킷의 {@code visits/{firebaseUid}/{spotId}/} 하위를 가리키는지 확인한다.
     *
     * @throws IllegalArgumentException 형식이 다르거나 남의 경로일 때
     */
    public void validate(String photoUrl, String firebaseUid, Long spotId) {
        if (!isEnabled()) {
            return;
        }

        URI uri;
        try {
            uri = URI.create(photoUrl);
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("photoUrl 형식이 올바르지 않습니다.", e);
        }

        if (!STORAGE_HOST.equalsIgnoreCase(uri.getHost())) {
            throw new IllegalArgumentException("photoUrl 은 프로젝트 Storage 주소여야 합니다.");
        }

        String rawPath = uri.getRawPath();
        String objectPrefix = "/v0/b/" + bucket + "/o/";
        if (rawPath == null || !rawPath.startsWith(objectPrefix)) {
            throw new IllegalArgumentException("photoUrl 의 버킷이 올바르지 않습니다.");
        }

        // 객체 경로는 퍼센트 인코딩돼 있다 (visits%2F...). 디코드 후 소유 경로와 대조한다.
        String objectName = URLDecoder.decode(
                rawPath.substring(objectPrefix.length()), StandardCharsets.UTF_8);

        String expected = "visits/" + firebaseUid + "/" + spotId + "/";
        if (!objectName.startsWith(expected)) {
            // 남의 UID·다른 스팟 경로를 가리키는 경우. 어느 쪽인지는 굳이 알려주지 않는다.
            throw new IllegalArgumentException("photoUrl 이 본인이 업로드한 인증 사진 경로가 아닙니다.");
        }
    }
}
