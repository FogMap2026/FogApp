-- ================================================================
-- V2: spots.geom 자동 채움 트리거 + 좌표 이상치 처리
-- 관련 이슈: #6
--
-- lat/lng 은 배치(#5)·API가 그대로 저장하고, geom(Point,4326)은
-- 트리거가 lat/lng 으로부터 자동으로 채운다. 애플리케이션(JPA) 레이어가
-- 아니라 DB 트리거로 처리하는 이유: 배치 적재가 JDBC 벌크 insert 등
-- 엔티티 콜백을 타지 않는 경로로 들어올 수 있어, geom 생성 로직을
-- 한 곳(DB)에만 두어야 누락을 막을 수 있기 때문이다.
--
-- 좌표가 없거나(NULL) 범위를 벗어난 이상치인 경우, 행 자체는 그대로
-- 두고 geom 만 NULL로 남긴다 (반경 검색에서만 자연히 제외됨).
-- ================================================================

CREATE OR REPLACE FUNCTION fn_spots_set_geom() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.lat IS NULL OR NEW.lng IS NULL THEN
        NEW.geom := NULL;
    ELSIF NEW.lat < -90 OR NEW.lat > 90 OR NEW.lng < -180 OR NEW.lng > 180 THEN
        RAISE WARNING 'spot content_id=% : lat/lng 범위 이상치 (lat=%, lng=%) — geom 비움',
            NEW.content_id, NEW.lat, NEW.lng;
        NEW.geom := NULL;
    ELSE
        NEW.geom := ST_SetSRID(ST_MakePoint(NEW.lng, NEW.lat), 4326);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_spots_set_geom
    BEFORE INSERT OR UPDATE OF lat, lng ON spots
    FOR EACH ROW
    EXECUTE FUNCTION fn_spots_set_geom();

-- 이 마이그레이션 적용 전에 이미 적재된 행이 있다면 geom 을 소급 채운다.
-- (SET lat = lat 는 값 변경 없이 "UPDATE OF lat" 트리거만 발동시키기 위함)
UPDATE spots SET lat = lat WHERE geom IS NULL AND lat IS NOT NULL AND lng IS NOT NULL;
