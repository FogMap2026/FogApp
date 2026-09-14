-- ================================================================
-- V11: 좌표가 완전히 같은 스팟 합치기
--
-- 관광공사 API 는 같은 장소를 여러 contentid 로 준다 — 광장(관광지)과 거기서 열리는
-- 축제(행사), 시설과 그 안의 공연장 등. 좌표가 소수점 끝까지 같은 쌍이 전국 247개다
-- (실기기, 09-15). 앱에서는 마커가 포개져 하나만 보이고, 우하단 «인증 가능» 카드는
-- 인천애뜰이라는데 마커를 누르면 위에 얹힌 한복사랑이 열렸다. 하나로 합친다.
--
-- 어느 쪽을 남기나: **행사(content_type_id = '15')가 아닌 쪽**, 그다음 낮은 id.
-- 행사는 기간이 지나면 의미가 없고, 장소 자체가 스팟의 정체다.
--
-- 참조는 살려서 옮긴다:
--   visits             — 남는 스팟으로 옮긴다. 같은 사람이 양쪽을 다 인증했으면 한 건만 남긴다
--                        (UNIQUE (user_id, spot_id)). 정복률은 「방문/스팟」이라 분모·분자가 같이 준다.
--   footprints         — 남는 스팟으로 옮긴다.
--   traveler_positions — 남는 스팟으로 옮긴다.
--   journey_points     — 스팟 참조가 없다.
-- ================================================================

CREATE TEMP TABLE spot_dupes AS
WITH ranked AS (
    SELECT id,
           first_value(id) OVER (
               PARTITION BY lat, lng
               ORDER BY (content_type_id = '15') ASC NULLS FIRST, id ASC
           ) AS keep_id
    FROM spots
    WHERE lat IS NOT NULL AND lng IS NOT NULL
)
SELECT id AS dup_id, keep_id
FROM ranked
WHERE id <> keep_id;

-- visits: 같은 사람이 양쪽을 다 인증했으면 중복 쪽 기록을 지우고, 나머지는 옮긴다.
DELETE FROM visits v
 USING spot_dupes d
 WHERE v.spot_id = d.dup_id
   AND EXISTS (SELECT 1 FROM visits k WHERE k.user_id = v.user_id AND k.spot_id = d.keep_id);

UPDATE visits v
   SET spot_id = d.keep_id
  FROM spot_dupes d
 WHERE v.spot_id = d.dup_id;

UPDATE footprints f
   SET spot_id = d.keep_id
  FROM spot_dupes d
 WHERE f.spot_id = d.dup_id;

UPDATE traveler_positions t
   SET nearest_spot_id = d.keep_id
  FROM spot_dupes d
 WHERE t.nearest_spot_id = d.dup_id;

DELETE FROM spots s
 USING spot_dupes d
 WHERE s.id = d.dup_id;

DROP TABLE spot_dupes;

-- 유니크 인덱스는 걸지 않는다. 다시 생기는 것은 수집기(SpotUpserter)가 막는다 — 같은 좌표가
-- 이미 있으면 새로 만들지 않는다. DB 제약으로 걸면 좌표가 같은 스팟을 만드는 테스트 픽스처
-- (ConquestServiceIT·SpotQueryServiceIT 등) 열 개가 깨지고, 한 건물의 다른 시설처럼 같은
-- 좌표가 정당한 경우도 막는다.
