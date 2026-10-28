로드맵 위치: 본선 D-10 / 팀 GitHub 운영 스타터팩 / Day-1 병목 제거 + 심사 "팀 개발 20점"

# starter-pack/github — 본선 팀 레포를 10분 안에 세우는 묶음

| 파일 | 내용 |
|---|---|
| [01-repo-comparison.md](01-repo-comparison.md) | 작년 2위(Team Green)·우승(Blue)·우리 예선(camellia)·하반기 팀(rising-sun) 레포 운영 비교. 【사실】/【추정】 구분 |
| [02-strategy.md](02-strategy.md) | 추천 전략: 모노레포 / `main` 하나 + squash / Notion·Issue 경계 / 커밋·라벨 / CODEOWNERS 안 씀 / CI 뼈대 / ADR / Day-1 체크리스트. 항목마다 "선택·대안·이유" |
| [files/](files/) | **팀 레포 루트에 그대로 복사하는 파일들.** 아래 표 |

## files/ 안에 뭐가 있나

| 경로 | 역할 |
|---|---|
| `.github/pull_request_template.md` | PR 양식. "검토한 대안과 버린 이유", "검증 명령+출력" 칸 필수 |
| `.github/ISSUE_TEMPLATE/{task,bug,decision}.md`, `config.yml` | 이슈 3종(작업·버그·결정 요청). 빈 이슈 금지, 계획은 Notion으로 링크 |
| `.github/labeler.yml` + `workflows/labeler.yml` | 바뀐 경로로 `area:*` 라벨 자동 |
| `.github/workflows/ci.yml` | PR 검증: actionlint / kustomize 렌더링+kubeconform / terraform validate / **kind에 실제 배포 후 curl** / 결과 집계 `ci` |
| `.github/labels.json` | 라벨 12개 정의 (스크립트가 읽음) |
| `.github/CODEOWNERS.example` | 기본은 안 씀. 필요할 때만 이름 바꿔서 |
| `AGENTS.md`, `CLAUDE.md` | 사람·AI 공통 작업 규칙 1장 |
| `docs/decisions/README.md` | ADR 원본은 Notion Decisions DB. 이 폴더는 발표 전날 export 사본 + 절차 |
| `manifests/base/hello`, `overlays/{dev,demo}` | CI·로컬 smoke용 최소 앱(nginx). 주제 나오면 교체 |
| `scripts/up.sh`, `smoke.sh` | 로컬 kind 기동, 응답 확인 (CI와 같은 스크립트) |
| `scripts/day1-setup.sh` | 레포 생성·병합 설정·라벨·브랜치 보호·팀원 초대를 `gh`로 한 번에 |
| `README.md`, `.gitignore` | 팀 레포 README 뼈대, 시크릿 제외 목록 |

## 쓰는 법 (킥오프 직후, 리드)

```sh
# 1) 새 폴더에 files/ 내용을 복사 (숨김 파일 .github .gitignore 포함되게 `/.` 로)
mkdir finals && cp -r starter-pack/github/files/. finals/ && cd finals

# 2) 첫 커밋
git init && git add -A && git commit -m "chore: 레포 뼈대 (스타터팩)"

# 3) gh 로그인 확인 후 셋업 스크립트 (org·repo 이름은 킥오프에서 정한 것)
gh auth status
bash scripts/day1-setup.sh <org> <repo> <팀원핸들1> <팀원핸들2> ...

# 4) Slack #dev 에서
#    /github subscribe <org>/<repo> pulls reviews comments
```

처음 보는 명령 설명:
- `cp -r 원본/. 대상/` — 끝의 `/.`가 숨김 파일(`.github`)까지 같이 복사하게 한다.
- `gh auth status` — GitHub CLI가 어느 계정으로 로그인돼 있는지 확인. 안 돼 있으면 `gh auth login`.
- `/github subscribe …` — Slack GitHub 앱 명령. PR 열림·리뷰·댓글이 채널에 자동으로 올라온다.

## 주제 공개 전에 할 수 있는 것 (이 팩으로)
- 개인 샌드박스 레포에 한 번 돌려서 셋업 10분 + 첫 PR 녹색 10분을 실측 (02-strategy 셀프 연습).
- `scripts/up.sh`가 내 맥에서 도는지 확인 — kind·kubectl 설치 상태 점검을 겸한다.
- `AGENTS.md`를 내 Claude Code로 읽혀 보고 어색한 규칙 수정.
