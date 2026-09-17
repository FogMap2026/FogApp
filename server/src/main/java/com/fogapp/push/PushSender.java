package com.fogapp.push;

import java.util.Map;

/**
 * 푸시 한 건을 보낸다(#134).
 *
 * <p>인터페이스로 두는 이유는 둘이다 — Firebase 자격증명이 없는 환경(로컬·CI)에서는
 * {@code PushFallbackConfig} 의 대역이 대신 서고, 테스트는 이걸 mocking 해 «무엇을 누구에게 보내려 했나»만
 * 본다(실제 FCM 호출 없이).</p>
 */
public interface PushSender {

    /**
     * @param userId 받을 사람. 그 사람의 기기가 없으면 아무 일도 없다.
     * @param data   앱이 알림을 눌렀을 때 어디로 갈지(예: {@code type=message, matchId=3}).
     */
    void send(Long userId, String title, String body, Map<String, String> data);
}
