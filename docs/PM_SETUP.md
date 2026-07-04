# ⚙️ 저장소 초기 설정 (PM 수동 작업)

Phase 0 항목 중 **GitHub 웹에서만 가능한 관리자 작업**입니다.
PM(박근호 [@PGH0621](https://github.com/PGH0621))이 한 번만 설정하면 됩니다.

---

## 1. 브랜치 보호 규칙 (0-1)

`Settings → Branches → Add branch ruleset` (또는 Branch protection rules)에서
`main` 과 `dev` 각각에 대해:

- ✅ **Require a pull request before merging**
- ✅ **Require approvals** — 1명 이상
- ✅ **Do not allow bypassing the above settings**
- ✅ (선택) Require status checks to pass — CI(`app`, `server`) 통과 요구

> 이렇게 하면 실수로 `main`/`dev`에 직접 push하는 것을 막습니다.
> 자세한 배경은 [CONTRIBUTING.md](../CONTRIBUTING.md) 8번 참고.

---

## 2. 라벨(Label) 생성 (0-2)

`Issues → Labels` 에서 아래 라벨을 만들어주세요.
(gh CLI가 있다면 하단 스크립트로 일괄 생성 가능)

| 라벨 | 색상(hex) | 용도 |
|------|-----------|------|
| `feature` | `#0E8A16` 🟢 | 새 기능 |
| `bug` | `#D73A4A` 🔴 | 버그 |
| `docs` | `#0075CA` 🔵 | 문서 |
| `enhancement` | `#FBCA04` 🟡 | 개선 |
| `help wanted` | `#7057FF` 🟣 | 도움 필요 |
| `map` | `#C5DEF5` ⚪ | 지도·위치·안개 |
| `social` | `#C5DEF5` ⚪ | 매칭·소셜·발자취 |
| `api` | `#C5DEF5` ⚪ | 백엔드·API |
| `ui` | `#C5DEF5` ⚪ | 모바일 프론트 |
| `infra` | `#C5DEF5` ⚪ | 인프라·사진·알림 |

### (선택) gh CLI로 일괄 생성

```bash
# gh 설치 후: https://cli.github.com/
gh label create feature     -c "#0E8A16" -d "새 기능"        -R FogMap2026/FogApp
gh label create bug         -c "#D73A4A" -d "버그"           -R FogMap2026/FogApp
gh label create docs        -c "#0075CA" -d "문서"           -R FogMap2026/FogApp
gh label create enhancement -c "#FBCA04" -d "개선"           -R FogMap2026/FogApp
gh label create "help wanted" -c "#7057FF" -d "도움 필요"     -R FogMap2026/FogApp
gh label create map    -c "#C5DEF5" -d "지도·위치·안개"       -R FogMap2026/FogApp
gh label create social -c "#C5DEF5" -d "매칭·소셜·발자취"     -R FogMap2026/FogApp
gh label create api    -c "#C5DEF5" -d "백엔드·API"          -R FogMap2026/FogApp
gh label create ui     -c "#C5DEF5" -d "모바일 프론트"        -R FogMap2026/FogApp
gh label create infra  -c "#C5DEF5" -d "인프라·사진·알림"     -R FogMap2026/FogApp
```

---

## 3. (선택) GitHub Discussions 활성화

이슈 템플릿의 "논의/질문" 링크가 작동하려면
`Settings → General → Features → Discussions` 를 켜주세요. (안 켜도 무방)
