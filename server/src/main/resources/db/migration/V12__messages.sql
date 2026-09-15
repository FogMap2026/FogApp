-- ================================================================
-- V12: messages — 친구끼리 주고받는 메시지
--
-- 「친구」는 새 관계 테이블이 아니라 **수락된 매칭**(matches.status = 'accepted')이다.
-- 메시지는 그 매칭에 달린다 — 대화방이 곧 매칭 한 건이다.
--
-- 지우는 경로가 따로 필요 없게 참조를 CASCADE 로 건다:
--   matches 삭제(친구 끊기·요청 취소) → 그 대화 전부 삭제
--   users 삭제(회원 탈퇴, #182)        → 내가 보낸 메시지 + 내가 낀 매칭의 대화 전부 삭제
-- 방침의 «탈퇴 시 지체 없이 파기»가 별도 코드 없이 지켜진다.
-- ================================================================

CREATE TABLE messages (
    id         BIGSERIAL PRIMARY KEY,
    match_id   BIGINT NOT NULL REFERENCES matches (id) ON DELETE CASCADE,
    sender_id  BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    content    VARCHAR(1000) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 대화방 조회는 항상 «이 매칭의, 이 id 이후»다.
CREATE INDEX idx_messages_match_id ON messages (match_id, id);
