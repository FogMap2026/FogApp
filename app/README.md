# 📱 FogApp — Mobile (Flutter)

안개 지도 탐험 앱의 Flutter 프로젝트입니다.

> ⛔ **`flutter create .` 를 실행하지 마세요.** `android/`·`ios/`·`web/` 는 **이미 커밋되어 있고**,
> 우리가 손댄 설정이 들어 있습니다. 다시 생성하면 아래가 덮어써집니다.
>
> | 파일 | 들어 있는 것 |
> |---|---|
> | `android/app/src/main/AndroidManifest.xml` | 위치 권한, 마이크 권한 제거([#189](../../pull/189)) |
> | `android/app/build.gradle.kts` | **릴리스 서명**([#163](../../pull/163)), `applicationId` |
>
> `applicationId` 가 기본값으로 되돌아가면 **지도·Firebase·키스토어가 한꺼번에 깨집니다** —
> 셋 다 `com.fogapp.fogapp` 에 묶여 있습니다.

## 처음 세팅

```bash
cd app
flutter pub get

flutter run \
  --dart-define=NAVER_MAP_CLIENT_ID=<인프라에게 요청> \
  --dart-define=API_BASE_URL=https://fogapp.taild500a1.ts.net
```

Flutter 버전은 CI 와 같은 **3.44.9** 를 쓰세요([ci.yml](../.github/workflows/ci.yml)).

### 두 값에 대해

| | |
|---|---|
| **`NAVER_MAP_CLIENT_ID`** | 🔴 **각자 발급받는 값이 아닙니다.** 인프라([@songkh1201](https://github.com/songkh1201))에게 **비공개 채널로** 요청하세요 |
| **`API_BASE_URL`** | 빼면 `http://10.0.2.2:8080`(에뮬레이터 로컬)로 붙어 **지도는 떠도 로그인이 안 됩니다** |

**Client ID 를 각자 발급받으면 안 되는 이유** — 이 값은 **등록된 패키지명에서 올 때만** 동작합니다.
우리 앱은 `com.fogapp.fogapp` 으로 등록돼 있어서, 같은 저장소를 빌드하는 한 **팀 전체가 같은 값을
씁니다.** 다른 값을 넣으면 `401 Unauthorized` 로 **지도가 회색**이 됩니다.

> ⛔ 이 값을 이슈·PR·커밋에 붙이지 마세요. APK 안에 어차피 들어가는 공개 식별자지만,
> **키를 저장소에 넣지 않는다는 선이 무너지면** 서비스 계정 키 같은 진짜 비밀도 따라 들어옵니다.

> 📌 Firebase 클라이언트 설정(`google-services.json`·`firebase_options.dart`)은 **커밋되어 있습니다**
> ([#42](../../pull/42) 정책). 따로 받을 것이 없습니다.
> Flutter 는 `.env` 를 읽지 않으므로 이 프로젝트는 **`--dart-define`** 으로만 주입합니다 —
> 루트 `.env` 의 `NAVER_MAP_CLIENT_ID` 줄은 목록 성격이고 실제로 쓰이지 않습니다.

### 앱만 써보고 싶다면

빌드 없이 **설치본**을 받으면 됩니다.

```
https://fogapp.taild500a1.ts.net/fogapp.apk
```

기존 앱이 깔려 있으면 **먼저 지우세요** — 릴리스 서명으로 바뀌어([#163](../../pull/163)) 덮어설치가 안 됩니다.

## 폴더 구조

```
lib/
├── main.dart        # 앱 진입점
├── screens/         # 화면 (지도, 발자취, 매칭, 프로필)
├── widgets/         # 재사용 위젯 (안개 오버레이, 발자취 카드)
├── services/        # API 통신, 위치, 인증
└── models/          # 데이터 모델
```

## 담당

Mobile Frontend — 송진오 [@oorony](https://github.com/oorony)
지도·위치·안개 — 김시진 [@sijin2170](https://github.com/sijin2170)

> Naver Maps 클라이언트 ID, Firebase 설정 파일은 커밋하지 마세요. [../docs/ENV_GUIDE.md](../docs/ENV_GUIDE.md) 참고.
