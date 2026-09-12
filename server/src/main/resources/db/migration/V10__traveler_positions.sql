-- ================================================================
-- V10: traveler_positions — 주변 여행자 익명 표시 (#133, 6-3)
--
-- 신고 접수본("소상공인등의 위치기반서비스 사업내용 설명자료", 09-10)이 이미
-- 이 기능을 전제로 쓰여 있다. 구속 조건 넷:
--
--   1. opt-in            — POST 를 보낸 사람만 이 테이블에 행이 생긴다
--   2. 30분 경과분만 제공 — updated_at 이 30분 안 지났으면 조회에서 제외 (서비스 계층)
--   3. 이용자별 최신 1건만 — user_id 가 PK. 이력 테이블이 아니다
--   4. UPSERT            — INSERT 가 아니라 갱신·덮어쓰기. 과거 위치가 쌓이지 않는다
--
-- 좌표 자체는 저장하지 않는다. 가장 가까운 스팟 id 로만 환산해 저장한다 — #133
-- 설계(익명·30분 텀·스팟 기준)의 "스팟 기준"이 이 저장 형태로 강제된다.
-- ================================================================

CREATE TABLE traveler_positions (
    user_id         BIGINT PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
    nearest_spot_id BIGINT NOT NULL REFERENCES spots (id) ON DELETE CASCADE,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE traveler_positions IS
    '주변 여행자 익명 표시(#133)용 최신 위치 1건. user_id 가 PK라 이력이 쌓이지 않는다. '
    '행이 있으면 공유 중, 없으면 꺼짐(opt-in) — 별도 boolean 플래그를 두지 않는다.';
COMMENT ON COLUMN traveler_positions.nearest_spot_id IS
    '좌표가 아니라 가장 가까운 스팟 id. 정확한 좌표는 저장하지 않는다.';
COMMENT ON COLUMN traveler_positions.updated_at IS
    '마지막 갱신 시각. 조회 시 이 값이 30분 이상 지난 행만 응답에 포함된다(서비스 계층에서 필터).';

-- 「내 것 제외 + 반경 내 스팟」 조회가 spots.geom(V7 의 geography GiST)을 타므로,
-- 이 테이블 쪽은 스팟별 최신 시각 필터링에만 쓰인다. user_id 는 이미 PK라 별도
-- 인덱스가 필요 없다.
CREATE INDEX idx_traveler_positions_spot ON traveler_positions (nearest_spot_id);
