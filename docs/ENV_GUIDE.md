# 🔐 환경 변수 & 시크릿 관리 가이드

FogApp은 여러 외부 서비스(관광공사 OpenAPI, Naver Maps, Firebase, DB) 키를 사용합니다.
**모든 키·비밀번호·설정 파일은 절대 저장소에 커밋하지 않습니다.**

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

## 3. 커밋하면 안 되는 파일 (`.gitignore` 에 등록됨)

| 파일 | 설명 |
|------|------|
| `.env`, `.env.*` | 환경 변수 실제 값 |
| `google-services.json` | Firebase Android 설정 |
| `GoogleService-Info.plist` | Firebase iOS 설정 |
| `firebase_options.dart` | FlutterFire 생성 설정 |
| `serviceAccountKey.json` | Firebase Admin 서비스 계정 |
| `*.key`, `*.pem`, `*.keystore`, `*.jks` | 각종 키·인증서 |
| `secrets/` | 시크릿 모음 폴더 |

---

## 4. 각 키 발급처

| 변수 | 발급처 |
|------|--------|
| `TOUR_API_SERVICE_KEY` | [한국관광공사 TourAPI](https://api.visitkorea.or.kr/) |
| `NAVER_MAP_CLIENT_ID` | [네이버 클라우드 플랫폼 — Maps](https://www.ncloud.com/product/applicationService/maps) |
| `FIREBASE_*` | [Firebase 콘솔](https://console.firebase.google.com/) |
| `DB_*` | 로컬은 `docker-compose.yml` 기본값, 배포는 인프라 담당(송건희)이 발급 |
| `JWT_SECRET` | 팀이 임의 생성(예: `openssl rand -base64 48`) |

---

## 5. 실수로 커밋했다면?

1. 즉시 **해당 키를 무효화(재발급)** 하세요. 히스토리에서 지워도 이미 노출된 것으로 간주합니다.
2. 인프라 담당(송건희 [@songkh1201](https://github.com/songkh1201))과 PM(박근호 [@PGH0621](https://github.com/PGH0621))에게 알리세요.
3. `git rm --cached <파일>` 후 `.gitignore` 확인, 필요 시 히스토리 정리.

> 관련 규칙은 [CONTRIBUTING.md](../CONTRIBUTING.md) 8번 "자주 하는 실수" 참고.
