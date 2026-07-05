# 🔐 Firebase Auth 설정 가이드 (#2)

> 담당: 송건희 [@songkh1201](https://github.com/songkh1201) (인프라)
> 관련 이슈: [#2 Firebase Auth 설정 & 소셜 로그인 Provider 구성](https://github.com/FogMap2026/FogApp/issues/2)
> 블로킹 대상: [#3 로그인/온보딩 화면](https://github.com/FogMap2026/FogApp/issues/3) (완료, 이 설정 대기 중), [#4 JWT 검증 미들웨어](https://github.com/FogMap2026/FogApp/issues/4)

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

앱은 아직 `firebase_options.dart`가 없는 상태이며(`app/lib/main.dart`의 TODO 참고),
이 항목이 완료되어야 연결할 수 있습니다.

1. Firebase 콘솔에서 Android/iOS 앱 등록 (패키지명/번들 ID는 `app/android`, `app/ios`
   스캐폴딩 확정 후 UI 담당(@oorony)과 함께 결정)
2. `flutterfire configure` 실행 → `firebase_options.dart`, `google-services.json`,
   `GoogleService-Info.plist` 생성
   - 이 파일들은 **커밋 금지** (`.gitignore`에 이미 등록됨)
   - 팀 공유는 비공개 채널(팀 채팅 또는 비밀번호 관리자)로만 진행
3. `app/lib/main.dart`의 `Firebase.initializeApp()` 호출에 생성된 `options`를 연결
   (연결 작업은 @oorony에게 핸드오프)

## 3. 서버 — 서비스 계정 키 발급 (ID 토큰 검증용)

`app`은 `Authorization: Bearer <Firebase ID Token>` 헤더로 서버에 요청을 보낸다
(`app/lib/services/api_client.dart` 참고). 서버(#4, JWT 검증 미들웨어)는 이 토큰을
Firebase Admin SDK로 검증해야 하므로 서비스 계정 키가 필요합니다.

1. Firebase 콘솔 → **프로젝트 설정 → 서비스 계정 → 새 비공개 키 생성**
2. 다운로드된 JSON은 `serviceAccountKey.json`으로 로컬에 저장 (커밋 금지, `.gitignore` 등록됨)
3. `.env`의 `FIREBASE_SERVICE_ACCOUNT_PATH`가 이 파일 경로를 가리키도록 설정
   (`.env.example` 참고)
4. 검증 방식 권장: 서버에 Firebase Admin SDK를 추가해 `verifyIdToken()`으로 검증 후
   커스텀 JWT 발급 또는 ID 토큰을 그대로 세션 식별자로 사용 — 최종 방식은
   JWT 미들웨어 담당(@PGH0621, #4)과 협의해서 결정

## 4. 공유 체크리스트

- [ ] Google 로그인 Provider 활성화 (+ 이메일/비밀번호)
- [ ] `flutterfire configure`로 앱 설정 파일 발급 → @oorony에게 비공개 채널로 전달
- [ ] 서비스 계정 키 발급 → @PGH0621에게 비공개 채널로 전달, 로컬 `.env` 갱신
- [ ] 위 두 핸드오프 완료 후 이슈 #2 종료, #3/#4 블로킹 해제

## 5. 주의사항

- 이 문서의 어떤 값도 실제 키·ID를 담지 않습니다. 실제 값은 절대 저장소에 커밋하지 마세요.
- 콘솔 작업 완료 후 [ENV_GUIDE.md](ENV_GUIDE.md)에 새로 생긴 환경 변수가 있다면 반영합니다.
