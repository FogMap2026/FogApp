# 🌫️ FogApp

> 안개 낀 지도를 발로 뛰어 밝히고, 여행 성향이 맞는 동행과 함께 영토를 기록해나가는 **탐험형 여행 플랫폼**

대한민국 전역이 회색 안개(정복률 0%)로 덮인 상태에서 시작합니다. 사용자가 실제로 그 장소에 도달해 사진으로 방문을 인증하면 안개가 걷히고 관광 스팟이 해금됩니다. 단순히 구경하는 여행을 **지도를 정복하고 완성하는 게임적 경험**으로 바꾸고, 여행 성향이 비슷한 동행과 서로의 발자취를 이어가는 서비스입니다.

---

## ✨ 주요 기능

### 1. 안개 지도 탐험 (Fog-of-War Map)
- 한국관광공사 OpenAPI 기반 전국 수만 개 관광 스팟을 안개 아래 **숨겨진 탐험 포인트**로 배치
- 실제 위치에 도달하면 안개가 걷히고 스팟의 명칭·주소·소개 정보가 자동 공개
- 지역별 정복률(예: `경주 15%`)을 실시간 수치로 피드백하여 즉각적인 성취감 제공

### 2. 위치 기반 인증 & 알림
- 스팟 반경 접근 시 실시간 위치 기반 근접 알림 — 앱 사용 중 인앱 알림(Phase 3), 백그라운드 푸시(Phase 6)
- 현장에서 사진 촬영으로 방문 인증 → 상세 정보 및 리스트 해금

### 3. 여행 성향 매칭 (Partner Matching)
- 즉흥성/계획성, 휴양/관광, 외향/내향 등 다각도로 분석하는 여행 성향 테스트
- 지역별·이동 거리·활동 범위 설정을 통한 정교한 동행 매핑
- 성향이 일치하는 파트너와 보완적 동선 구축 및 협동 탐험

### 4. 발자취 시스템 (Footprints)
- 사용자가 남긴 텍스트·사진 기록이 그 자리의 **발자취**로 지도에 남음
- 앞서간 여행자의 발자취를 클릭해 감상·현장 정보 확인
- 좋아요·공감을 통한 **비동기적 유대감** 형성 (서로 모르는 유저를 '장소'라는 공통분모로 연결)

### 5. 캐릭터 기반 실시간 위치 공유
- 지도 위 캐릭터로 여정을 시각화, 30분 단위 주변 스팟 데이터 갱신
- "저 여행자는 지금 어떤 곳 근처에 있는지"를 맥락 있게 전달

---

## 🛠️ 기술 스택

> 아래는 **실제로 채택·적용된 스택**입니다. 버전은 [app/pubspec.yaml](app/pubspec.yaml)·[server/build.gradle](server/build.gradle)이 정본입니다.
>
> ⚠️ **Flutter는 3.44.9로 맞춰주세요.** `app/android`(Gradle 9.1 · AGP 9.0)와 `app/ios`(implicit engine API) 스캐폴딩이
> 이 버전 기준이라, 더 낮은 버전에서는 **네이티브 빌드가 아예 되지 않습니다.** CI도 같은 버전으로 고정돼 있습니다.

| 영역 | 기술 | 버전 | 선택 이유 |
|------|------|------|-----------|
| **모바일 앱** | Flutter (Dart) + Riverpod | **Flutter 3.44.9** / Dart ≥3.4 | iOS/Android 단일 코드베이스, 지도·카메라·위치 플러그인 성숙 |
| **지도 SDK** | Naver Maps SDK (`flutter_naver_map`) | 1.3.x | 국내 지도 정확도, 커스텀 안개 오버레이 구현 용이 |
| **백엔드** | Spring Boot (Java) | 3.3.2 / Java 17 | REST API, 관광공사 OpenAPI 연동, 안정적 서버 |
| **데이터베이스** | PostgreSQL + **PostGIS** | PostGIS 3.4 (`postgis/postgis:16-3.4`) | 지리공간 쿼리·geofencing·GPS 궤적→Polygon 변환의 핵심 |
| **DB 마이그레이션** | Flyway (+ Hibernate `ddl-auto: validate`) | — | 스키마 버전 관리. 스키마 정본은 `V*.sql` |
| **인증** | Firebase Auth + Firebase Admin SDK | admin 9.3.0 | 앱이 발급한 ID 토큰을 서버가 `verifyIdToken`으로 검증 |
| **실시간/알림** | Firebase (Firestore + FCM) | — | 실시간 위치 공유, 푸시 알림 (Phase 6) |
| **스토리지** | 서버 직접 저장 (로컬 디스크) | — | 방문 인증 사진 (Phase 3). Firebase Storage는 무료 요금제에서 버킷 생성이 막혀 미채택 — [STORAGE_SETUP.md](docs/STORAGE_SETUP.md) |
| **테스트** | JUnit 5 + **Testcontainers**(PostGIS) / `flutter test` | — | 실제 PostGIS 컨테이너로 공간 쿼리까지 검증 |
| **빌드 도구** | Gradle 8.8 | — | Spring Boot 3.3.x 호환 버전으로 고정 |
| **CI/CD** | GitHub Actions | — | 변경 영역(`app`/`server`) 감지 후 해당 잡만 실행 |

