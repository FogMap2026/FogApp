-- ================================================================
-- V5: footprints 에 좌표·geom 추가
-- 관련 이슈: #114 (발자취 재설계 5.5-1)
--
-- 발자취가 "스팟에 남기는 리뷰"에서 "길목마다 남기는 글귀"로 바뀐다.
-- 지금까지는 spot_id 하나로 장소를 표현해서, 스팟이 아닌 곳에는 남길 방법이
-- 없었다. 좌표가 있어야 길 위 어디에나 붙을 수 있다.
-- 설계 근거·반경 값은 docs/footprint-redesign.md 참고.
--
-- geom 은 spots(V2)·visits(V4)와 같이 DB 트리거가 채운다 — 작성 경로가
-- 늘어나도(배치 보정, 관리자 도구 등) 좌표 생성 로직이 한 곳에만 있어야
-- 누락이 생기지 않는다.
--
-- spot_id 는 그대로 nullable 로 둔다. 길목 발자취는 이 값이 비어 있고,
-- 스팟에서 쓴 글은 계속 채워진다 — 스팟 상세의 목록 조회가 이 값을 쓴다.
-- ================================================================

ALTER TABLE footprints
    ADD COLUMN lat  DOUBLE PRECISION,
    ADD COLUMN lng  DOUBLE PRECISION,
    ADD COLUMN geom geometry(Point, 4326);

-- ----------------------------------------------------------------
-- geom 자동 채움 — spots(V2)·visits(V4)와 동일한 규칙
-- 좌표 이상치는 행을 남기고 geom 만 비운다. 글 자체는 사용자가 쓴 것이라
-- 좌표가 이상하다고 버리면 안 되고, geom 이 NULL 이면 반경 조회에서
-- 자연히 빠진다.
-- ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_footprints_set_geom() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.lat IS NULL OR NEW.lng IS NULL THEN
        NEW.geom := NULL;
    ELSIF NEW.lat < -90 OR NEW.lat > 90 OR NEW.lng < -180 OR NEW.lng > 180 THEN
        RAISE WARNING 'footprint id=% user_id=% : lat/lng 범위 이상치 (lat=%, lng=%) — geom 비움',
            NEW.id, NEW.user_id, NEW.lat, NEW.lng;
        NEW.geom := NULL;
    ELSE
        NEW.geom := ST_SetSRID(ST_MakePoint(NEW.lng, NEW.lat), 4326);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_footprints_set_geom
    BEFORE INSERT OR UPDATE OF lat, lng ON footprints
    FOR EACH ROW
    EXECUTE FUNCTION fn_footprints_set_geom();

-- 반경 조회(#115)가 쓴다. geography 로 캐스팅해 ST_DWithin 을 미터로 받되,
-- 이 GiST 인덱스가 bbox 사전 필터로 쓰인다 — spots 의 idx_spots_geom 과 같은 구조.
CREATE INDEX idx_footprints_geom ON footprints USING GIST (geom);

-- ----------------------------------------------------------------
-- 기존 행 보정 — 연결된 스팟 좌표로 채운다
--
-- 이미 있는 발자취는 전부 스팟에서 쓴 것이라 좌표가 없다. 그대로 두면
-- 지도에서 통째로 사라진다. 대략 맞는 자리(그 스팟)에 있는 편이 낫다.
-- 스팟이 없거나(spot_id NULL, ON DELETE SET NULL) 스팟 좌표 자체가 없으면
-- NULL 로 남고, 반경 조회에서 빠진다.
-- ----------------------------------------------------------------
UPDATE footprints f
   SET lat = s.lat,
       lng = s.lng
  FROM spots s
 WHERE f.spot_id = s.id
   AND f.lat IS NULL
   AND s.lat IS NOT NULL
   AND s.lng IS NOT NULL;
