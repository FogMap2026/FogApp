# 🤝 FogApp 협업 매뉴얼 (CONTRIBUTING)

> 5인 팀이 Issues와 Pull Requests로 협업하기 위한 규칙을 정리한 문서입니다.
> **작업을 시작하기 전에 이 문서를 먼저 읽어주세요.**

---

## 목차

1. [전체 개발 흐름 한눈에 보기](#1-전체-개발-흐름-한눈에-보기)
2. [브랜치 전략](#2-브랜치-전략)
3. [이슈(Issue) 사용법](#3-이슈issue-사용법)
4. [커밋 규칙](#4-커밋-규칙)
5. [Pull Request(PR) 규칙](#5-pull-requestpr-규칙)
6. [코드 리뷰 규칙](#6-코드-리뷰-규칙)
7. [담당자별 작업 영역](#7-담당자별-작업-영역)
8. [자주 하는 실수 & 주의사항](#8-자주-하는-실수--주의사항)

---

## 1. 전체 개발 흐름 한눈에 보기

작업 하나가 시작해서 배포까지 가는 전체 과정입니다.

```
① 이슈 생성          "무엇을 할지" 정의 (기능/버그)
      ↓
② 작업 브랜치 생성    feat/xxx  또는  fix/xxx  (dev에서 분기)
      ↓
③ 코드 작성 + 커밋    작은 단위로 자주 커밋
      ↓
④ PR 생성 → dev      작업 브랜치를 dev로 병합 요청
      ↓
⑤ 코드 리뷰          팀원 1명 이상 승인(Approve)
      ↓
⑥ dev 병합 + 검증    dev에서 실제로 돌려보고 문제 없는지 확인
      ↓
⑦ PR 생성 → main     검증 끝난 dev를 main으로 병합 요청
      ↓
⑧ main 병합 (배포)   안정 버전 완성 ✅
```

**핵심 원칙**: 코드는 항상 `작업 브랜치 → dev(검증) → main(안정)` 순서로만 올라갑니다.
작업 브랜치나 개인 코드를 **main에 직접 push하지 않습니다.**

---

## 2. 브랜치 전략

### 브랜치 종류

| 브랜치 | 용도 | 병합 방향 | 설명 |
|--------|------|-----------|------|
| `main` | **배포/제출용 안정 버전** | — | 항상 정상 동작하는 코드만. 직접 작업 ❌ |
| `dev` | **통합 테스트** | `dev → main` | 각자 작업을 모아서 함께 돌려보는 곳 |
| `feat/*` | **새 기능 개발** | `feat/* → dev` | 기능 하나당 브랜치 하나 |
| `fix/*` | **버그 수정** | `fix/* → dev` | 버그 하나당 브랜치 하나 |
| `hotfix/*` | **긴급 수정** | `hotfix/* → main` | main에 급한 버그가 있을 때만 예외적으로 |

### 브랜치 이름 규칙

```
<타입>/<영역>-<간단한-설명>
```

- 타입: `feat`(기능) / `fix`(버그) / `hotfix`(긴급) / `docs`(문서) / `chore`(설정·잡무)
- 영역: 담당 영역을 나타내는 키워드 (아래 표)
- 설명: 영어 소문자 + 하이픈(`-`)

| 영역 키워드 | 담당 파트 |
|-------------|-----------|
| `map` | 지도 · 위치 · 안개 |
| `social` | 매칭 · 소셜 · 발자취 |
| `api` / `server` | 백엔드 · API |
| `ui` / `app` | 모바일 프론트엔드 |
| `infra` / `data` | 인프라 · 사진 · 알림 |

**예시**

```
feat/map-fog-overlay       # 안개 오버레이 기능
feat/social-matching       # 성향 매칭 기능
feat/api-tour-openapi      # 관광공사 OpenAPI 연동
fix/auth-token-expire      # 로그인 토큰 만료 버그
docs/readme-update         # README 수정
```

### 작업 시작 명령어

```bash
# 항상 최신 dev에서 시작
git checkout dev
git pull origin dev

# 새 작업 브랜치 생성
git checkout -b feat/map-fog-overlay

# 작업 후 push
git push origin feat/map-fog-overlay
```

---

## 3. 이슈(Issue) 사용법

**모든 작업은 이슈에서 시작합니다.** 코드를 짜기 전에 "무엇을, 왜 하는지"를 이슈로 먼저 남겨주세요.

### 이슈를 만드는 경우

- 새 기능을 개발할 때
- 버그를 발견했을 때
- 논의가 필요한 사항이 있을 때

### 이슈 작성 형식

**제목**: `[타입] 간단한 요약`
예) `[Feat] 안개 오버레이 렌더링 구현`, `[Bug] 스팟 인증 시 사진 업로드 실패`

**본문 템플릿**

```markdown
## 📌 무엇을 (What)
안개 지도 위에 회색 오버레이를 그리고, 스팟 도달 시 걷히도록 구현

## 🎯 왜 (Why)
탐험 기능의 핵심 시각 요소. 이게 있어야 인증 로직과 연결 가능

## ✅ 할 일 (To-do)
- [ ] 안개 오버레이 레이어 렌더링
- [ ] 스팟 좌표 기준 반경 원형 클리어
- [ ] 정복률(%) 계산 연동

## 🔗 참고
관련 이슈 / 문서 링크
```

### 라벨(Label) 사용

이슈·PR에 라벨을 붙여 분류합니다. 아래 라벨을 미리 만들어두세요.

| 라벨 | 색상 | 용도 |
|------|------|------|
| `feature` | 🟢 초록 | 새 기능 |
| `bug` | 🔴 빨강 | 버그 |
| `docs` | 🔵 파랑 | 문서 |
| `enhancement` | 🟡 노랑 | 개선 |
| `help wanted` | 🟣 보라 | 도움 필요 |
| `map` / `social` / `api` / `ui` / `infra` | ⚪ 영역별 | 담당 파트 구분 |

### 담당자(Assignee) 지정

이슈를 만들면 **담당자를 지정**하세요. 보통 해당 영역 오너가 담당합니다.

---

## 4. 커밋 규칙

### 커밋 메시지 형식

```
<타입>: <한 줄 요약> (#이슈번호)
```

| 타입 | 의미 |
|------|------|
| `feat` | 새 기능 |
| `fix` | 버그 수정 |
| `docs` | 문서 |
| `style` | 코드 포맷팅 (기능 변화 없음) |
| `refactor` | 리팩터링 |
| `test` | 테스트 코드 |
| `chore` | 빌드·설정·잡무 |

**예시**

```
feat: 안개 오버레이 렌더링 추가 (#12)
fix: 인증 사진 업로드 타임아웃 수정 (#20)
docs: README 기술 스택 표 업데이트 (#5)
```

### 커밋 팁

- **작은 단위로 자주** 커밋하세요. 한 커밋에 하나의 논리적 변경.
- 커밋 메시지는 **한글/영어 무관**, 팀 내에서 통일만 하면 됩니다.
- `#이슈번호`를 붙이면 이슈와 자동 연결됩니다.

---

## 5. Pull Request(PR) 규칙

### PR 생성 시점

- 작업 브랜치의 기능이 **동작 가능한 상태**가 되면 `dev`로 PR을 올립니다.
- 완벽하지 않아도 리뷰가 필요하면 **Draft PR**로 먼저 올려도 됩니다.

### PR 제목

```
[타입] 요약 (#이슈번호)
```
예) `[Feat] 안개 오버레이 렌더링 구현 (#12)`

### PR 본문 템플릿

```markdown
## 🔗 관련 이슈
Closes #12

## ✨ 작업 내용
- 안개 오버레이 레이어 추가
- 스팟 반경 도달 시 안개 클리어 로직 구현

## 🧪 테스트 방법
1. 앱 실행 → 지도 화면 진입
2. 임의 좌표로 스팟 근접 → 안개 걷히는지 확인

## 📸 스크린샷 (UI 변경 시)
(이미지 첨부)

## ✅ 체크리스트
- [ ] 로컬에서 정상 동작 확인
- [ ] 관련 이슈 연결 (`Closes #번호`)
- [ ] 리뷰어 지정
```

### PR 병합 규칙

| 방향 | 조건 |
|------|------|
| `feat/* → dev` | **리뷰어 1명 이상 Approve** 후 병합 |
| `dev → main` | **dev에서 통합 테스트 통과** + 리뷰어 승인 후 병합 |

- `feat/* → dev` 는 **Squash and merge** 권장 (커밋 히스토리가 깔끔해집니다).
- ⚠️ 단 `dev → main` 과 **아래 "스택 PR" 은 예외**로 반드시 merge commit 을 씁니다.
- 병합 후 작업 브랜치는 **삭제**합니다 (GitHub에서 "Delete branch" 버튼).

### ⚠️ 스택(Stacked) PR 병합 — squash 금지

PR의 base가 `dev`·`main`이 아니라 **다른 feature 브랜치**인 경우를 스택 PR이라고 합니다.
앞 작업이 끝나기 전에 이어서 작업할 때 자연스럽게 생깁니다.

```
dev ← feat/map-base ← feat/ui-map-screen ← feat/map-spot-load
      (PR #34)         (PR #35)             (PR #40)
```

**이때 squash로 병합하면 위쪽 PR이 전부 충돌합니다.**

```
feat/map-base :  A ─ B ─ C        ← feat/ui-map-screen 이 이 커밋들 위에 쌓여 있음
                       │
      squash 병합 ─────┴──► dev :  [ABC]   ← 하나의 새 커밋으로 압축

→ dev 의 [ABC] 와 feat/ui-map-screen 의 A·B·C 는 내용은 같지만 커밋 ID가 다르다
→ git 이 공통 조상을 못 찾고 "양쪽이 각각 수정했다"고 판단 → 충돌
```

**내용이 충돌한 게 아니라 이력이 끊긴 것**이라, 코드를 아무리 읽어봐도 원인이 안 보입니다.

#### 규칙

| 상황 | 소스 브랜치가 병합 후에도 살아 있는가 | 병합 방식 |
|------|--------------------------------------|-----------|
| `feat/* → dev` | ❌ 병합 후 삭제 | **Squash and merge** |
| **`dev → main`** (릴리스 승격) | ✅ `dev` 는 계속 쓴다 | 🚨 **Create a merge commit** |
| **스택 PR** (base가 다른 feature 브랜치) | ✅ 위에 PR이 매달려 있다 | 🚨 **Create a merge commit** |
| **이력 편입 목적 병합** (`main → dev` 등) | ✅ | 🚨 **Create a merge commit** |

> ### 판단 기준: **squash 는 소스 브랜치를 버릴 때만.**
>
> 병합 후에도 그 브랜치를 계속 쓴다면 squash 가 조상 관계를 끊고, **다음 병합에서 반드시 충돌**합니다.
> base 가 무엇이냐가 아니라 **소스 브랜치의 수명**으로 판단하세요.

#### 스택 PR 도 CI 가 돕니다

CI 는 base 가 무엇이든 모든 PR 에서 실행됩니다. 예전에는 `pull_request` 트리거에 `branches: [main, dev]` 필터가 있어 **스택 PR 에서 CI 가 아예 안 돌았습니다** — 체크 목록이 비어 있어 "통과"로 오해하기 쉬웠지만 실은 실행조차 안 된 상태였습니다.

> 체크 목록이 **비어 있는 것**과 **초록인 것**은 다릅니다. 비어 있으면 아무것도 검증되지 않은 것입니다.

#### 왜 `dev → main` 이 특히 위험한가

`dev` 는 릴리스 후에도 계속 살아 있는 장수 브랜치라, 여기서 squash 하면 **매 릴리스마다** 같은 충돌이 반복됩니다.

```
squash 병합 시:
  main :  ... ← [dev 24커밋을 압축한 새 커밋]
  dev  :  ... 원본 24커밋 그대로 살아 있음

  → main 의 그 커밋은 dev 에 없고, dev 의 24커밋은 main 에 없다
  → 다음 릴리스에서 이미 올린 커밋이 "새 변경"으로 다시 나타난다
  → 양쪽이 건드린 파일마다 충돌
```

`feat/*` 는 병합 후 삭제하니 이 문제가 없습니다. 차이는 **브랜치를 계속 쓰느냐** 하나뿐입니다.

#### 이미 충돌이 났다면

위쪽 브랜치가 아래쪽 내용을 이미 포함하고 있으므로, **자기 브랜치 버전을 채택**하면 됩니다.

```bash
git checkout feat/내-브랜치
git fetch origin
git merge origin/dev              # 또는 base 브랜치

git checkout --ours <충돌파일>    # 대개 내 브랜치가 상위집합
git add <충돌파일>

# ✅ 커밋 전 필수 확인 — base 쪽 내용이 사라지지 않았는가?
git diff --cached origin/dev --diff-filter=D --name-only   # 출력이 없어야 정상

git commit
git push
```

`--ours`를 쓰기 전에 **충돌 구간을 눈으로 확인**하고, 위 `--diff-filter=D` 검사를 꼭 돌리세요.
내 브랜치가 상위집합이 아닌 경우(양쪽이 서로 다른 기능을 같은 파일에 넣은 경우)에는 손으로 합쳐야 합니다.

#### 애초에 스택을 안 만들려면

가능하면 **각 PR의 base를 `dev`로** 두세요. 앞 작업 결과가 필요하면 그때그때 `git merge origin/dev`로 따라가면 됩니다.
스택은 리뷰 단위를 작게 쪼개주는 장점이 있지만, 병합 방식을 한 번만 틀려도 위쪽 전부가 막힙니다.

---

## 6. 코드 리뷰 규칙

### 리뷰어 입장

- PR이 올라오면 **24시간 이내 확인**을 목표로 합니다.
- 무조건 승인하지 말고, 코드를 실제로 읽고 **최소 1가지는 피드백**하려 노력하세요.
- 리뷰 코멘트는 **정중하게**. 사람이 아니라 코드에 대해 이야기합니다.

### 작성자 입장

- 리뷰 코멘트에는 반드시 답하거나 반영합니다.
- 반영 후에는 리뷰어에게 다시 확인 요청(Re-request review).

### 승인 기준

- ✅ 코드가 이슈의 요구사항을 만족하는가
- ✅ 다른 파트의 코드를 깨뜨리지 않는가
- ✅ 민감 정보(API 키, `.env`)가 커밋에 포함되지 않았는가

---

## 7. 담당자별 작업 영역

각자 자기 영역의 오너입니다. 다른 영역을 수정해야 하면 **해당 오너에게 먼저 알리고** PR 리뷰어로 지정하세요.

| 영역 | 담당자 | 브랜치 접두어 | GitHub |
|------|--------|---------------|--------|
| PM & Backend — 서버·API | 박근호 | `feat/api-*` | [@PGH0621](https://github.com/PGH0621) |
| Mobile Frontend — 앱 UI/UX | 송진오 | `feat/ui-*` | [@oorony](https://github.com/oorony) |
| Map & Location — 지도·위치·안개 | 김시진 | `feat/map-*` | [@sijin2170](https://github.com/sijin2170) |
| Social & Matching — 매칭·소셜·발자취 | 김규현 | `feat/social-*` | [@k2hop1213](https://github.com/k2hop1213) |
| DevOps & Data — 인프라·사진·알림 | 송건희 | `feat/infra-*` | [@songkh1201](https://github.com/songkh1201) |

> PM(박근호)이 `main`·`dev` 브랜치 병합의 최종 관리자 역할을 겸합니다.

---

## 8. 자주 하는 실수 & 주의사항

### ❌ 하지 말아야 할 것

- **main·dev에 직접 push 금지** → 반드시 PR로만
- **API 키, `.env`, 서버 관리자 키 커밋 금지** → `.gitignore`로 관리
  - ⚠️ **Firebase는 파일마다 다릅니다.** `serviceAccountKey.json`·`firebase-adminsdk-*.json`(서버 관리자 키)은 **금지**,
    `google-services.json`·`GoogleService-Info.plist`·`firebase_options.dart`(클라이언트 설정)는 **커밋합니다**.
    근거와 전체 목록은 [docs/ENV_GUIDE.md](docs/ENV_GUIDE.md) 3장 참고. ([#42](https://github.com/FogMap2026/FogApp/pull/42)에서 확정)
- **거대한 PR 금지** → 리뷰 불가능. 기능 단위로 잘게 나누기
- **오래된 브랜치로 작업 금지** → 작업 전 항상 `git pull origin dev`

### ✅ 충돌(Conflict)이 났을 때

```bash
# 내 작업 브랜치에서 최신 dev를 가져와 병합
git checkout feat/map-fog-overlay
git fetch origin
git merge origin/dev
# 충돌 해결 후
git add .
git commit
git push
```

> 💡 **코드를 봐도 왜 충돌인지 모르겠다면** — 같은 코드가 양쪽에 다른 커밋으로 존재하는,
> squash 병합으로 이력이 끊긴 경우일 수 있습니다. 5번 [스택 PR 병합](#️-스택stacked-pr-병합--squash-금지) 참고.

### 🔒 브랜치 보호 설정 (PM이 설정)

Settings → Branches → Branch protection rules 에서 `main`, `dev`에 대해:

- ✅ Require a pull request before merging
- ✅ Require approvals (1명 이상)
- ✅ Do not allow bypassing the above settings

이렇게 설정하면 실수로 직접 push하는 것을 막을 수 있습니다.

---

**질문이나 논의가 필요하면 Issues 또는 팀 채팅에 남겨주세요. 함께 안개를 걷어냅시다 🌫️➡️🗺️**
