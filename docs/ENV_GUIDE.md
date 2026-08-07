# 🔐 환경 변수 & 시크릿 관리 가이드

FogApp은 여러 외부 서비스(관광공사 OpenAPI, Naver Maps, Firebase, DB) 키를 사용합니다.
**서버 시크릿(관리자 키·DB 비밀번호·API 서비스 키)은 절대 저장소에 커밋하지 않습니다.**
단, **Firebase 클라이언트 설정 파일은 시크릿이 아니므로 커밋합니다**(아래 3-2 참고).

---

## 1. 기본 원칙

- 시크릿은 **`.env` 파일**과 **로컬 설정 파일**로만 관리합니다.
- 저장소에는 값이 비어 있는 **`.env.example`** 만 커밋합니다.
- 새 환경 변수를 추가하면 `.env.example` 에도 **키만** 추가해 팀원에게 공유합니다.
- 실제 키 값은 팀 채팅(비공개)·비밀번호 관리자 등 안전한 채널로 공유합니다.

---

## 2. 처음 세팅하는 법

```bash
# 1) 예시 파일을 복사
cp .env.example .env

# 2) .env 를 열어 실제 값 입력 (팀에서 공유받은 값)
```

---

## 3. Firebase 파일 — 커밋 여부 구분

Firebase 관련 파일은 **성격이 다릅니다.** 클라이언트 설정은 앱에 배포되는 공개값이라 커밋하고, 서버 관리자 키만 커밋을 금지합니다.

### 3-1. 커밋하면 안 되는 파일 (`.gitignore` 에 등록됨)

| 파일 | 설명 |
|------|------|
| `.env`, `.env.*` | 환경 변수 실제 값 |
| `serviceAccountKey.json`, `firebase-adminsdk-*.json` | **Firebase Admin 서비스 계정 키** — 서버가 토큰 검증에 쓰는 관리자 권한 키. 유출 시 프로젝트 전체 위험 |
| `*.key`, `*.pem`, `*.keystore`, `*.jks` | 각종 키·인증서 |
| `secrets/` | 시크릿 모음 폴더 |

### 3-2. 커밋하는 Firebase 클라이언트 설정 (시크릿 아님)

| 파일 | 설명 |
|------|------|
| `google-services.json` | Firebase Android 설정 |
| `GoogleService-Info.plist` | Firebase iOS 설정 |
| `firebase_options.dart` | FlutterFire 생성 설정 |

> ℹ️ 이 파일들에 담긴 API 키는 앱 바이너리에 어차피 포함되어 배포되는 **공개 식별자**입니다. 실제 보안은 Firebase **Security Rules**와 API 키 제한으로 처리하므로, 소스에 커밋해도 안전합니다([Firebase 공식 문서](https://firebase.google.com/docs/projects/api-keys) 기준). 커밋해야 CI(`flutter analyze`)와 팀원 로컬 빌드가 파일 부재로 깨지지 않습니다.
>
> ⚠️ 단 `serviceAccountKey.json`(서버 관리자 키)과 혼동하지 마세요 — 그건 3-1의 금지 대상입니다.

> 🔐 Firebase 설정 발급 절차는 [FIREBASE_AUTH_SETUP.md](FIREBASE_AUTH_SETUP.md) 체크리스트를 따르세요.

---

## 4. 각 키 발급처

| 변수 | 발급처 |
|------|--------|
| `TOUR_API_SERVICE_KEY` | [한국관광공사 TourAPI](https://api.visitkorea.or.kr/) |
| `TOUR_COLLECT_*` | 발급 불필요 — 수집 배치 동작 설정([#5](https://github.com/FogMap2026/FogApp/issues/5)). 기본 `false`로 꺼져 있음 |
| `NAVER_MAP_CLIENT_ID` | [네이버 클라우드 플랫폼 — Maps](https://www.ncloud.com/product/applicationService/maps) |
| `FIREBASE_ENABLED` | 발급 불필요 — 서비스 계정 키를 받은 뒤 `true`로 켜는 스위치 |
| `FIREBASE_SERVICE_ACCOUNT_PATH` | [Firebase 콘솔](https://console.firebase.google.com/) — 발급 절차는 [FIREBASE_AUTH_SETUP.md](FIREBASE_AUTH_SETUP.md) 참고 |
| `DB_*` | 로컬은 `docker-compose.yml` 기본값, 배포는 인프라 담당(송건희)이 발급 |

> 💡 `JWT_SECRET` / `JWT_EXPIRATION_MS` 는 더 이상 쓰지 않습니다.
> 서버는 커스텀 JWT를 발급하지 않고 **Firebase ID 토큰을 그대로 검증**하는 방식([#4](https://github.com/FogMap2026/FogApp/issues/4))으로 확정되어,
> `.env.example`에서도 제거했습니다.

---

## 5. 실수로 커밋했다면?

1. 즉시 **해당 키를 무효화(재발급)** 하세요. 히스토리에서 지워도 이미 노출된 것으로 간주합니다.
2. 인프라 담당(송건희 [@songkh1201](https://github.com/songkh1201))과 PM(박근호 [@PGH0621](https://github.com/PGH0621))에게 알리세요.
3. `git rm --cached <파일>` 후 `.gitignore` 확인, 필요 시 히스토리 정리.

> 관련 규칙은 [CONTRIBUTING.md](../CONTRIBUTING.md) 8번 "자주 하는 실수" 참고.
