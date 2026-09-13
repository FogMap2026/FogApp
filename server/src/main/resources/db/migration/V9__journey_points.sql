-- ================================================================
-- V9: journey_points — 걸어온 자리(#131)
--
-- 안개는 두 축으로 걷힌다.
--
--   인증한 스팟   150m   visits 로 서버에 남고 GET /api/visits 로 복원된다
--   걸어온 자리    15m   ← 이 테이블. 그동안 «세션 동안만» 남아 앱을 끄면 사라졌다
--
-- 🔴 정복률과는 무관하다. 정복률은 visits 로 계산한다(GET /api/conquest).
--    걸어서 걷힌 안개가 정복으로 세어지면 사진 인증을 할 이유가 없어진다
--    (planning.md 3장 「도달 → 인증 → 해제」).
-- ================================================================

CREATE TABLE journey_points (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    lat         DOUBLE PRECISION NOT NULL,
    lng         DOUBLE PRECISION NOT NULL,
    recorded_at TIMESTAMPTZ NOT NULL,           -- 단말이 «측위한» 시각. 서버 도착 시각이 아니다
    geom        geometry(Point, 4326),          -- 트리거가 채운다 (spots V2 · visits V4 · footprints V5 와 동일)
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- 🔑 batch 업로드는 «재전송이 일어난다». 네트워크가 끊겼다 붙으면 앱이 같은
    --    묶음을 다시 보내고, 그러면 궤적에 점이 두 겹으로 쌓인다.
    --    앱에서 중복을 막는 것보다 서버에서 막는 편이 훨씬 싸다 — ON CONFLICT DO NOTHING
    --    으로 받으면 앱이 재전송을 마음 편히 할 수 있다.
    UNIQUE (user_id, recorded_at)
);

COMMENT ON TABLE journey_points IS
    '사용자가 지나간 자리(#131). 안개를 15m 반경으로 걷는 데 쓴다. 정복률과 무관하다.';
COMMENT ON COLUMN journey_points.recorded_at IS
    '단말이 측위한 시각. (user_id, recorded_at) 유니크로 batch 재전송을 멱등하게 만든다.';

-- ----------------------------------------------------------------
-- geom 자동 채움 — 애플리케이션이 아니라 DB 가 채운다
--
-- spots(V2)·visits(V4)·footprints(V5) 와 같은 이유다: 적재 경로가 늘어나도
-- (배치 보정·관리 도구 등) geom 생성 로직이 한 곳에만 있어야 누락이 안 생긴다.
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_journey_points_set_geom() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.lat < -90 OR NEW.lat > 90 OR NEW.lng < -180 OR NEW.lng > 180 THEN
        RAISE WARNING 'journey_point user_id=% : lat/lng 범위 이상치 (lat=%, lng=%) — geom 비움',
            NEW.user_id, NEW.lat, NEW.lng;
        NEW.geom := NULL;
    ELSE
        NEW.geom := ST_SetSRID(ST_MakePoint(NEW.lng, NEW.lat), 4326);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_journey_points_set_geom
    BEFORE INSERT OR UPDATE OF lat, lng ON journey_points
    FOR EACH ROW
    EXECUTE FUNCTION fn_journey_points_set_geom();

-- ----------------------------------------------------------------
-- 인덱스
-- ----------------------------------------------------------------

-- 「내 궤적을 시간순으로」 — 지도 진입 시 복원이 이 축으로 읽는다.
CREATE INDEX idx_journey_points_user_time ON journey_points (user_id, recorded_at);

-- 🔴 geography 로 만든다. geom(geometry) 에만 걸고 쿼리를 geom::geography 로 하면
--    타입이 어긋나 인덱스를 못 탄다 — spots·footprints 가 정확히 그래서 Seq Scan 을
--    돌았고(#125, 93.5ms → 7.4ms) V7 로 고쳤다. 새 테이블에서 같은 실수를 반복하지 않는다.
CREATE INDEX idx_journey_points_geom_geography
    ON journey_points USING GIST ((geom::geography));
