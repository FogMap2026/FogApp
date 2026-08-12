# 🔐 Firebase Auth 설정 가이드 (#2)

> 담당: 송건희 [@songkh1201](https://github.com/songkh1201) (인프라)
> 관련 이슈: [#2 Firebase Auth 설정 & 소셜 로그인 Provider 구성](https://github.com/FogMap2026/FogApp/issues/2)

> **🚧 이 체크리스트가 현재 프로젝트의 유일한 미해결 Phase 0/1 블로커입니다 (2026-08-07 기준).**
>
> 아래 두 작업의 **코드는 이미 `dev`에 병합**되어 있고, 실제 동작 확인만 이 문서의 콘솔 작업을 기다리고 있습니다.
>
> | 대기 중인 작업 | 코드 상태 | 필요한 것 |
> |----------------|-----------|-----------|
> | [#3 로그인/온보딩 화면](https://github.com/FogMap2026/FogApp/issues/3) | ✅ 병합 ([PR #12](https://github.com/FogMap2026/FogApp/pull/12)) | 2장 — 앱 설정 파일(`firebase_options.dart` 등) |
> | [#4 JWT 검증 미들웨어](https://github.com/FogMap2026/FogApp/issues/4) | ✅ 병합 ([PR #20](https://github.com/FogMap2026/FogApp/pull/20)) | 3장 — 서버 서비스 계정 키 |
>
> 서버 기본값은 `firebase.enabled=false`(CI 포함)이며, 이때 `DisabledTokenVerifier`가 주입되어
> **모든 토큰을 거부**합니다. 즉 지금 서버를 띄우면 `/api/health`를 뺀 모든 API가 401을 돌려줍니다(fail-closed).
> 3장의 키를 받아 `firebase.enabled=true`로 켜야 인증이 실제로 동작합니다.

이 문서는 Firebase 콘솔에서 로그인 Provider를 활성화하고, 앱/서버가 필요로 하는
설정 파일·키를 발급해 안전하게 전달하기 위한 체크리스트입니다. **콘솔 조작은
Firebase 프로젝트 소유자/편집자 권한이 있는 사람이 직접 수행해야 합니다.**

---

## 1. Firebase 콘솔 — 로그인 Provider 활성화

1. [Firebase 콘솔](https://console.firebase.google.com/) → 해당 프로젝트 선택
2. **Authentication → Sign-in method** 이동
3. 아래 Provider를 활성화
   - **Google** (필수 — README 기준 소셜 로그인 기본)
   - 이메일/비밀번호는 `feat/ui-auth`(#3)에서 이미 폴백 구현되어 있으므로 함께 활성화
4. Google Provider 설정 시 **프로젝트 지원 이메일**을 지정해야 저장됨

## 2. 앱 설정 파일 발급 (Flutter — `flutterfire configure`)

> ✅ **Android는 완료**입니다 — `firebase_options.dart` · `android/app/google-services.json` 커밋됨.
> ⏸ **iOS `GoogleService-Info.plist`만 남았습니다.** 아래 2-1 참고.

1. Firebase 콘솔에서 Android/iOS 앱 등록 (패키지명/번들 ID는 `app/android`, `app/ios`
   스캐폴딩 확정 후 UI 담당(@oorony)과 함께 결정)
2. `flutterfire configure` 실행 → `firebase_options.dart`, `google-services.json`,
   `GoogleService-Info.plist` 생성
   - ✅ 이 파일들은 **커밋합니다** ([#42](https://github.com/FogMap2026/FogApp/pull/42)에서 정책 확정).
     담긴 API 키는 앱 바이너리에 실려 배포되는 공개 식별자라 시크릿이 아니며,
     커밋해야 CI(`flutter analyze`)와 팀원 로컬 빌드가 파일 부재로 깨지지 않습니다.
     자세한 근거는 [ENV_GUIDE.md](ENV_GUIDE.md) 3-2 참고.
   - ⛔ 3장의 `serviceAccountKey.json`(서버 관리자 키)과 혼동하지 마세요 — 그건 커밋 금지입니다.
   - 🔒 커밋으로 공유하는 대신 **콘솔에서 API 키 사용처를 제한**해야 합니다 (아래 4장 체크리스트).
3. `app/lib/main.dart`의 `Firebase.initializeApp()` 호출에 생성된 `options`를 연결
   (연결 작업은 @oorony에게 핸드오프)

### 2-1. iOS `GoogleService-Info.plist` — **Mac 없이 받을 수 있습니다**

Windows에서 `flutterfire configure`를 돌리면 iOS 설정 파일이 생성되지 않을 수 있는데,
**이건 Mac이 없어서가 아니라 CLI 동작의 문제입니다.** 파일 자체는 콘솔에서 웹으로 내려받습니다.

1. [Firebase 콘솔](https://console.firebase.google.com/) → 프로젝트 설정 → **내 앱 → iOS 앱 추가**
2. **번들 ID: `com.fogapp.fogapp`** (`app/ios/Runner.xcodeproj` 에 이미 설정돼 있음 — 반드시 일치시킬 것)
3. `GoogleService-Info.plist` 다운로드
4. **`app/ios/Runner/` 에 넣고 커밋** (클라이언트 설정이므로 커밋 대상 — 3-2 정책)

> 이 파일이 없어도 `firebase_options.dart` 에 iOS 설정이 들어 있어 빌드와 초기화는 됩니다.
> 다만 일부 네이티브 SDK가 이 파일을 직접 읽으므로, iOS를 실제로 돌리기 전에는 넣어야 합니다.

### 2-2. iOS 권한 문구 (`Info.plist`)

iOS는 권한 문구가 없으면 **해당 기능을 쓰는 순간 앱이 죽습니다. 그런데 빌드는 통과합니다** —
CI로 못 잡는 종류라 네이티브 기능을 추가할 때마다 직접 확인해야 합니다.

현재 `app/ios/Runner/Info.plist` 에 들어 있는 문구:

| 키 | 용도 |
|----|------|
| `NSLocationUsageDescription` · `NSLocationWhenInUseUsageDescription` | 지도 내 위치·근접 감지 |
| `NSCameraUsageDescription` | 방문 인증 사진 촬영 |
| `NSMotionUsageDescription` | 나침반(바라보는 방향) |

> 백그라운드 위치(Phase 6, 6-5)를 도입하면 `NSLocationAlwaysAndWhenInUseUsageDescription` 와
> 백그라운드 모드 설정이 추가로 필요합니다.

## 3. 서버 — 서비스 계정 키 발급 (ID 토큰 검증용)

`app`은 `Authorization: Bearer <Firebase ID Token>` 헤더로 서버에 요청을 보낸다
(`app/lib/services/api_client.dart` 참고). 서버(#4, JWT 검증 미들웨어)는 이 토큰을
Firebase Admin SDK로 검증해야 하므로 서비스 계정 키가 필요합니다.

1. Firebase 콘솔 → **프로젝트 설정 → 서비스 계정 → 새 비공개 키 생성**
2. 다운로드된 JSON은 `serviceAccountKey.json`으로 로컬에 저장 (커밋 금지, `.gitignore` 등록됨)
3. `.env`의 `FIREBASE_SERVICE_ACCOUNT_PATH`가 이 파일 경로를 가리키도록 설정
   (`.env.example` 참고)
4. `.env`에 `FIREBASE_ENABLED=true` 설정 — 기본값 `false` 상태에서는 검증기가 모든 토큰을 거부합니다.

> ✅ **검증 방식은 확정됐습니다** ([#4](https://github.com/FogMap2026/FogApp/issues/4), [PR #20](https://github.com/FogMap2026/FogApp/pull/20)).
> 커스텀 JWT를 발급하지 않고 **Firebase ID 토큰을 서버가 `verifyIdToken()`으로 직접 검증**합니다.
> (`FirebaseTokenVerifier` · `FirebaseAuthFilter`) 그래서 `JWT_SECRET` 류 환경 변수는 쓰지 않습니다.

## 4. 콘솔 보안 설정 (커밋 정책 전제 조건)

클라이언트 설정 파일을 커밋하기로 한 이상([#42](https://github.com/FogMap2026/FogApp/pull/42)), **실제 보안은 아래 두 가지가 담당합니다.**
이게 안 걸려 있으면 공개된 API 키가 그대로 남용될 수 있으므로, 커밋 전에 함께 설정해 주세요.

- [ ] **API 키 사용처 제한** — Google Cloud 콘솔 → 사용자 인증 정보 → 해당 API 키
      → Android 패키지명 + SHA-1 / iOS 번들 ID 로 제한
- [ ] **Firestore · Storage Security Rules 설정** — 기본 테스트 모드(전체 공개)로 두지 않기

## 5. 공유 체크리스트

- [ ] Google 로그인 Provider 활성화 (+ 이메일/비밀번호)
- [ ] `flutterfire configure`로 앱 설정 파일 발급 → **커밋해서 공유** (비공개 전달 불필요)
- [ ] 위 4장의 API 키 제한 · Security Rules 설정
- [ ] 서비스 계정 키 발급 → @PGH0621에게 **비공개 채널로 전달**, 로컬 `.env` 갱신 (⛔ 커밋 금지)
- [ ] `app/lib/main.dart`의 `Firebase.initializeApp()`에 `options` 연결 (@oorony)
- [ ] 위 항목 완료 후 이슈 [#2](https://github.com/FogMap2026/FogApp/issues/2) 종료, [#3](https://github.com/FogMap2026/FogApp/issues/3)/[#4](https://github.com/FogMap2026/FogApp/issues/4) 블로킹 해제

## 6. 주의사항

- 이 문서의 어떤 값도 실제 키·ID를 담지 않습니다.
- **서버 관리자 키**(`serviceAccountKey.json`)와 DB 비밀번호는 절대 저장소에 커밋하지 마세요.
  클라이언트 설정 파일과의 구분은 [ENV_GUIDE.md](ENV_GUIDE.md) 3장을 따릅니다.
- 콘솔 작업 완료 후 [ENV_GUIDE.md](ENV_GUIDE.md)에 새로 생긴 환경 변수가 있다면 반영합니다.
