package com.fogapp.push;

import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.MessagingErrorCode;
import com.google.firebase.messaging.Notification;

/** FCM 으로 실제 발송한다. {@code firebase.enabled=true} 일 때만 주입된다. */
@Component
@ConditionalOnProperty(name = "firebase.enabled", havingValue = "true")
public class FirebasePushSender implements PushSender {

    private static final Logger log = LoggerFactory.getLogger(FirebasePushSender.class);

    private final DeviceTokenRepository tokenRepository;

    // FirebaseApp 초기화(FirebaseConfig) 이후 생성되도록 생성자 의존을 둔다(FirebaseAccountDeleter 와 같다).
    public FirebasePushSender(DeviceTokenRepository tokenRepository, com.google.firebase.FirebaseApp firebaseApp) {
        this.tokenRepository = tokenRepository;
    }

    /**
     * 그 사람의 기기 전부에 보낸다.
     *
     * <p>🔴 <b>발송 실패가 원래 요청을 깨뜨리면 안 된다.</b> 메시지를 보내는 일은 성공했는데 알림이
     * 안 갔다고 500 이 나면, 사용자는 «안 보내졌다»고 읽고 다시 보낸다. 그래서 여기서 예외를 삼키고
     * 로그만 남긴다.</p>
     *
     * <p>더 이상 유효하지 않은 토큰({@code UNREGISTERED}: 앱 삭제·재설치)은 그 자리에서 지운다 —
     * 안 지우면 그 기기로 영영 실패하는 발송이 매번 따라다닌다.</p>
     */
    @Override
    @Transactional
    public void send(Long userId, String title, String body, Map<String, String> data) {
        List<DeviceToken> devices = tokenRepository.findAllByUserId(userId);
        for (DeviceToken device : devices) {
            try {
                FirebaseMessaging.getInstance().send(com.google.firebase.messaging.Message.builder()
                        .setToken(device.getToken())
                        .setNotification(Notification.builder().setTitle(title).setBody(body).build())
                        .putAllData(data)
                        .build());
            } catch (FirebaseMessagingException e) {
                if (e.getMessagingErrorCode() == MessagingErrorCode.UNREGISTERED
                        || e.getMessagingErrorCode() == MessagingErrorCode.INVALID_ARGUMENT) {
                    log.info("죽은 푸시 토큰을 지운다 userId={} code={}", userId, e.getMessagingErrorCode());
                    tokenRepository.delete(device);
                    continue;
                }
                log.warn("푸시 발송 실패 userId={} : {}", userId, e.toString());
            } catch (RuntimeException e) {
                log.warn("푸시 발송 실패 userId={} : {}", userId, e.toString());
            }
        }
    }
}
