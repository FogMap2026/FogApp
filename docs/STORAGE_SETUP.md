# 📸 인증 사진 저장 가이드 (#48)

> 담당: 송건희 [@songkh1201](https://github.com/songkh1201) (인프라)
> 관련 이슈: [#48 인증 사진 업로드 파이프라인 + 방문 인증 API](https://github.com/FogMap2026/FogApp/issues/48)

---

## 1. 결정 — 사진만 서버가 보관한다

**Firebase Storage는 쓰지 않는다.** 무료(Spark) 요금제에서 버킷 생성 자체가 막히고, Blaze(종량제) 전환은 카드 등록이 필요해 팀에서 채택하지 않았다.

대신 **Firebase는 계속 쓴다.** 막힌 것은 Storage 하나뿐이다.

| Firebase 서비스 | 사용 여부 | 비고 |
|---|:---:|---|
| **Auth** (로그인) | ✅ 사용 | 무료. [#2](https://github.com/FogMap2026/FogApp/issues/2)·[#3](https://github.com/FogMap2026/FogApp/issues/3)·[#4](https://github.com/FogMap2026/FogApp/issues/4) 그대로 |
| **FCM** (푸시) | ✅ 사용 예정 | 무료. Phase 6 |
| **Storage** (파일) | ❌ 미사용 | Spark에서 버킷 생성 불가 → **서버가 대체** |

---

## 2. 업로드 흐름

```
① 사진 업로드
   앱 ──POST /api/visits/photo (multipart: spotId, file)──▶ 서버
                                                            └─▶ 디스크에 저장
   앱 ◀──── { "photoUrl": "/api/visits/photos/{uid}/{spotId}/{파일명}" } ────┘

② 방문 인증
   앱 ──POST /api/visits { spotId, photoUrl, lat, lng }──▶ 서버
                                                           └─▶ visits 행 생성

③ 사진 조회
   앱 ──GET /api/visits/photos/{uid}/{spotId}/{파일명}──▶ 서버가 파일 반환
```

> ⚠️ **①의 응답 `photoUrl`을 가공하지 말고 그대로 ②에 넘길 것.** 서버가 "본인 경로인지"를 다시 검증하므로, 값을 바꾸면 인증이 거부된다.

### 왜 상대 경로인가

`photoUrl`은 호스트 없는 상대 경로다. 절대 URL을 DB에 저장하면 로컬·배포에서 호스트가 달라질 때 이미 저장된 행이 전부 깨진다. 앱은 API base URL을 앞에 붙여 사용한다.

---

## 3. 보안 — Storage Rules가 하던 일을 서버가 한다

Firebase Storage였다면 Security Rules가 해 줬을 방어를 서버 코드가 대신한다.

| 방어 | 구현 | 위치 |
|------|------|------|
| **본인 경로에만 쓰기** | 저장 경로의 `{uid}`를 인증 토큰의 `AuthUser.firebaseUid`로만 만든다. 요청으로 받지 않는다 | `VisitPhotoStorage.store()` |
| **용량 제한** | 5MB 초과 거부 (`visit.max-photo-bytes`) | `VisitPhotoStorage.store()` |
| **형식 제한** | JPEG·PNG·WebP만. **매직 바이트로 판정** — 확장자·Content-Type 위장을 막는다 | `VisitPhotoStorage.sniff()` |
| **경로 이탈 차단** | 파일명은 서버가 생성. 경로 조각 검증 + 최종 경로가 루트 밖이면 거부 | `VisitPhotoStorage` |
| **남의 사진으로 인증 금지** | `photoUrl`이 본인 `{uid}/{spotId}` 경로인지 대조 | `VisitPhotoUrlValidator` |
| **위치 위조 차단** | 좌표가 실제 스팟 반경 안인지 PostGIS로 재확인 | `VisitService.verify()` |

> **왜 검증이 두 겹인가**: 업로드가 본인 경로를 강제해도, 인증 단계가 그 경로를 요구하지 않으면 아무 문자열이나 `photoUrl`로 넣어 인증이 성립한다. 두 검증이 짝을 이뤄야 "사진으로 방문을 인증한다"는 성질이 지켜진다.

---

## 4. 설정

`server/src/main/resources/application.yml`

```yaml
visit:
  photo-storage-path: ${VISIT_PHOTO_STORAGE_PATH:./data/visit-photos}
  max-photo-bytes: ${VISIT_MAX_PHOTO_BYTES:5242880}   # 5MB

spring:
  servlet:
    multipart:
      max-file-size: ${VISIT_MAX_PHOTO_BYTES:5242880}
      max-request-size: ${VISIT_MAX_REQUEST_SIZE:6291456}
```

> `max-photo-bytes`와 `multipart.max-file-size`는 **함께 움직여야 한다.** multipart 쪽이 더 작으면 서비스 검증에 닿기 전에 서블릿 컨테이너가 먼저 잘라내 오류 메시지가 달라진다.

### 로컬 실행

별도 준비가 없다. 서버를 띄우면 `server/data/visit-photos/`가 자동 생성된다(`.gitignore` 등록됨).

---

## 5. ⚠️ 배포 시 반드시 할 일 (Phase 7)

**저장 경로를 영속 볼륨에 마운트해야 한다.** 컨테이너가 재시작될 때 사라지면, 이미 인증된 방문의 사진이 통째로 유실되고 `visits.photo_url`은 깨진 링크만 남는다.

```yaml
# 예시 — 배포 구성 시
volumes:
  - fogapp_photos:/app/data/visit-photos
environment:
  VISIT_PHOTO_STORAGE_PATH: /app/data/visit-photos
```

백업 대상에도 DB와 함께 이 디렉터리를 포함할 것.

---

## 6. 앱 구현 시 주의 (UI 담당)

- **업로드 전 리사이즈·압축은 필수다.** 원본 그대로면 5MB 제한에 걸리고 서버 용량·대역폭도 감당이 안 된다. `image_picker`의 `maxWidth`/`imageQuality`로 1차 축소가 가능하다.
- `firebase_storage` SDK는 **더 이상 쓰지 않는다.** HTTP multipart 요청으로 대체한다. `pubspec.yaml`의 의존성도 정리 대상이다.
- 서버 응답 코드 처리:
  | 코드 | 의미 | 안내 |
  |---|---|---|
  | 201 | 업로드/인증 성공 | — |
  | 400 | 형식·용량 문제 | "JPEG·PNG·WebP 5MB 이하만 가능" |
  | 401 | 미인증 | 로그인 유도 |
  | 409 | 이미 인증한 스팟 | "이미 정복한 곳입니다" |
  | 422 | 스팟 반경 밖 | "조금 더 가까이 가주세요" |
- ⚠️ 인증(②)이 실패해도 업로드된 사진(①)은 서버에 남는다. 고아 파일 정리는 후속 과제로 둔다.

---

## 7. 관련 문서

- [ENV_GUIDE.md](ENV_GUIDE.md) — 시크릿·설정 파일 관리 정책
- [FIREBASE_AUTH_SETUP.md](FIREBASE_AUTH_SETUP.md) — 로그인 설정([#2](https://github.com/FogMap2026/FogApp/issues/2), 완료)
- [ERD.md](ERD.md) — `visits` 테이블 스키마
