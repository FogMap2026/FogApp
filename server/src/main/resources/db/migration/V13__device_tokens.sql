-- ================================================================
-- V13: device_tokens — 푸시 알림(FCM)을 보낼 기기(#134, 6-4)
--
-- 한 사람이 기기를 여럿 쓸 수 있으므로 사용자당 여러 행이다. 반대로 **토큰 하나는 기기 하나**라
-- 토큰이 기본키다 — 같은 폰에 다른 계정이 로그인하면 그 행의 user_id 가 새 사람으로 바뀌어야
-- 이전 사람의 알림이 그 폰으로 가지 않는다(UPSERT 로 덮어쓴다).
--
-- 탈퇴(#182)하면 users CASCADE 로 함께 사라진다 — 방침의 «탈퇴 시 지체 없이 파기»가
-- 별도 코드 없이 지켜진다. 앱에서 알림을 끄면 행을 지운다(끔 = 보낼 곳이 없음).
-- ================================================================

CREATE TABLE device_tokens (
    token      VARCHAR(255) PRIMARY KEY,
    user_id    BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    platform   VARCHAR(16) NOT NULL DEFAULT 'android',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 보낼 때는 항상 «이 사람의 기기 전부»를 찾는다.
CREATE INDEX idx_device_tokens_user ON device_tokens (user_id);
