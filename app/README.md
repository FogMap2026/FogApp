# 📱 FogApp — Mobile (Flutter)

안개 지도 탐험 앱의 Flutter 프로젝트입니다.

> ⚠️ 이 폴더에는 **소스 뼈대(`lib/`, `pubspec.yaml`)만** 커밋되어 있습니다.
> `android/`, `ios/`, `web/` 등 **플랫폼 폴더는 Flutter SDK로 생성**해야 합니다.

## 처음 세팅

```bash
cd app

# 플랫폼 폴더(android/ios 등) 생성 — lib/ 와 pubspec.yaml 은 유지됩니다
flutter create .

# 의존성 설치
flutter pub get

# 실행
flutter run
```

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
