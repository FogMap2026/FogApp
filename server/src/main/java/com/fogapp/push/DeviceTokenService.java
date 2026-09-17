package com.fogapp.push;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class DeviceTokenService {

    private final DeviceTokenRepository repository;

    public DeviceTokenService(DeviceTokenRepository repository) {
        this.repository = repository;
    }

    /**
     * 기기를 등록한다. 이미 있는 토큰이면 **주인을 지금 사용자로 바꾼다** — 같은 폰에 다른 계정이
     * 로그인했는데 그대로 두면 이전 사람의 알림이 이 폰으로 온다.
     */
    @Transactional
    public void register(Long userId, String token, String platform) {
        String device = platform == null || platform.isBlank() ? "android" : platform;
        repository.findById(token)
                .ifPresentOrElse(
                        existing -> existing.reassignTo(userId, device),
                        () -> repository.save(new DeviceToken(token, userId, device)));
    }

    /** 알림 끄기·로그아웃. 남의 토큰을 지우지 못하게 사용자까지 함께 본다(#52). */
    @Transactional
    public void unregister(Long userId, String token) {
        repository.deleteByTokenAndUserId(token, userId);
    }
}