### 📡 데이터 활용 — 한국관광공사 OpenAPI (필수)
- **지역기반관광정보조회**: 지역별 관광 스팟 목록 → 안개 지도 탐험 포인트 배치
- **위치기반관광정보조회**: 사용자 주변 스팟 30분 갱신 → 캐릭터 실시간 위치 공유
- **공통정보조회 / 이미지정보조회**: 발자취 카드의 공식 명칭·분류·위치·이미지 기본 정보

---

## 👥 팀 구성 및 역할 분담 (5인)

각 팀원이 하나의 명확한 영역을 오너십으로 가집니다.

| 역할 | 담당자 | GitHub |
|------|--------|--------|
| **PM & Backend Lead** — 서버 · API | 박근호 | [@PGH0621](https://github.com/PGH0621) |
| **Mobile Frontend** — 앱 UI/UX | 송진오 | [@oorony](https://github.com/oorony) |
| **Map & Location** — 지도 · 위치 · 안개 | 김시진 | [@sijin2170](https://github.com/sijin2170) |
| **Social & Matching** — 매칭 · 소셜 · 발자취 | 김규현 | [@k2hop1213](https://github.com/k2hop1213) |
| **DevOps & Data** — 인프라 · 사진 · 알림 | 송건희 | [@songkh1201](https://github.com/songkh1201) |

### 1️⃣ PM & Backend Lead — 서버 · API · 박근호 [@PGH0621](https://github.com/PGH0621)
- 서버 아키텍처 설계 및 REST API 개발
- **한국관광공사 OpenAPI 연동** (관광 스팟 수집·캐싱·정제)
- DB 스키마 설계, 팀 일정·이슈 관리
- `Spring Boot` · `PostgreSQL` · `OpenAPI`

### 2️⃣ Mobile Frontend — 앱 UI/UX · 송진오 [@oorony](https://github.com/oorony)
- 앱 화면 설계·구현, 네비게이션, 상태 관리
- 발자취 카드, 프로필, 매칭, 탐험 화면 UI/UX
- `Flutter` · `Dart` · `상태관리(Riverpod/Bloc)`

### 3️⃣ Map & Location — 지도 · 위치 · 안개 시스템 · 김시진 [@sijin2170](https://github.com/sijin2170)
- 안개 오버레이 렌더링 및 **안개 해제 로직**
- GPS 추적, geofencing(스팟 근접 인증 알림)
- GPS 이동 궤적(Point) → 면적(Polygon) 변환
- `Naver Maps SDK` · `PostGIS` · `Geolocation`

### 4️⃣ Social & Matching — 매칭 · 소셜 · 발자취 · 김규현 [@k2hop1213](https://github.com/k2hop1213)
- 여행 성향 테스트 및 매칭 알고리즘
- 발자취 기록·조회, 좋아요·공감 상호작용
- 실시간 위치 공유(30분 갱신) 로직
- `Firestore` · `매칭 알고리즘` · `실시간 동기화`

### 5️⃣ DevOps & Data — 인프라 · 사진 · 알림 · 송건희 [@songkh1201](https://github.com/songkh1201)
- 방문 인증 사진 업로드·스토리지 파이프라인
- 푸시 알림(FCM), 인증(Auth) 연동
- CI/CD, 배포, 환경 구성
- `사진 저장(서버)` · `FCM` · `GitHub Actions`

---

## 📁 프로젝트 구조

```
FogApp/
├── app/                              # Flutter 모바일 앱
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/                   # personality.dart …
│   │   ├── screens/                  # auth_gate · login · map
│   │   │   └── social/               # 성향 테스트·결과 화면
│   │   ├── services/                 # api_client · auth · personality
│   │   └── widgets/                  # 안개 오버레이·발자취 카드 (예정)
│   ├── test/
│   └── pubspec.yaml
├── server/                           # Spring Boot 백엔드
│   └── src/main/java/com/fogapp/
│       ├── auth/                     # Firebase 토큰 검증 · Security 설정
│       ├── common/                   # 공통 예외·에러 응답
│       ├── user/                     # 프로필 · 성향 저장
│       ├── spot/                     # 스팟 조회(지역별·반경별)
│       ├── tour/                     # 관광공사 OpenAPI 수집 배치
│       ├── footprint/                # 발자취 CRUD · 좋아요
│       └── match/                    # 매칭 요청 · 성향 유사도 추천
│   └── src/main/resources/db/migration/   # Flyway V1~V3 (스키마 정본)
├── docs/                             # 설계·운영 문서 (아래 표)
├── .github/                          # CI · CODEOWNERS · 이슈/PR 템플릿
├── docker-compose.yml                # PostgreSQL + PostGIS 로컬 실행
├── planning.md                       # 단계별 로드맵 + 현재 진행 상황
└── CONTRIBUTING.md                   # 협업 규칙 (브랜치·PR·리뷰)
```

### 📚 문서 안내

| 문서 | 내용 |
|------|------|
| [planning.md](planning.md) | 8단계 로드맵과 **현재 진행 상황 스냅샷** |
| [CONTRIBUTING.md](CONTRIBUTING.md) | 브랜치 전략·커밋·PR·리뷰 규칙 |
| [docs/ERD.md](docs/ERD.md) | DB 스키마와 설계 근거 |
| [docs/ENV_GUIDE.md](docs/ENV_GUIDE.md) | 환경 변수·시크릿 관리 |
| [docs/FIREBASE_AUTH_SETUP.md](docs/FIREBASE_AUTH_SETUP.md) | Firebase 콘솔 설정 체크리스트 |
| [docs/personality-test-design.md](docs/personality-test-design.md) | 여행 성향 축·설문·점수 모델 |
| [docs/PM_SETUP.md](docs/PM_SETUP.md) | 저장소 관리자 설정(PM 전용) |

---

## 🚀 시작하기

### 0) 저장소 클론 & 환경 변수

```bash
git clone https://github.com/FogMap2026/FogApp.git
cd FogApp

cp .env.example .env
# .env 를 열어 TOUR_API_SERVICE_KEY · NAVER_MAP_CLIENT_ID · DB_* 등 실제 값 입력
```

키 발급처와 관리 규칙은 [docs/ENV_GUIDE.md](docs/ENV_GUIDE.md)를 따르세요.

### 1) DB 실행 (PostgreSQL + PostGIS)

```bash
docker compose up -d
# 서버 기동 시 Flyway 가 V1~V3 마이그레이션을 자동 적용합니다.
```

### 2) 서버 실행

```bash
cd server

# ⚠️ Gradle wrapper(gradlew)는 저장소에 커밋돼 있지 않습니다.
#    최초 1회, 로컬에 설치된 Gradle로 wrapper를 생성해야 합니다.
gradle wrapper --gradle-version 8.8

./gradlew bootRun          # Windows: gradlew.bat bootRun

# 확인
curl http://localhost:8080/api/health
```

> 🔑 기본값은 `firebase.enabled=false` 입니다. 이 상태에서는 토큰 검증기가 **모든 토큰을 거부**하므로
> `/api/health` 외의 API는 401을 반환합니다. Firebase 서비스 계정 키를 받아 `firebase.enabled=true`로 켜야
> 인증이 동작합니다 — 발급 절차는 [docs/FIREBASE_AUTH_SETUP.md](docs/FIREBASE_AUTH_SETUP.md) 참고. (대기 중: [#2](../../issues/2))

### 3) 앱 실행

```bash
cd app
flutter pub get
flutter run
```

> ⚠️ **현재 깨끗한 클론에서는 앱이 실행되지 않습니다** ([#2](../../issues/2) 대기).
>
> | 필요한 것 | 상태 |
> |---|---|
> | `google-services.json` · `firebase_options.dart` | 미커밋 — 없으면 `Firebase.initializeApp()` 에서 크래시 |
> | Naver Maps 클라이언트 ID | 미설정 — 없으면 지도가 렌더링되지 않음 |
>
> [#2](../../issues/2)가 닫히면 클라이언트 설정 파일이 저장소에 들어와(정책은 [#42](../../pull/42)에서 확정) 이 제약이 사라집니다.

### 4) 테스트

```bash
cd server && ./gradlew test    # Testcontainers 로 PostGIS 컨테이너를 띄웁니다 (Docker 필요)
cd app    && flutter test
```

> 처음 클론했다면 위 2)의 `gradle wrapper` 단계를 먼저 거쳐야 `./gradlew` 가 생깁니다.
> 자세한 서버 설정은 [server/README.md](server/README.md) 참고.

> ⚠️ 관광공사 OpenAPI 서비스 키, Naver Maps 클라이언트 ID, **Firebase 서버 관리자 키(`serviceAccountKey.json`)** 는
> `.env`·`.gitignore`로 관리하고 **절대 커밋하지 마세요.** 자세한 구분은 [docs/ENV_GUIDE.md](docs/ENV_GUIDE.md) 참고.

---

## 🔌 구현된 API

> 인증: `/api/health`를 제외한 모든 `/api/**` 는 `Authorization: Bearer <Firebase ID Token>` 헤더가 필요합니다.

| 메서드 | 경로 | 설명 | Phase |
|--------|------|------|-------|
| `GET` | `/api/health` | 헬스체크 (공개) | 0 |
| `GET` | `/api/profile` | 내 프로필 조회 | 1 |
| `PATCH` | `/api/profile` | 닉네임·프로필 이미지 수정 | 1 |
| `PATCH` | `/api/profile/personality` | 성향 테스트 결과 저장 | 2 |
| `GET` | `/api/spots?region={code}&page&size` | 지역 코드별 스팟 목록(페이지네이션). `unlocked`·`overview`는 **로그인한 사용자 기준** | 1·3 |
| `GET` | `/api/spots/nearby?lat&lng&radius` | 반경 내 스팟 조회 (PostGIS `ST_DWithin`, 최대 20km) | 1·3 |
| `POST` `GET` `PATCH` `DELETE` | `/api/footprints`, `/api/footprints/{id}` | 발자취 CRUD (`spotId` 또는 `userId`로 목록 조회) | 1·2 |
| `POST` `DELETE` | `/api/footprints/{id}/likes` | 좋아요 등록·취소 (1인 1회) | 2 |
| `POST` `GET` `PATCH` `DELETE` | `/api/matches`, `/api/matches/{id}` | 동행 요청 생성·조회·상태 변경·취소 | 1·5 |
| `GET` | `/api/matches/candidates?userId&limit` | 성향 유사도 기반 동행 후보 추천 | 3 |
| `POST` | `/api/visits` | 방문 인증 (서버가 PostGIS로 반경 재검증, 1인 1스팟 1회) | 3 |
| `GET` | `/api/visits` | 내 인증 목록 — 앱이 걷힌 안개 영역을 복원할 때 사용 | 3 |
| `GET` | `/api/conquest` | 지역별 정복률 (**시/군/구 단위**) | 3 |

스팟 데이터는 `SpotCollectionRunner`(관광공사 OpenAPI 수집 배치)가 `spots.content_id` 업서트로 적재합니다.

---

## 📈 개발 현황 (2026-08-28)

**MVP가 동작합니다.** 스팟에 도달해 사진을 찍으면 안개가 걷히고, 스팟 정보가 해금되며, 지역 정복률이 올라갑니다.
발자취를 남기고 다른 사람의 기록에 좋아요를 누르는 것, 성향이 맞는 동행을 추천받아 요청·수락하는 것까지 됩니다.

| Phase | 상태 |
|-------|------|
| **0** 기반 다지기 | ✅ 완료 |
| **1** 인증 & 데이터 토대 | ✅ 완료 |
| **2** 지도 & 안개 코어 | ✅ 완료 |
| **3** 탐험 루프 ★MVP★ | ✅ **완료** |
| **4** 발자취 통합·완성 | ✅ **완료** |
| **5** 매칭 화면·완성 | ✅ **완료** |
| **6** 실시간 위치 공유 | ⬜ 미착수 |
| **7** 완성 & 출품 | 🔄 컨테이너화·영속 볼륨 ✅ / QA·발표 자료 남음 |

`dev`는 [PR #92](../../pull/92)로 `main`에 승격돼 두 브랜치가 같은 상태입니다.

> ⚠️ **실행 전 확인**: `spots` 테이블이 비어 있으면 지도에 마커가 없고 정복률이 `--%`로 나옵니다.
> 관광공사 OpenAPI 키를 넣고 **스팟 수집 배치를 한 번 돌려야 합니다** — 아래 참고.

### 스팟 수집 배치 돌리기 (최초 1회)

목록 수집과 소개글(`overview`) 채우기가 **한 번에 이어서** 돕니다([#100](../../issues/100)). 소개글은 스팟을 해금했을 때 보여주는 유일한 내용이라, 이걸 돌리지 않으면 정복해도 빈 화면이 열립니다.

```bash
# .env 에 키를 넣고 (⚠️ "일반 인증키(Decoding)" 를 쓸 것)
TOUR_API_SERVICE_KEY=...
TOUR_COLLECT_ON_STARTUP=true

docker compose up -d
docker compose logs -f server        # "소개글 수집: 대상 N, 채움 N" 이 보이면 완료
```

> 🚨 **끝나면 반드시 `TOUR_COLLECT_ON_STARTUP=false` 로 되돌리고 다시 띄우세요.**
>
> `server` 는 `restart: unless-stopped` 라, `true` 로 둔 채 컨테이너가 재시작되면 **목록 수집이 통째로 다시 돕니다**(지역 3 × 최대 10페이지 = 30회). 소개글 단계는 "이미 채워진 건 건너뛰기" 가 있지만 목록 단계에는 그런 가드가 없습니다.
>
> 관광공사 API 는 일일 호출 한도가 있어, 잊고 두면 **한도를 다 쓰고 그날 아무것도 못 하게 됩니다.**

소개글은 한 번에 최대 `TOUR_COLLECT_OVERVIEW_MAX_PER_RUN` 건(기본 200)만 채웁니다. 남은 것은 다음 실행이 이어서 채우므로, 스팟이 많으면 위 과정을 여러 번 반복하면 됩니다.

단계별 상세 항목·담당자·병합 순서는 [planning.md](planning.md)에 정리돼 있습니다.

---

## 🎯 서비스 발전 방향

- **GPS 영역 점유**: 점 방문을 넘어 이동 궤적을 면적 데이터로 변환, 안개 해제 시각 피드백 강화
- **희귀 지역 보너스**: 인구 감소 지역·오지 탐험 시 추가 경험치·특별 스킨 부여로 소도시 방문 유도
- **성향 맞춤 발자취 필터**: 나와 성향이 유사한 사용자의 기록만 골라 보기
- **실시간 조우 이벤트**: 근처 탐험가에게 응원·즉석 파티 결성 제안
- **로컬 스팟 퀘스트**: 로컬 카페·공방을 '보물상자 스팟'으로 지정, 리뷰 시 지역 화폐·쿠폰 지급

---

## 📊 기대효과

- **사용자**: 지도 정복의 게임적 재미 + 실제 동선이 담긴 신뢰도 높은 여행 정보
- **사회·경제**: 관광객 동선 분산, 소도시 재발견, 지역 경제 활성화
- **데이터 가치**: 성향별 선호 경로라는 고부가가치 데이터 수집 → 맞춤형 관광 상품·마케팅 활용

---

## 📄 라이선스

본 프로젝트는 오픈소스 개발자대회 2026 출품작입니다. (라이선스 확정 후 기재)

---

<div align="center">

**FogApp** — 안개 너머의 대한민국을 함께 밝혀나가는 여정 🌫️➡️🗺️

</div>
