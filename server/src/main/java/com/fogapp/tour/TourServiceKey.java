package com.fogapp.tour;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;

/**
 * 공공데이터포털 서비스 키를 <b>URL 에 그대로 넣을 수 있는 형태</b>로 정규화한다.
 *
 * <p><b>왜 필요한가.</b> 포털은 같은 키를 두 가지 형태로 준다.</p>
 *
 * <ul>
 *   <li><b>Decoding 키</b> — base64 원문. {@code +} {@code /} {@code =} 가 들어 있다</li>
 *   <li><b>Encoding 키</b> — 그것을 퍼센트 인코딩한 것. {@code %2B} {@code %2F} {@code %3D}</li>
 * </ul>
 *
 * <p>둘 중 무엇을 넣느냐에 따라 필요한 처리가 정반대라, 어느 쪽을 넣었는지 모른 채
 * 일괄로 인코딩하거나 일괄로 두면 <b>한쪽은 반드시 깨진다.</b> 그리고 깨졌을 때 서버가
 * 돌려주는 말이 {@code SERVICE_KEY_IS_NOT_REGISTERED_ERROR}("등록되지 않은 서비스키")라,
 * <b>키가 멀쩡한데 발급이 잘못된 줄 알고 엉뚱한 곳을 찾게 된다.</b></p>
 *
 * <p>실제로 그렇게 한 번 막혔다 — Encoding 키를 넣었는데 클라이언트가 한 번 더 인코딩해
 * {@code %2B} 가 {@code %252B} 가 됐다. 포털에서 같은 키를 그대로 호출하면 정상
 * 응답(resultCode 0000)이 오는데도 서버만 403 을 받았다.</p>
 *
 * <p>그래서 <b>어느 쪽을 넣어도 같은 URL 이 나오도록</b> 여기서 한 번 정규화한다.</p>
 */
final class TourServiceKey {

    private TourServiceKey() {
    }

    /**
     * URL 에 넣을 수 있게 퍼센트 인코딩된 서비스 키를 돌려준다.
     *
     * <p>판정 기준은 {@code '%'} 의 존재다. base64 문자 집합은
     * {@code A-Z a-z 0-9 + / =} 뿐이라 <b>{@code %} 가 들어갈 수 없다</b> —
     * 있다면 이미 퍼센트 인코딩된 Encoding 키다.</p>
     *
     * @param rawKey 설정에서 읽은 키. null·빈 값이면 빈 문자열
     * @return 이미 인코딩돼 있으면 그대로, 아니면 퍼센트 인코딩한 값
     */
    static String encoded(String rawKey) {
        if (rawKey == null || rawKey.isBlank()) {
            return "";
        }
        String key = rawKey.trim();
        if (key.indexOf('%') >= 0) {
            return key;
        }
        return URLEncoder.encode(key, StandardCharsets.UTF_8);
    }
}
