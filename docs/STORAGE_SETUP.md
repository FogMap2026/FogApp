# 📸 인증 사진 Storage 설정 가이드 (#48)

> 담당: 송건희 [@songkh1201](https://github.com/songkh1201) (인프라)
> 관련 이슈: [#48 인증 사진 업로드 파이프라인 + 방문 인증 API](https://github.com/FogMap2026/FogApp/issues/48)
> 서버 API는 [PR #54](https://github.com/FogMap2026/FogApp/pull/54)로 완료 — 이 문서는 **사진 저장 계층(INF)** 을 다룬다.

---

## 1. 역할 분담 — 사진은 서버를 거치지 않는다

```
앱 ──① 사진 업로드──▶ Firebase Storage
 │                        │
 │                        └─▶ 다운로드 URL
 │
 └──② POST /api/visits { spotId, photoUrl, lat, lng } ──▶ 서버
                                                          └─▶ visits 행 생성
```

- **서버는 바이너리를 받지 않는다.** 앱이 Storage에 먼저 올리고 URL만 서버에 넘긴다(`visits.photo_url`).
- "누가 어디에 올릴 수 있는가"의 1차 방어선은 **Storage Security Rules**다.
- 위치 위조 방어는 서버가 담당한다(`POST /api/visits`의 PostGIS 반경 검증, #54).

> ⚠️ **Rules 단독으로는 부족하다.** 서버가 `photoUrl`을 아무 문자열이나 받으면,
> Rules로 업로드를 잠가도 `"https://evil.com/a.jpg"` 같은 URL로 인증이 성립해
> "사진으로 방문을 인증한다"는 성질이 깨진다.
> 그래서 서버도 `photoUrl`이 **본인 경로**를 가리키는지 검증한다(`VisitPhotoUrlValidator`).
> **경로 규칙이 세 곳에서 같아야 동작한다** — 아래 3장 표 참고.

---

## 2. 경로 규칙

```
visits/{firebaseUid}/{spotId}/{timestamp}.jpg
```

- `{firebaseUid}` — **Firebase UID**(서버 `users.id`가 아님). Storage는 서버 DB를 모르므로 소유권 판정을 UID로 한다.
- `{spotId}` — 서버 `spots.id`
- `{timestamp}` — 밀리초 epoch. 같은 스팟 재업로드 시 충돌 방지용이지만, 정복은 1인 1회(`visits` 유니크)라 실제로는 1장이 정상이다.

### ⚠️ 이 경로는 세 곳에서 동일해야 한다

한 곳만 어긋나도 업로드가 되거나 인증이 되거나 둘 중 하나가 조용히 실패한다.

| 위치 | 무엇 | 판정 근거 |
|------|------|-----------|
| 앱 | `VisitPhotoUploader` — 업로드 경로 생성 | `FirebaseAuth.currentUser.uid` |
| Storage | [`app/storage.rules`](../app/storage.rules) — 쓰기 허용 | `request.auth.uid` |
| 서버 | `VisitPhotoUrlValidator` — `photoUrl` 출처 검증 | `AuthUser.firebaseUid` |

> 셋 다 **Firebase UID** 를 쓴다. `storage.rules` 의 match 변수명이 `{userId}` 라
> 서버 `users.id` 로 오해하기 쉬운데, 실제로 대조하는 값은 `request.auth.uid` 다.
> (이 혼동으로 [#57](https://github.com/FogMap2026/FogApp/pull/57) 에 잘못된 수정 요청이 올라간 적이 있다)

---

## 3. Security Rules

규칙 파일: [`app/storage.rules`](../app/storage.rules) (`app/firebase.json`의 `storage.rules`로 연결됨)

| 동작 | 허용 조건 |
|------|-----------|
| **읽기** | 로그인한 사용자(발자취·정복 기록은 다른 탐험가도 봄) |
| **생성** | 본인 UID 경로 + `image/jpeg\|png\|webp` + **5MB 미만** |
| **수정·삭제** | ❌ 금지 — 인증 사진은 기록이라 사후 변조 불가 |
| 그 외 경로 | ❌ 전부 차단(fail-closed) |

### 배포 방법

```bash
cd app
firebase deploy --only storage
```

> Firebase CLI 로그인(`firebase login`)과 프로젝트 선택(`firebase use fogmap-9355b`)이 선행돼야 한다.

---

## 4. 콘솔에서 해야 할 일 (프로젝트 소유자)

Rules 파일은 저장소에 있지만, **버킷 생성은 콘솔 작업**이라 소유자가 직접 해야 한다.

- [ ] Firebase 콘솔 → **Storage → 시작하기** → 버킷 생성
  - 위치: `asia-northeast3`(서울) 권장 — 국내 사용자 지연 최소화
  - 시작 모드: **프로덕션 모드**(어차피 위 Rules로 덮어씀)
- [ ] 위 `firebase deploy --only storage`로 Rules 배포
- [ ] 콘솔 → Storage → Rules 탭에서 반영 확인

버킷: `fogmap-9355b.firebasestorage.app` (`app/lib/firebase_options.dart` 기준)

---

## 5. 앱 구현 시 주의 (UI 담당)

- **업로드 전 리사이즈·압축 필수.** 원본 그대로 올리면 5MB 제한에 걸리고 용량도 감당이 안 된다.
  `image_picker`의 `maxWidth`/`imageQuality`로 1차 축소가 가능하다(이미 `pubspec.yaml`에 있음).
- 업로드 성공 후 얻은 **다운로드 URL을 `POST /api/visits`의 `photoUrl`로** 넘긴다.
- 서버가 **422**(반경 밖) 또는 **409**(이미 인증한 스팟)를 돌려줄 수 있다 — 두 경우 모두 사용자에게 명확히 안내할 것.
  - ⚠️ 이때 이미 올라간 사진은 Storage에 남는다. 정리는 후속 과제(고아 파일 정리 배치)로 둔다.

---

## 6. 관련 문서

- [ENV_GUIDE.md](ENV_GUIDE.md) — 시크릿·설정 파일 커밋 정책
- [FIREBASE_AUTH_SETUP.md](FIREBASE_AUTH_SETUP.md) — Auth 설정(#2, 완료)
- [ERD.md](ERD.md) — `visits` 테이블 스키마
