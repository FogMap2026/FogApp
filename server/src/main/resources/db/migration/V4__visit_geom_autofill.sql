-- ================================================================
-- V4: visits.geom 자동 채움 트리거
-- 관련 이슈: #48
--
-- V1에서 visits.geom(Point,4326) 컬럼은 만들어 두었지만 채우는 주체가 없어
-- 계속 NULL로 남아 있었다. spots(V2)와 같은 이유로 애플리케이션이 아니라
-- DB 트리거가 채운다 — 인증 경로가 늘어나도(배치 보정, 관리자 도구 등)
-- geom 생성 로직이 한 곳에만 있어야 누락이 생기지 않기 때문이다.
--
-- 좌표 이상치 처리도 spots와 동일하다: 행은 남기고 geom만 NULL로 둔다.
-- (인증 좌표는 서버가 반경 검증을 통과시킨 값이라 이상치가 들어올 일은
--  거의 없지만, 방어적으로 같은 규칙을 적용한다.)
--
-- 반경 검증 자체는 spots.geom 기준으로 수행하므로 이 트리거에 의존하지 않는다.
-- visits.geom은 "인증이 실제로 어디서 일어났는가"를 사후에 확인하기 위한 기록이다.
-- ================================================================

CREATE OR REPLACE FUNCTION fn_visits_set_geom() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.lat IS NULL OR NEW.lng IS NULL THEN
        NEW.geom := NULL;
    ELSIF NEW.lat < -90 OR NEW.lat > 90 OR NEW.lng < -180 OR NEW.lng > 180 THEN
        RAISE WARNING 'visit user_id=% spot_id=% : lat/lng 범위 이상치 (lat=%, lng=%) — geom 비움',
            NEW.user_id, NEW.spot_id, NEW.lat, NEW.lng;
        NEW.geom := NULL;
    ELSE
        NEW.geom := ST_SetSRID(ST_MakePoint(NEW.lng, NEW.lat), 4326);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_visits_set_geom
    BEFORE INSERT OR UPDATE OF lat, lng ON visits
    FOR EACH ROW
    EXECUTE FUNCTION fn_visits_set_geom();

-- 인증 위치 기반 조회(3-5 안개 해제 영역 복원)를 위한 공간 인덱스.
CREATE INDEX idx_visits_geom ON visits USING GIST (geom);
