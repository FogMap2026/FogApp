# 🗺️ FogApp 개발 로드맵 (Planning)

> 안개 지도 탐험 서비스를 **0에서 완성까지** 끌고 가기 위한 단계별 계획서입니다.
> [README.md](README.md)의 기능 정의와 [CONTRIBUTING.md](CONTRIBUTING.md)의 협업 규칙(브랜치·영역 오너)을 기준으로 작성했습니다.

---

## 📌 이 문서의 사용법

- 각 **Phase = 하나의 마일스톤**입니다. Phase가 끝날 때마다 `dev`에서 통합 테스트 → 태그(`v0.x`)를 찍습니다.
- 작업 항목은 [CONTRIBUTING.md](CONTRIBUTING.md)의 브랜치 접두어(`feat/api-*`, `feat/map-*` …)와 영역 오너에 매핑됩니다.
- 실제 진행 시에는 각 항목을 **GitHub 이슈로 쪼개서** 담당자에게 할당하세요.

### 담당 영역 약어

| 약어 | 영역 | 담당자 |
|------|------|--------|
| 🟦 **API** | 백엔드·서버 | 박근호 [@PGH0621](https://github.com/PGH0621) |
| 🟩 **UI** | 모바일 프론트 | 송진오 [@oorony](https://github.com/oorony) |
| 🟨 **MAP** | 지도·위치·안개 | 김시진 [@sijin2170](https://github.com/sijin2170) |
| 🟪 **SOC** | 매칭·소셜·발자취 | 김규현 [@k2hop1213](https://github.com/k2hop1213) |
| 🟧 **INF** | 인프라·사진·알림 | 송건희 [@songkh1201](https://github.com/songkh1201) |

---

## 🧭 전체 그림 — 8단계

```
Phase 0  기반 다지기        프로젝트 뼈대 · 개발환경 · 협업 셋업
   ↓
Phase 1  인증 & 데이터 토대  로그인 · DB(PostGIS) · 관광공사 OpenAPI 수집
   ↓
Phase 2  지도 & 안개 코어    지도 렌더 · 안개 오버레이 · 스팟 배치 · GPS 추적
   ↓
Phase 3  탐험의 핵심 루프    근접 감지 · 사진 인증 · 안개 해제 · 정복률   ★MVP★
   ↓
Phase 4  발자취 시스템       기록 작성/조회 · 좋아요·공감
   ↓
Phase 5  성향 매칭          성향 테스트 · 매칭 알고리즘 · 동행 추천
   ↓
Phase 6  실시간 위치 공유    캐릭터 지도 · 30분 갱신 · 푸시 알림
   ↓
Phase 7  완성 & 출품         QA · 성능 · 배포 · 발표 자료
```

> **★MVP 기준선★**: Phase 3까지 완료되면 "안개를 걷으며 탐험한다"는 **핵심 가치가 동작**합니다.
> 시간이 부족하면 Phase 3을 데모 가능한 최소 완성본으로 잡고, 4~6은 우선순위대로 붙입니다.

---

## Phase 0 — 기반 다지기 (Foundation)

**목표**: 5명이 충돌 없이 동시에 개발을 시작할 수 있는 상태를 만든다.

| # | 작업 | 영역 | 브랜치 예시 |
|---|------|------|-------------|
| 0-1 | `dev` 브랜치 생성 + `main`/`dev` 브랜치 보호 규칙 설정 | 🟦 API(PM) | — |
| 0-2 | 이슈/PR 템플릿, 라벨(feature/bug/영역별) 생성 | 🟦 API(PM) | `chore/repo-setup` |
| 0-3 | Flutter 앱 스캐폴딩(`app/`) + 폴더 구조·라우팅·상태관리 세팅 | 🟩 UI | `chore/app-scaffold` |
| 0-4 | Spring Boot 서버 스캐폴딩(`server/`) + 헬스체크 API | 🟦 API | `chore/server-scaffold` |
| 0-5 | PostgreSQL + PostGIS 로컬 실행(docker-compose) | 🟧 INF | `chore/infra-db` |
| 0-6 | Firebase 프로젝트 생성(Auth/Firestore/Storage/FCM) + 설정 `.gitignore` | 🟧 INF | `chore/infra-firebase` |
| 0-7 | `.env.example`, `.gitignore`, 시크릿 관리 규칙 문서화 | 🟧 INF | `docs/env-guide` |
| 0-8 | GitHub Actions CI 뼈대(빌드·린트) | 🟧 INF | `chore/ci-skeleton` |

**완료 기준(DoD)**: 앱이 빈 화면이라도 실행되고, 서버 헬스체크가 200을 반환하며, 모두 로컬 DB에 연결된다.

---

## Phase 1 — 인증 & 데이터 토대 (Auth & Data)

**목표**: 사용자가 로그인할 수 있고, 지도에 뿌릴 관광 스팟 데이터가 DB에 쌓인다.

| # | 작업 | 영역 | 브랜치 예시 |
|---|------|------|-------------|
| 1-1 | 소셜 로그인(Firebase Auth) + 앱 로그인/온보딩 화면 | 🟩 UI / 🟧 INF | `feat/ui-auth`, `feat/infra-auth` |
| 1-2 | 서버 JWT 검증 미들웨어 · 사용자 프로필 API | 🟦 API | `feat/api-auth` |
| 1-3 | DB 스키마 설계(users, spots, visits, footprints, matches …) | 🟦 API | `feat/api-schema` |
| 1-4 | **관광공사 OpenAPI 연동** — 지역기반 스팟 수집·정제·캐싱 배치 | 🟦 API | `feat/api-tour-openapi` |
| 1-5 | 스팟 좌표를 PostGIS `geometry`로 저장 + 공간 인덱스 | 🟨 MAP / 🟦 API | `feat/api-spot-geo` |
| 1-6 | 스팟 조회 API(지역별/반경별) | 🟦 API | `feat/api-spot-query` |

**완료 기준(DoD)**: 로그인 후 서버에서 "특정 지역 스팟 목록"을 좌표와 함께 받아올 수 있다.

---

## Phase 2 — 지도 & 안개 코어 (Map & Fog Core)

**목표**: 지도 위에 회색 안개가 덮이고, 스팟이 숨겨진 상태로 배치된다.

| # | 작업 | 영역 | 브랜치 예시 |
|---|------|------|-------------|
| 2-1 | Naver Maps SDK 연동 + 기본 지도 화면 | 🟨 MAP | `feat/map-base` |
| 2-2 | **안개 오버레이 렌더링**(전국 회색 레이어) | 🟨 MAP | `feat/map-fog-overlay` |
| 2-3 | Phase 1의 스팟 API를 지도에 로드(숨김 상태 마커) | 🟨 MAP / 🟩 UI | `feat/map-spot-load` |
| 2-4 | 실시간 GPS 추적 + 내 위치 표시 | 🟨 MAP | `feat/map-gps-track` |
| 2-5 | 지도 화면 UI/UX(줌·이동·현재 지역 표시) | 🟩 UI | `feat/ui-map-screen` |

**완료 기준(DoD)**: 앱을 켜면 안개 덮인 지도가 뜨고, 내 위치가 지도 위에 실시간으로 표시된다.

---

## Phase 3 — 탐험의 핵심 루프 (Explore Loop) ★MVP★

**목표**: **도달 → 인증 → 안개 해제 → 정복률 상승**의 핵심 게임 루프를 완성한다.

| # | 작업 | 영역 | 브랜치 예시 |
|---|------|------|-------------|
| 3-1 | 스팟 반경 **geofencing**(근접 감지) | 🟨 MAP | `feat/map-geofence` |
| 3-2 | 근접 시 근접 알림(로컬/푸시) | 🟨 MAP / 🟧 INF | `feat/map-proximity-alert` |
| 3-3 | 현장 사진 촬영 → **방문 인증** UI | 🟩 UI | `feat/ui-visit-verify` |
| 3-4 | 인증 사진 업로드 파이프라인(Storage) + 인증 API | 🟧 INF / 🟦 API | `feat/api-visit`, `feat/infra-photo-upload` |
| 3-5 | 인증 성공 시 해당 반경 **안개 걷힘** 애니메이션 | 🟨 MAP | `feat/map-fog-clear` |
| 3-6 | 스팟 정보(명칭·주소·소개) 해금 표시 | 🟩 UI | `feat/ui-spot-detail` |
| 3-7 | 지역별 **정복률(%) 계산·표시** | 🟦 API / 🟩 UI | `feat/api-conquest-rate`, `feat/ui-conquest` |

**완료 기준(DoD)**: 스팟에 도달해 사진을 찍으면 안개가 걷히고, 지역 정복률이 올라간다. → **데모 가능한 MVP 완성**

---

## Phase 4 — 발자취 시스템 (Footprints)

**목표**: 사용자가 장소에 기록을 남기고, 남의 발자취를 감상·공감한다.

| # | 작업 | 영역 | 브랜치 예시 |
|---|------|------|-------------|
| 4-1 | 발자취 작성(텍스트+사진) API·저장 | 🟪 SOC / 🟦 API | `feat/social-footprint-write` |
| 4-2 | 지도/스팟에서 발자취 카드 조회 UI | 🟩 UI / 🟪 SOC | `feat/ui-footprint-card` |
| 4-3 | 좋아요·공감 상호작용 | 🟪 SOC | `feat/social-reaction` |
| 4-4 | 내 발자취 모아보기(프로필) | 🟩 UI | `feat/ui-profile-footprints` |

**완료 기준(DoD)**: 방문한 스팟에 발자취를 남기고, 다른 사람 발자취에 좋아요를 누를 수 있다.

---

## Phase 5 — 성향 매칭 (Matching)

**목표**: 여행 성향이 맞는 동행을 찾아 추천한다.

| # | 작업 | 영역 | 브랜치 예시 |
|---|------|------|-------------|
| 5-1 | 여행 성향 테스트 설문 설계(즉흥/계획, 휴양/관광 …) | 🟪 SOC | `feat/social-personality-test` |
| 5-2 | 성향 테스트 UI + 결과 저장 | 🟩 UI / 🟪 SOC | `feat/ui-personality-test` |
| 5-3 | **매칭 알고리즘**(성향 유사도 + 지역/거리 필터) | 🟪 SOC | `feat/social-matching` |
| 5-4 | 매칭 결과·동행 추천 화면 | 🟩 UI | `feat/ui-match-result` |

**완료 기준(DoD)**: 성향 테스트를 마치면 성향이 비슷한 사용자를 추천받는다.

---

## Phase 6 — 실시간 위치 공유 (Live Sharing)

**목표**: 지도 위 캐릭터로 여정을 공유하고, 주변 스팟을 주기적으로 갱신한다.

| # | 작업 | 영역 | 브랜치 예시 |
|---|------|------|-------------|
| 6-1 | 캐릭터 기반 내 위치/여정 시각화 | 🟨 MAP / 🟩 UI | `feat/map-character` |
| 6-2 | 30분 단위 주변 스팟 데이터 갱신(위치기반 OpenAPI) | 🟦 API / 🟪 SOC | `feat/social-live-refresh` |
| 6-3 | 실시간 위치 동기화(Firestore) | 🟪 SOC | `feat/social-live-sync` |
| 6-4 | 푸시 알림 통합(FCM) — 근접·조우 이벤트 | 🟧 INF | `feat/infra-fcm` |

**완료 기준(DoD)**: 지도에서 캐릭터로 표현된 사용자의 위치가 주기적으로 갱신·공유된다.

---

## Phase 7 — 완성 & 출품 (Polish & Release)

**목표**: 안정화하고 대회 제출·발표 준비를 마친다.

| # | 작업 | 영역 |
|---|------|------|
| 7-1 | 통합 QA·버그 픽스(`fix/*`) | 전원 |
| 7-2 | 성능 최적화(지도 렌더·쿼리·이미지) | 🟨 MAP / 🟦 API / 🟧 INF |
| 7-3 | 배포 파이프라인 완성(CI/CD) + 릴리스 빌드 | 🟧 INF |
| 7-4 | 시연 시나리오·발표 자료·데모 영상 | 🟦 API(PM) 주도, 전원 |
| 7-5 | 라이선스 확정 + README 최종 정리 | 🟦 API(PM) |

**완료 기준(DoD)**: `main`에 안정 버전이 있고, 시연·발표 준비가 끝난다. 🎉

---

## 🔗 단계 간 의존 관계 (동시 진행 팁)

- **Phase 0**은 반드시 먼저. 이후 **Phase 1(데이터)과 Phase 2(지도)는 상당 부분 병렬** 가능
  (지도팀은 더미 좌표로 먼저 시작 → API 준비되면 실 데이터로 교체).
- **Phase 3은 Phase 1·2가 모두 있어야** 완성됨(핵심 통합 지점).
- **Phase 4·5**는 Phase 3 이후 병렬 가능(발자취=SOC/UI, 매칭=SOC/UI).
- **Phase 6**은 Phase 2(지도)·3(위치)·1(OpenAPI)에 의존.

```
        ┌────────── Phase 1 (데이터) ─────────┐
Phase 0 ┤                                      ├─ Phase 3 ─┬─ Phase 4 ─┐
        └────────── Phase 2 (지도) ───────────┘            ├─ Phase 5 ─┼─ Phase 7
                                              └─ Phase 6 ──┘
```

---

## ✅ 마일스톤 요약

| 마일스톤 | 완료 시 상태 | 태그 |
|----------|--------------|------|
| M0 | 모두가 개발 시작 가능 | `v0.1` |
| M1 | 로그인 + 스팟 데이터 확보 | `v0.2` |
| M2 | 안개 지도 + 내 위치 표시 | `v0.3` |
| **M3** | **탐험 핵심 루프 동작 (MVP)** | `v0.4` |
| M4 | 발자취 시스템 | `v0.5` |
| M5 | 성향 매칭 | `v0.6` |
| M6 | 실시간 위치 공유 | `v0.7` |
| M7 | 출품 완성본 | `v1.0` |

---

> 이 계획은 고정이 아닙니다. 각 Phase 시작 전 팀 회의에서 범위를 조정하고,
> 세부 항목은 이슈로 분해해 담당자에게 할당하세요. 함께 안개를 걷어냅시다 🌫️➡️🗺️
