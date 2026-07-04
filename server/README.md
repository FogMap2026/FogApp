# 🖥️ FogApp — Server (Spring Boot)

REST API 서버. 관광공사 OpenAPI 연동, PostGIS 기반 지리공간 쿼리를 담당합니다.

> ⚠️ Gradle **wrapper(`gradlew`, `gradle/wrapper/`)는 커밋되어 있지 않습니다.**
> 로컬에 Gradle이 설치돼 있다면 아래처럼 wrapper를 생성한 뒤 사용하세요.

## 처음 세팅

```bash
cd server

# (최초 1회) Gradle wrapper 생성 — 로컬 gradle 필요
gradle wrapper --gradle-version 8.8

# DB 먼저 실행 (저장소 루트에서)
#   docker compose up -d

# 서버 실행
./gradlew bootRun
```

## 헬스체크

```bash
curl http://localhost:8080/api/health
# {"status":"UP","service":"fogapp-server"}
```

## 폴더 구조

```
src/main/java/com/fogapp/
├── FogAppApplication.java     # 진입점
└── controller/
    └── HealthController.java  # /api/health
src/main/resources/
└── application.yml            # 설정 (DB·API 키는 환경 변수 주입)
```

## 환경 변수

DB 접속·API 키는 `application.yml` 이 환경 변수에서 읽습니다.
저장소 루트의 [.env.example](../.env.example) / [docs/ENV_GUIDE.md](../docs/ENV_GUIDE.md) 참고.

## 담당

PM & Backend — 박근호 [@PGH0621](https://github.com/PGH0621)
