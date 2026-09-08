-- ================================================================
-- 심사용 계정 시딩 (#157, #141)
--
-- 대회 심사위원은 사무실 책상에서 앱을 켭니다. 그런데 이 앱의 기능은
-- 전부 물리적 위치에 걸려 있습니다 — 방문 인증은 스팟 반경 100m 이내,
-- 발자취 작성은 GPS 정확도 10m 이내. 심사위원은 셋 다 통과하지 못합니다.
--
-- 그러면 로그인해서 회색 안개만 보고 끝납니다. 우리가 만든 것 중
-- 아무것도 보이지 않습니다(#144).
--
-- 게이트 값(100m·10m)은 허위 인증과 도배를 막는 설계의 핵심이라
-- 건드리지 않습니다. 대신 계정 쪽을 채웁니다 — "이미 좀 다녀본
-- 사용자" 의 상태로 만들어 두는 것입니다.
--
-- 로그인 직후 이렇게 보이는 것이 목표입니다.
--   · 서울 일부가 걷혀 있는 안개
--   · 0% 가 아닌 정복률
--   · 걷힌 영역 안에 읽을 수 있는 발자취
--   · 해금된 스팟에 실제 소개글
--
-- ----------------------------------------------------------------
-- 실행
--   docker compose exec -T db psql -U "$DB_USER" -d "$DB_NAME" \
--     -f - < server/scripts/seed_review_account.sql
--
-- 여러 번 돌려도 안전합니다(ON CONFLICT DO NOTHING). 값을 바꿔 다시
-- 돌리면 부족한 만큼만 채웁니다.
--
-- ⚠️ 선행 조건: 심사 계정으로 앱에서 한 번 로그인해 두어야 합니다.
--    users 행은 Firebase 로그인 시점에 생기므로, 그 전에는 붙일
--    대상이 없습니다. 로그인 안 했으면 아래에서 명시적으로 실패합니다.
-- ================================================================

DO $$
DECLARE
    -- ─── 설정 ────────────────────────────────────────────────
    -- 심사자료가 지정한 계정. 도메인만 우리 것으로 바꿔 쓰세요.
    cfg_email        TEXT := 'openapi@fogapp.example';

    -- 시딩할 지역. 소개글이 이미 채워진 곳이어야 해금 화면에 내용이 뜹니다.
    -- 전국 수집(#155) 후에도 소개글은 서울·부산·제주만 차 있습니다.
    --
    -- 지역은 addr1 로 "찾기만" 하고, 실제 시딩과 정복률 계산은 거기서
    -- 얻은 (area_code, sigungu_code) 로 합니다 — 앱의 정복률이
    -- 그 두 코드로 GROUP BY 하기 때문입니다(ConquestRepository).
    -- addr1 문자열로 계산하면 화면에 뜨는 숫자와 어긋납니다.
    cfg_sido         TEXT := '서울';
    cfg_sigungu      TEXT := '종로구';

    -- 정복률은 시군구 단위라 한 구에 몰아야 숫자가 보입니다 —
    -- 여러 구에 흩으면 각각 1~2% 가 됩니다.
    cfg_visits       INT  := 12;

    -- 심사 중 소진되지 않도록. 기본값 3 이면 글 3개 쓰고 끝입니다(#141).
    cfg_quota        INT  := 999;

    -- 심사위원이 "남의 글귀를 발견하는" 경험(Phase 5.5)을 보려면 다른
    -- 사람의 발자취가 있어야 합니다. false 로 두면 본인 글만 보입니다.
    cfg_demo_authors BOOLEAN := TRUE;
    -- ─────────────────────────────────────────────────────────

    judge_id   BIGINT;
    judge_uid  TEXT;
    t_area     TEXT;
    t_sigungu  TEXT;
    demo_a     BIGINT;
    demo_b     BIGINT;
    n_visits   INT;
    n_prints   INT;
    rate       NUMERIC;
BEGIN
    -- ── 1. 심사 계정 확인 ────────────────────────────────────
    SELECT id, firebase_uid INTO judge_id, judge_uid
      FROM users WHERE email = cfg_email;

    IF judge_id IS NULL THEN
        RAISE EXCEPTION E'심사 계정(%)이 users 에 없습니다.\n'
            '  → 앱에서 그 계정으로 한 번 로그인한 뒤 다시 실행하세요.\n'
            '    users 행은 Firebase 로그인 시점에 생깁니다.', cfg_email;
    END IF;

    -- ── 2. 대상 지역 코드 확정 ───────────────────────────────
    -- 정복률이 (area_code, sigungu_code) 로 묶이므로, 시딩도 같은 코드
    -- 안에서 해야 분자와 분모가 맞습니다.
    SELECT s.area_code, s.sigungu_code
      INTO t_area, t_sigungu
      FROM spots s
     WHERE s.addr1 LIKE cfg_sido || '%'
       AND s.addr1 LIKE '%' || cfg_sigungu || '%'
       AND s.area_code IS NOT NULL
       AND s.overview IS NOT NULL AND s.overview <> ''
       AND s.lat IS NOT NULL AND s.lng IS NOT NULL
     GROUP BY s.area_code, s.sigungu_code
     ORDER BY count(*) DESC
     LIMIT 1;

    IF t_area IS NULL THEN
        RAISE EXCEPTION '% %에 조건을 만족하는 스팟이 없습니다. 소개글(overview)과 '
                        '좌표가 있고 area_code 가 채워진 스팟이 필요합니다 — '
                        'cfg_sigungu 를 다른 구로 바꿔보세요.', cfg_sido, cfg_sigungu;
    END IF;

    -- ── 3. 발자취 쿼터 (#141) ────────────────────────────────
    -- 쿼터는 스팟을 정복하면 리셋되는데(#116), 심사위원은 걸어서
    -- 인증할 수 없으니 리셋 경로가 막혀 있습니다.
    UPDATE users SET footprint_quota = cfg_quota WHERE id = judge_id;

    -- ── 4. 방문 인증 이력 ────────────────────────────────────
    -- 좌표는 스팟 중심에서 조금 떨어뜨립니다. 실제 인증은 반경 100m
    -- 안에서 일어나므로 정확히 중심점인 것이 오히려 부자연스럽습니다.
    -- 위도 0.0002° ≒ 22m, 경도 0.0002° ≒ 18m (서울 기준).
    --
    -- geom 은 넣지 않습니다 — trg_visits_set_geom(V4)이 채웁니다.
    --
    -- photo_url 은 앱 어느 화면에서도 렌더링되지 않습니다(Visit 모델에
    -- 필드는 있으나 표시하는 위젯이 없음). NOT NULL 을 채우면서 형식만
    -- 실제와 맞춰 둡니다: /api/visits/photos/{uid}/{spotId}/...
    WITH target AS (
        SELECT id, lat, lng
          FROM spots
         WHERE area_code = t_area
           AND sigungu_code IS NOT DISTINCT FROM t_sigungu
           AND overview IS NOT NULL AND overview <> ''
           AND lat IS NOT NULL AND lng IS NOT NULL
         ORDER BY id
         LIMIT cfg_visits
    )
    INSERT INTO visits (user_id, spot_id, photo_url, lat, lng, verified_at)
    SELECT judge_id,
           t.id,
           '/api/visits/photos/' || judge_uid || '/' || t.id || '/seed.jpg',
           t.lat + 0.0002,
           t.lng - 0.0002,
           now() - (row_number() OVER (ORDER BY t.id) || ' days')::INTERVAL
      FROM target t
    ON CONFLICT (user_id, spot_id) DO NOTHING;

    -- ── 5. 데모 작성자 (선택) ────────────────────────────────
    -- 로그인하지 않는 계정입니다. firebase_uid 를 'seed:' 로 시작하게
    -- 두어 실제 Firebase UID 와 절대 겹치지 않고, 나중에 한 번에
    -- 지울 수 있게 합니다:
    --   DELETE FROM users WHERE firebase_uid LIKE 'seed:%';
    IF cfg_demo_authors THEN
        INSERT INTO users (firebase_uid, nickname)
        VALUES ('seed:traveler-a', '안개를걷는사람'),
               ('seed:traveler-b', '골목길')
        ON CONFLICT (firebase_uid) DO NOTHING;

        SELECT id INTO demo_a FROM users WHERE firebase_uid = 'seed:traveler-a';
        SELECT id INTO demo_b FROM users WHERE firebase_uid = 'seed:traveler-b';
    END IF;

    -- ── 6. 발자취 ────────────────────────────────────────────
    -- 심사위원이 인증한 스팟 근처에 놓습니다. 발자취 조회 반경은
    -- 이동 중 50m, 해금된 스팟 안에서는 150m 라(footprint-redesign 3-2·3-3),
    -- 걷힌 영역 안에 있어야 지도에서 보입니다.
    --
    -- 40~90m 범위로 흩어 놓습니다. 같은 자리에 겹치면 마커가 포개져
    -- 하나로만 보입니다(#117 "정해야 할 것").
    --
    -- spot_id 는 NULL 로 둡니다 — 재설계 이후 발자취는 스팟 리뷰가
    -- 아니라 길목의 글귀입니다. photo_url 도 NULL: 이건 카드에서
    -- 실제로 렌더링되므로, 없는 파일을 가리키면 깨진 이미지가 뜹니다.
    -- LIMIT 을 쓰지 않습니다. row_number() 는 창 순서로 매겨지지만 LIMIT 은
    -- 어느 행이 남을지 보장하지 않아, 둘을 같이 쓰면 rn 이 1~6 이 아닌 값으로
    -- 남아 아래 JOIN 이 조용히 어긋납니다. 글귀 목록(lines)이 rn 1~6 뿐이라
    -- JOIN 자체가 개수를 제한합니다.
    WITH visited AS (
        SELECT v.spot_id, v.lat, v.lng,
               row_number() OVER (ORDER BY v.spot_id) AS rn
          FROM visits v
         WHERE v.user_id = judge_id
    ),
    lines AS (
        SELECT * FROM (VALUES
            (1, '여기서 올려다본 하늘이 좋았다.'),
            (2, '골목 끝까지 가보세요. 안 후회합니다.'),
            (3, '비 온 뒤에 오면 완전히 다른 곳이 됩니다.'),
            (4, '벤치 하나 있습니다. 잠깐 앉았다 가세요.'),
            (5, '여기까지 걸어온 사람만 아는 게 있습니다.'),
            (6, '지나가는 길이었는데 한참 서 있었습니다.')
        ) AS t(rn, content)
    )
    INSERT INTO footprints (user_id, spot_id, content, lat, lng, created_at)
    SELECT CASE
               WHEN NOT cfg_demo_authors THEN judge_id
               WHEN v.rn % 3 = 0 THEN judge_id      -- 1/3 은 본인 글 ("내 발자취" 화면용)
               WHEN v.rn % 3 = 1 THEN demo_a
               ELSE demo_b
           END,
           NULL,
           l.content,
           v.lat + (v.rn * 0.00012),
           v.lng + (v.rn * 0.00009),
           now() - (v.rn || ' hours')::INTERVAL
      FROM visited v
      JOIN lines l ON l.rn = v.rn
     WHERE NOT EXISTS (
         SELECT 1 FROM footprints f WHERE f.content = l.content
     );

    -- ── 7. 좋아요 ────────────────────────────────────────────
    -- like_count 는 footprint_likes 의 캐시입니다(ERD 설계 노트).
    -- 숫자만 올리면 캐시가 어긋나므로 실제 행을 넣고 함께 갱신합니다.
    IF cfg_demo_authors THEN
        INSERT INTO footprint_likes (footprint_id, user_id)
        SELECT f.id, demo_a
          FROM footprints f
         WHERE f.user_id <> demo_a AND f.spot_id IS NULL
         LIMIT 3
        ON CONFLICT (footprint_id, user_id) DO NOTHING;

        -- 방금 좋아요를 넣은 행만 다시 셉니다. 전체를 갱신하면 맞기는 하지만
        -- 시딩 스크립트가 건드릴 이유가 없는 실제 사용자 데이터까지 씁니다.
        UPDATE footprints f
           SET like_count = (SELECT count(*) FROM footprint_likes l
                              WHERE l.footprint_id = f.id)
         WHERE EXISTS (SELECT 1 FROM footprint_likes l
                        WHERE l.footprint_id = f.id AND l.user_id = demo_a);
    END IF;

    -- ── 8. 결과 ──────────────────────────────────────────────
    SELECT count(*) INTO n_visits FROM visits WHERE user_id = judge_id;
    SELECT count(*) INTO n_prints FROM footprints WHERE spot_id IS NULL;

    -- ConquestRepository.aggregate 와 같은 계산입니다.
    SELECT round(100.0 * count(v.id) / NULLIF(count(*), 0), 1)
      INTO rate
      FROM spots s
      LEFT JOIN visits v ON v.spot_id = s.id AND v.user_id = judge_id
     WHERE s.area_code = t_area
       AND s.sigungu_code IS NOT DISTINCT FROM t_sigungu;

    RAISE NOTICE E'\n─────────────────────────────────────────';
    RAISE NOTICE '심사 계정   : % (users.id=%)', cfg_email, judge_id;
    RAISE NOTICE '방문 인증   : %건', n_visits;
    RAISE NOTICE '정복률      : % %% (% % / area=% sigungu=%)',
          COALESCE(rate, 0), cfg_sido, cfg_sigungu, t_area, t_sigungu;
    RAISE NOTICE '발자취      : %건 (길목)', n_prints;
    RAISE NOTICE '발자취 쿼터 : %', cfg_quota;
    RAISE NOTICE E'─────────────────────────────────────────\n';

    IF n_visits = 0 THEN
        RAISE WARNING '방문 인증이 0건입니다. cfg_sigungu 를 다른 구로 바꿔보세요.';
    END IF;
END $$;
