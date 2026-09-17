package com.fogapp.push;

import java.time.OffsetDateTime;

import org.hibernate.annotations.UpdateTimestamp;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

/** 푸시를 보낼 기기 하나(#134). 토큰이 기본키다 — 자세한 이유는 V13 주석. */
@Entity
@Table(name = "device_tokens")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class DeviceToken {

    @Id
    private String token;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(nullable = false, length = 16)
    private String platform;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private OffsetDateTime updatedAt;

    public DeviceToken(String token, Long userId, String platform) {
        this.token = token;
        this.userId = userId;
        this.platform = platform;
    }

    /** 같은 폰에 다른 계정이 로그인했다 — 주인을 바꾼다. */
    public void reassignTo(Long userId, String platform) {
        this.userId = userId;
        this.platform = platform;
    }
}
