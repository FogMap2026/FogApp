# FogApp 서버 이미지 (#86 — Phase 7-3)
#
# 빌드:  docker build -t fogapp-server ./server
# 실행:  docker compose up -d          (루트의 docker-compose.yml 이 이 파일을 쓴다)
#
# ⚠️ 이미지에는 시크릿을 굽지 않는다. Firebase 서비스 계정 키·DB 비밀번호는
#    실행 시 볼륨/환경 변수로 주입한다. 이미지 레이어는 지워도 남는다.

# ── 빌드 ────────────────────────────────────────────────────────────
# Gradle wrapper(gradlew)가 저장소에 없어(server/README.md 참고) CI 와 같이
# gradle 이미지를 쓴다. Spring Boot 3.3.x 는 Gradle 8.x 를 요구한다 — 9.x 는 호환 불가.
FROM gradle:8.8-jdk17 AS build

WORKDIR /build

# 빌드 스크립트를 먼저 복사해 의존성 해석을 별도 레이어로 만든다.
# 소스만 바뀌었을 때 의존성을 다시 받지 않는다.
COPY settings.gradle build.gradle ./
RUN gradle --no-daemon dependencies --quiet || true

COPY src ./src

# 테스트는 여기서 돌리지 않는다 — 통합 테스트가 Testcontainers(Docker)를 요구해
# 이미지 빌드 안에서는 실행할 수 없다. CI 의 "Spring Boot Server" 잡이 맡는다.
RUN gradle --no-daemon bootJar -x test

# ── 실행 ────────────────────────────────────────────────────────────
FROM eclipse-temurin:17-jre

# 헬스체크에 필요. JRE 이미지에는 curl 이 없다.
RUN apt-get update \
    && apt-get install --no-install-recommends -y curl \
    && rm -rf /var/lib/apt/lists/*

# root 로 돌리지 않는다. 인증 사진 업로드 취약점이 생기더라도 피해 범위를 좁힌다.
RUN useradd --system --create-home --uid 10001 fogapp

WORKDIR /app

COPY --from=build /build/build/libs/*.jar app.jar

# 인증 사진 저장 위치(#48, #76). 컨테이너 안의 이 경로를 영속 볼륨에 마운트해야 한다 —
# 안 하면 재시작할 때마다 인증 사진이 전부 사라지고 visits.photo_url 은 깨진 링크만 남는다.
# 미리 만들어 두는 이유: 볼륨 없이 띄웠을 때도 소유자가 fogapp 이어야 쓸 수 있다.
RUN mkdir -p /app/data/visit-photos && chown -R fogapp:fogapp /app/data
ENV VISIT_PHOTO_STORAGE_PATH=/app/data/visit-photos

USER fogapp

EXPOSE 8080

# 컨테이너 오케스트레이터가 "떴다"와 "받을 수 있다"를 구분하게 한다.
# 기동 직후에는 Flyway 마이그레이션이 도는 중이라 아직 요청을 못 받는다.
HEALTHCHECK --interval=15s --timeout=3s --start-period=60s --retries=5 \
    CMD curl -fsS http://localhost:8080/api/health || exit 1

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
