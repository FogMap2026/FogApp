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

### 🟪 병렬 소셜 트랙 (SOC · 김규현)

발자취·매칭·성향은 대부분 **지도/안개와 무관**하고, 스키마(`footprints`·`matches`·`users.personality_*`)가 [#1](../../issues/1)에서 이미 준비돼 있습니다.
그래서 SOC 작업은 탐험 코어(MAP/UI/API)와 **별도 트랙으로 Phase 1부터 병렬 진행**합니다.

```
탐험 코어 트랙 :  Phase 1 데이터 ─ Phase 2 지도 ─ Phase 3 탐험루프(MVP) ─┐
                                                                          ├─► Phase 4·5 통합·완성
소셜 트랙(SOC) :  성향 설계 ─ 성향 테스트·발자취 API ─ 매칭 알고리즘 ─────┘
                  (Phase 1)    (Phase 2)               (Phase 3)
```

**원칙**: 지도 의존성이 없는 **로직·API·설계**는 앞당기고(Phase 1~3), 지도 통합이 필요한 **UI**만 Phase 4~5에 둔다.
→ 김규현도 Phase 1부터 끊김 없이 작업하고, Phase 4·5에서는 "UI만 붙이면 완성"인 상태가 된다.

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
| 1-7 | 🟪 **여행 성향 테스트 설계**(설문 문항·성향 축·점수 모델) — 지도 의존성 없음 | 🟪 SOC | `feat/social-personality-design` |
| 1-8 | 🟪 **발자취·매칭 API 뼈대**(CRUD, 스키마 기반) | 🟪 SOC / 🟦 API | `feat/social-api-skeleton` |

> 🟪 소셜 트랙 시작: 1-7·1-8은 **#1 스키마에만 의존**(완료)하므로 인증·지도 작업과 무관하게 병렬 착수 가능.

**완료 기준(DoD)**: 로그인 후 서버에서 "특정 지역 스팟 목록"을 좌표와 함께 받아올 수 있다.
소셜 트랙: 성향 점수 모델이 확정되고, 발자취·매칭 API 뼈대가 동작한다.

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
| 2-6 | 🟪 **성향 테스트 화면 + 결과 저장**(`users.personality_*`) | 🟪 SOC / 🟩 UI | `feat/social-personality-test` |
| 2-7 | 🟪 **발자취 작성 API 완성 + 좋아요·공감 API** | 🟪 SOC | `feat/social-footprint-api` |

> 🟪 소셜 트랙: 2-6은 로그인(1-1)에만 의존, 2-7은 발자취 뼈대(1-8)에 의존 — 지도 코어와 병렬.

**완료 기준(DoD)**: 앱을 켜면 안개 덮인 지도가 뜨고, 내 위치가 지도 위에 실시간으로 표시된다.
소셜 트랙: 성향 테스트를 마치면 결과가 저장되고, 발자취·좋아요 API가 완성된다.

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
| 3-8 | 🟪 **매칭 알고리즘**(성향 유사도 + 지역/거리 필터) 선행 구현 | 🟪 SOC | `feat/social-matching-algo` |

> 🟪 소셜 트랙: 3-8은 성향 데이터(2-6)에만 의존 — 탐험 루프와 무관하게 병렬. Phase 5에서 화면만 붙이면 됨.

**완료 기준(DoD)**: 스팟에 도달해 사진을 찍으면 안개가 걷히고, 지역 정복률이 올라간다. → **데모 가능한 MVP 완성**
소셜 트랙: 성향 유사도 기반 매칭 후보 산출 로직이 API로 동작한다.

---

## Phase 4 — 발자취 통합·완성 (Footprints Integration)

**목표**: Phase 2에서 만든 발자취·좋아요 API를 **지도·UI에 통합**해 완성한다.
(작성/좋아요 API는 2-7에서 선행 완료 → 여기서는 지도 연결·화면 중심)

| # | 작업 | 영역 | 브랜치 예시 |
|---|------|------|-------------|
| 4-1 | 지도에서 스팟 탭 → 발자취 작성 플로우 연결 | 🟪 SOC / 🟩 UI | `feat/social-footprint-flow` |
| 4-2 | 지도/스팟에서 발자취 카드 조회 UI | 🟩 UI / 🟪 SOC | `feat/ui-footprint-card` |
| 4-3 | 좋아요·공감 UI 연동(2-7 API 사용) | 🟪 SOC / 🟩 UI | `feat/ui-reaction` |
| 4-4 | 내 발자취 모아보기(프로필) | 🟩 UI | `feat/ui-profile-footprints` |

> 지도(Phase 2·3)가 있어야 "장소에 남기고 지도에서 보는" 경험이 완성되므로, UI 통합은 여기에 둔다.

**완료 기준(DoD)**: 방문한 스팟에 발자취를 남기고, 지도에서 다른 사람 발자취를 보고 좋아요를 누를 수 있다.

---

## Phase 5 — 매칭 화면·완성 (Matching Completion)

**목표**: 선행 구현된 **성향 테스트(1-7·2-6)·매칭 알고리즘(3-8)**을 화면으로 완성한다.

| # | 작업 | 영역 | 브랜치 예시 |
|---|------|------|-------------|
| 5-1 | 매칭 결과·동행 추천 화면 | 🟩 UI / 🟪 SOC | `feat/ui-match-result` |
| 5-2 | 동행 요청·수락 플로우(`matches.status`) | 🟪 SOC | `feat/social-match-request` |
| 5-3 | 성향 결과 프로필 노출 + 성향 맞춤 발자취 필터 | 🟪 SOC / 🟩 UI | `feat/social-personality-profile` |

> 설계(1-7)·저장(2-6)·알고리즘(3-8)이 이미 끝나 있어, Phase 5는 **화면·상호작용 완성**에 집중.

**완료 기준(DoD)**: 성향이 비슷한 동행을 추천받고, 요청·수락으로 매칭이 성사된다.

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
- **🟪 소셜 트랙(SOC)은 Phase 1부터 별도 병렬**로 진행 — 지도 의존성 없는 로직·API·설계를 선행.
  (성향 설계 1-7 → 성향 UI·발자취 API 2-6·2-7 → 매칭 알고리즘 3-8)
- **Phase 3은 Phase 1·2가 모두 있어야** 완성됨(핵심 통합 지점).
- **Phase 4·5**는 지도(2·3)와 선행된 소셜 트랙을 **통합·UI 완성**하는 단계(대부분 로직은 이미 있음).
- **Phase 6**은 Phase 2(지도)·3(위치)·1(OpenAPI)에 의존.

```
탐험 코어 :        ┌──── Phase 1 (데이터) ────┐
        Phase 0 ─┤                            ├─ Phase 3 ─┬─ Phase 4 ─┐
                 └──── Phase 2 (지도) ────────┘           ├─ Phase 5 ─┼─ Phase 7
                                              └ Phase 6 ──┘
소셜 트랙 :        성향설계(1-7) ─ 성향·발자취(2-6·2-7) ─ 매칭알고리즘(3-8) ──┘
                  └───────────── SOC 김규현, Phase 1부터 병렬 ──────────────┘
```

---

## ✅ 마일스톤 요약

| 마일스톤 | 완료 시 상태 | 태그 |
|----------|--------------|------|
| M0 | 모두가 개발 시작 가능 | `v0.1` |
| M1 | 로그인 + 스팟 데이터 확보 · 🟪 성향 점수 모델 확정 | `v0.2` |
| M2 | 안개 지도 + 내 위치 표시 · 🟪 성향 테스트·발자취 API 완성 | `v0.3` |
| **M3** | **탐험 핵심 루프 동작 (MVP)** · 🟪 매칭 알고리즘 동작 | `v0.4` |
| M4 | 발자취 지도 통합·완성 | `v0.5` |
| M5 | 매칭 화면·동행 성사 완성 | `v0.6` |
| M6 | 실시간 위치 공유 | `v0.7` |
| M7 | 출품 완성본 | `v1.0` |

---

> 이 계획은 고정이 아닙니다. 각 Phase 시작 전 팀 회의에서 범위를 조정하고,
> 세부 항목은 이슈로 분해해 담당자에게 할당하세요. 함께 안개를 걷어냅시다 🌫️➡️🗺️
