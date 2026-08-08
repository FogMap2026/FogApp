-- ================================================================
-- V3: footprint_likes (발자취 좋아요·공감)
-- 관련 이슈: #23
--
-- footprints.like_count 는 이 테이블 기준 캐시 카운트다.
-- (footprint_id, user_id) 유니크로 한 사용자당 발자취 1개에 좋아요 1회만 허용한다.
-- ================================================================

CREATE TABLE footprint_likes (
    id           BIGSERIAL PRIMARY KEY,
    footprint_id BIGINT NOT NULL REFERENCES footprints (id) ON DELETE CASCADE,
    user_id      BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (footprint_id, user_id)
);

CREATE INDEX idx_footprint_likes_footprint_id ON footprint_likes (footprint_id);
CREATE INDEX idx_footprint_likes_user_id ON footprint_likes (user_id);
