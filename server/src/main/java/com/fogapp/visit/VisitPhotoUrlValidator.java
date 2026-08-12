package com.fogapp.visit;

import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

/**
 * 인증 사진 URL이 <b>본인이 이 서버에 올린 것</b>인지 검증한다 (#48).
 *
 * <p>서버는 {@code POST /api/visits} 에서 사진 바이너리가 아니라 URL만 받는다. 그래서
 * 업로드 엔드포인트가 경로를 본인 것으로 강제해도, <b>인증 단계가 그 경로를 요구하지 않으면
 * 우회된다</b> — 아무 문자열이나 넣어도 인증이 성립해 "사진으로 방문을 인증한다"는 성질이 깨진다.
 * 이 검증이 업로드 제약과 짝을 이뤄 그 구멍을 닫는다.</p>
 *
 * <p>기대 형태 (업로드 응답이 돌려주는 상대 경로):</p>
 * <pre>
 * /api/visits/photos/{firebaseUid}/{spotId}/{파일명}
 * </pre>
 *
 * <p>절대 URL을 받지 않는 이유: 호스트가 환경마다 달라 검증 기준이 흔들리고,
 * 외부 URL을 넣을 여지를 남기기 때문이다. 업로드 응답 그대로만 통과시킨다.</p>
 */
@Component
public class VisitPhotoUrlValidator {

    static final String PATH_PREFIX = "/api/visits/photos/";

    /**
     * {@code photoUrl} 이 {@code /api/visits/photos/{firebaseUid}/{spotId}/} 하위를 가리키는지 확인한다.
     *
     * @throws IllegalArgumentException 형식이 다르거나 남의 경로일 때
     */
    public void validate(String photoUrl, String firebaseUid, Long spotId) {
        if (!StringUtils.hasText(photoUrl)) {
            throw new IllegalArgumentException("photoUrl 이 비어 있습니다.");
        }
        if (!StringUtils.hasText(firebaseUid)) {
            throw new IllegalArgumentException("사용자 식별자가 없습니다.");
        }

        // 경로 이탈로 접두사 검사를 통과시키려는 시도(/api/visits/photos/me/1/../../other)를 막는다.
        if (photoUrl.contains("..")) {
            throw new IllegalArgumentException("photoUrl 에 허용되지 않은 경로가 포함되어 있습니다.");
        }
        if (!photoUrl.startsWith(PATH_PREFIX)) {
            throw new IllegalArgumentException("photoUrl 은 이 서버의 인증 사진 경로여야 합니다.");
        }

        // 조각 단위로 대조한다. 문자열 startsWith 만 쓰면 uid "abc" 가 "abcEXTRA" 를,
        // spotId 42 가 421 을 통과시킨다.
        String rest = photoUrl.substring(PATH_PREFIX.length());
        String[] parts = rest.split("/");
        if (parts.length != 3) {
            throw new IllegalArgumentException("photoUrl 형식이 올바르지 않습니다.");
        }
        if (!parts[0].equals(firebaseUid) || !parts[1].equals(String.valueOf(spotId))
                || parts[2].isEmpty()) {
            // 남의 UID·다른 스팟 경로인 경우. 어느 쪽인지는 굳이 알려주지 않는다.
            throw new IllegalArgumentException("photoUrl 이 본인이 업로드한 인증 사진 경로가 아닙니다.");
        }
    }
}
