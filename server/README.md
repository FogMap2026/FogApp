# 🖥️ FogApp — Server (Spring Boot)

REST API 서버. 관광공사 OpenAPI 연동, PostGIS 기반 지리공간 쿼리를 담당합니다.

> ⚠️ Gradle **wrapper(`gradlew`, `gradle/wrapper/`)는 커밋되어 있지 않습니다.**
> 로컬에 Gradle이 설치돼 있다면 아래처럼 wrapper를 생성한 뒤 사용하세요.

## 실행 방법 두 가지

### A. 컨테이너로 통째로 (Java·Gradle 설치 불필요)

저장소 루트에서:

```bash
docker compose up -d
```

DB가 healthcheck를 통과한 뒤 서버가 뜹니다. 인증 사진은 `fogapp_photos` 볼륨에 보관돼 재시작해도 남습니다(#76).

> ⚠️ `docker compose down -v` 는 볼륨까지 지웁니다 — **인증된 방문의 사진이 함께 사라집니다.** 평소에는 `-v` 없이 쓰세요.

### B. DB만 컨테이너, 서버는 IDE/로컬에서

코드를 고쳐가며 개발할 때 씁니다.

```bash
# 저장소 루트에서 DB만
docker compose up -d db

cd server

# (최초 1회) Gradle wrapper 생성 — 로컬 gradle 필요
gradle wrapper --gradle-version 8.8

./gradlew bootRun
```

## 헬스체크

```bash
curl http://localhost:8080/api/health
# {"status":"UP","service":"fogapp-server"}
```

## 컨테이너 이미지

[`Dockerfile`](Dockerfile) — 멀티스테이지(Gradle 8.8+JDK17 빌드 → JRE 17 실행).

- **이미지 빌드 중에는 테스트를 돌리지 않습니다.** 통합 테스트가 Testcontainers(=Docker)를 요구해 이미지 안에서 실행할 수 없습니다. CI의 `Spring Boot Server` 잡이 맡습니다.
- **non-root(`fogapp`, uid 10001)로 실행**합니다. 사진 업로드 경로에 문제가 생기더라도 피해 범위를 좁힙니다.
- ⛔ **시크릿은 이미지에 굽지 않습니다.** Firebase 서비스 계정 키는 실행 시 `./secrets` 를 읽기 전용으로 마운트해 주입합니다. 이미지 레이어는 지워도 남습니다.

## 환경 변수

DB 접속·API 키는 `application.yml` 이 환경 변수에서 읽습니다.
저장소 루트의 [.env.example](../.env.example) / [docs/ENV_GUIDE.md](../docs/ENV_GUIDE.md) 참고.

컨테이너로 띄울 때 반드시 짝이 맞아야 하는 값:

| 환경 변수 | 값 | 왜 |
|---|---|---|
| `DB_HOST` | `db` | 컨테이너 간 통신은 서비스 이름으로. `localhost` 는 자기 자신이다 |
| `VISIT_PHOTO_STORAGE_PATH` | `/app/data/visit-photos` | **`fogapp_photos` 볼륨 마운트 지점과 같아야 한다.** 어긋나면 사진이 볼륨 밖에 쌓여 재시작 때 사라진다 |
| `FIREBASE_SERVICE_ACCOUNT_PATH` | `/app/secrets/serviceAccountKey.json` | `./secrets` 마운트 안의 경로 |

## 담당

PM & Backend — 박근호 [@PGH0621](https://github.com/PGH0621)
