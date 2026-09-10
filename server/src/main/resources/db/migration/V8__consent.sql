-- ================================================================
-- V8: 개인정보·위치정보 수집 동의 이력 (users.privacy_consented_at, location_consented_at)
-- 관련 이슈: #152 (출품 절차 2/8 — 원스토어 반려 사유)
--
-- 원스토어는 "개인정보 수집·활용에 대한 약관 및 동의절차가 구현되지 않은 경우
-- 심사에서 반려"한다고 명시한다. 위치정보는 특히 별도 동의로 분리해야 한다
-- (#152 to-do) — 개인정보 동의 하나에 묶으면 "동의를 받은 게 아니라 받은 척한 것"이다.
--
-- 값을 boolean이 아니라 timestamptz로 두는 이유: "동의했는지"만이 아니라
-- "언제 동의했는지"가 이력이다. 동의 문구가 나중에 바뀌면 이 시각을 기준으로
-- 재동의가 필요한지 판단할 수 있다.
-- ================================================================

ALTER TABLE users
    ADD COLUMN privacy_consented_at  TIMESTAMPTZ,
    ADD COLUMN location_consented_at TIMESTAMPTZ;

COMMENT ON COLUMN users.privacy_consented_at IS
    '개인정보 수집·이용 동의 시각(#152). null이면 미동의.';
COMMENT ON COLUMN users.location_consented_at IS
    '위치정보 수집·이용 동의 시각(#152). 개인정보 동의와 별도로 받는다. null이면 미동의.';
