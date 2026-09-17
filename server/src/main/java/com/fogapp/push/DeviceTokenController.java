package com.fogapp.push;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.fogapp.auth.AuthUser;

import jakarta.validation.Valid;

/**
 * 푸시를 받을 기기 등록·해제(#134).
 *
 * <p>등록은 앱이 «알림 권한을 허용한 뒤»에, 해제는 «알림 끄기»와 로그아웃에서 부른다 —
 * 토큰이 없으면 보낼 곳이 없으므로 <b>행의 유무가 곧 켜짐/꺼짐</b>이다(별도 플래그를 두지 않는다).</p>
 */
@RestController
@RequestMapping("/api/devices/token")
public class DeviceTokenController {

    private final DeviceTokenService deviceTokenService;

    public DeviceTokenController(DeviceTokenService deviceTokenService) {
        this.deviceTokenService = deviceTokenService;
    }

    @PostMapping
    public ResponseEntity<Void> register(@AuthenticationPrincipal AuthUser me,
                                         @Valid @RequestBody DeviceTokenRequest request) {
        deviceTokenService.register(me.userId(), request.token(), request.platformOrDefault());
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping
    public ResponseEntity<Void> unregister(@AuthenticationPrincipal AuthUser me,
                                           @Valid @RequestBody DeviceTokenRequest request) {
        deviceTokenService.unregister(me.userId(), request.token());
        return ResponseEntity.noContent().build();
    }
}
