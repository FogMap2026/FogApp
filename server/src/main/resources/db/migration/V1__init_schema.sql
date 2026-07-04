-- ================================================================
-- FogApp 초기 스키마 (V1)
-- Phase 1~6 전체가 사용하는 핵심 테이블.
-- 좌표는 PostGIS geometry(Point, 4326) 로 저장한다.
-- 관련 이슈: #1
-- ================================================================

-- PostGIS 확장 (docker-compose 의 postgis 이미지에는 포함되어 있음)
CREATE EXTENSION IF NOT EXISTS postgis;

-- ----------------------------------------------------------------
-- users : 사용자 프로필 (+ 여행 성향 결과 자리 — Phase 5)
-- ----------------------------------------------------------------
CREATE TABLE users (
    id                 BIGSERIAL PRIMARY KEY,
    firebase_uid       VARCHAR(128) NOT NULL UNIQUE,   -- Firebase Auth UID
    email              VARCHAR(255),
    nickname           VARCHAR(50),
    profile_image_url  TEXT,
    personality_type   VARCHAR(50),                    -- 성향 유형 (Phase 5에서 채움)
    personality_scores JSONB,                          -- 성향 세부 점수
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ----------------------------------------------------------------
-- spots : 관광공사 OpenAPI 스팟 (안개 아래 탐험 포인트)
--   lat/lng = 원본 좌표, geom = PostGIS 좌표(#6에서 채움)
-- ----------------------------------------------------------------
CREATE TABLE spots (
    id              BIGSERIAL PRIMARY KEY,
    content_id      VARCHAR(32) NOT NULL UNIQUE,        -- 관광공사 contentid (중복 적재 방지)
    content_type_id VARCHAR(16),                        -- 관광 타입 코드
    title           VARCHAR(255) NOT NULL,
    addr1           VARCHAR(255),
    addr2           VARCHAR(255),
    area_code       VARCHAR(16),                        -- 지역 코드 (지역별 조회 #7)
    sigungu_code    VARCHAR(16),                        -- 시군구 코드
    tel             VARCHAR(64),
    first_image     TEXT,
    first_image2    TEXT,
    overview        TEXT,                               -- 소개 (해금 시 공개)
    lat             DOUBLE PRECISION,                   -- 원본 위도
    lng             DOUBLE PRECISION,                   -- 원본 경도
    geom            geometry(Point, 4326),              -- PostGIS 좌표 (#6에서 lat/lng로 채움)
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_spots_area_code ON spots (area_code);
CREATE INDEX idx_spots_geom ON spots USING GIST (geom);   -- 반경 검색용 공간 인덱스 (#6/#7)

-- ----------------------------------------------------------------
-- visits : 방문 인증 기록 (사진 인증 → 안개 해제)
-- ----------------------------------------------------------------
CREATE TABLE visits (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    spot_id     BIGINT NOT NULL REFERENCES spots (id) ON DELETE CASCADE,
    photo_url   TEXT NOT NULL,                          -- 인증 사진 (Storage URL)
    lat         DOUBLE PRECISION,                       -- 인증 당시 위치
    lng         DOUBLE PRECISION,
    geom        geometry(Point, 4326),                  -- 인증 위치 좌표
    verified_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, spot_id)                           -- 한 사용자당 스팟 1회 정복
);

CREATE INDEX idx_visits_user_id ON visits (user_id);
CREATE INDEX idx_visits_spot_id ON visits (spot_id);

-- ----------------------------------------------------------------
-- footprints : 발자취 (텍스트·사진 기록) — 뼈대 (Phase 4에서 확장)
-- ----------------------------------------------------------------
CREATE TABLE footprints (
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    spot_id    BIGINT REFERENCES spots (id) ON DELETE SET NULL,
    content    TEXT,
    photo_url  TEXT,
    like_count INT NOT NULL DEFAULT 0,                  -- 좋아요 수 (Phase 4 반응 테이블과 연동)
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_footprints_spot_id ON footprints (spot_id);
CREATE INDEX idx_footprints_user_id ON footprints (user_id);

-- ----------------------------------------------------------------
-- matches : 성향 매칭 (동행) — 뼈대 (Phase 5에서 확장)
-- ----------------------------------------------------------------
CREATE TABLE matches (
    id           BIGSERIAL PRIMARY KEY,
    requester_id BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    addressee_id BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    status       VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending / accepted / rejected
    score        DOUBLE PRECISION,                       -- 성향 유사도 점수
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (requester_id, addressee_id),
    CHECK (requester_id <> addressee_id)
);

CREATE INDEX idx_matches_requester ON matches (requester_id);
CREATE INDEX idx_matches_addressee ON matches (addressee_id);
