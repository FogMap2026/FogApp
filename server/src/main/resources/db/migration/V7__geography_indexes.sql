-- ================================================================
-- V7: 반경 조회가 GiST 인덱스를 타도록 geography 함수 인덱스로 교체
-- 관련 이슈: #125
--
-- geom 컬럼(geometry)에 GiST 인덱스를 걸어두고, 쿼리는 geom::geography 로
-- 캐스팅해 ST_DWithin 을 쓰고 있었다. 둘이 다른 타입이라 인덱스가 매칭되지
-- 않아, 반경 조회가 전부 Seq Scan 이었다.
--
-- geography 로 캐스팅한 것 자체는 맞는 선택이다 — 반경을 도(degree)가 아니라
-- 미터로 그대로 받기 위해서다. 인덱스를 그에 맞춰 만들지 않은 것이 문제였다.
--
-- 운영 DB(스팟 12,600행)에서 측정한 값:
--
--   현재  : Seq Scan,          Rows Removed 12,519,  93.5 ms
--   수정  : Bitmap Index Scan, Rows Removed     34,   4.3 ms
--
-- 약 21배다. 전국 수집(#144)으로 스팟이 2,669 → 12,600 이 되면서 격차가
-- 커졌다 — Seq Scan 은 행 수에 비례하지만 인덱스 스캔은 그렇지 않다.
-- ================================================================

-- ----------------------------------------------------------------
-- spots — 지도의 주변 스팟 조회(SpotRepository.findWithinRadius)
-- ----------------------------------------------------------------
CREATE INDEX idx_spots_geom_geography ON spots USING GIST ((geom::geography));

-- ----------------------------------------------------------------
-- footprints — 내 주변 발자취 조회(FootprintRepository.findWithinRadius)
-- ----------------------------------------------------------------
CREATE INDEX idx_footprints_geom_geography ON footprints USING GIST ((geom::geography));

-- ----------------------------------------------------------------
-- 기존 geometry 인덱스 제거
--
-- 남겨두면 쓰이지도 않으면서 INSERT/UPDATE 비용만 늘린다. 저장소 전체에서
-- geom 을 쓰는 쿼리는 셋뿐이고 전부 geography 로 캐스팅한다.
--
--   SpotRepository.findWithinRadius       geom::geography  → 위 새 인덱스
--   FootprintRepository.findWithinRadius  geom::geography  → 위 새 인덱스
--   VisitRepository.isWithinSpotRadius    geom::geography  (단, id = :spotId 로
--                                         먼저 좁혀 기본키를 타므로 공간 인덱스가
--                                         필요 없다)
--
-- ⚠️ 앞으로 반경 조회를 새로 만들 때도 geography 로 캐스팅할 것. geometry 로
--    쓰면 이 인덱스를 못 타고 다시 Seq Scan 이 된다.
-- ----------------------------------------------------------------
DROP INDEX IF EXISTS idx_spots_geom;
DROP INDEX IF EXISTS idx_footprints_geom;

-- visits.geom 의 idx_visits_geom(V4)은 건드리지 않는다.
-- 지금 visits 를 반경으로 조회하는 쿼리가 없어 이 인덱스는 쓰이지 않지만,
-- 이번 변경의 목적은 "쓰이는 조회가 인덱스를 타게 하는 것"이라 범위를 넘는다.
-- 정리하려면 별도 이슈로 다룰 것.
