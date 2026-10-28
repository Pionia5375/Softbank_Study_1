로드맵 위치: 본선 D-10 / 팀 GitHub 운영 전략 (결정안) / 심사 "팀 개발(대안 문서화) 20점" + Day-1 병목 제거

# 본선 팀 GitHub 전략 — 추천안

전제: 5~6명, 10/30 킥오프 ~ 11/8 발표(약 9일), 소통은 Slack, 계획·회의록·설계 문서는 Notion(별도 스레드), 코드는 GitHub.
목표 하나: **킥오프 당일 밤에 첫 PR이 막힘없이 나가고, 누가 뭘 하는지 레포만 봐도 보이게.**
근거 조사는 [01-repo-comparison.md](01-repo-comparison.md). 아래 각 항목은 "선택 / 버린 대안 / 이유" 순서로 썼다. 팀에서 뒤집어도 되는 항목은 `TODO(team)`으로 표시했다.

## 1. 레포 구성: 모노레포 1개

- 선택: 조직(org) 하나 + 레포 하나. 조직을 만드는 이유는 팀원 6명을 한 번에 초대하고, 끝난 뒤 조직 프로필 README가 포트폴리오 입구가 되기 때문(Team Green 방식).
- 버린 대안: 레포를 `app` / `infra` / `manifests`로 쪼개기(Green·rising-sun 방식).
- 이유:
  - 【사실】 쪼갠 두 팀 모두 레포 사이 어긋남이 생겼다(rising-sun: probe 포트 불일치, `dev`가 `main`보다 630커밋 앞섬). 1주일 대회에서 이걸 맞출 시간이 없다.
  - 【사실】 camellia 모노레포는 5일에 PR 367개를 소화했다. 속도의 병목은 레포 수가 아니었다.
  - PR 하나에 "API 변경 + 매니페스트 변경 + 결정 기록"이 같이 들어가서 리뷰어가 전체 맥락을 한 번에 본다. 이게 "컨텍스트 공유 확실한 방식"의 핵심.
  - Argo CD는 레포 안의 경로(`manifests/overlays/dev`)를 가리킬 수 있다. 매니페스트 레포를 따로 둘 기술적 이유가 없다.
- 트레이드오프와 대응: 모노레포는 CI가 매번 전부 돌면 느려진다 → 바뀐 경로만 돌리는 path filter를 CI에 넣었다(`files/.github/workflows/ci.yml`). rising-sun·camellia 둘 다 같은 방법을 썼다【사실】.

권장 디렉터리(주제 공개 전에 만들 수 있는 뼈대):

```
.
├── AGENTS.md            # AI 에이전트(Claude Code·Codex 등)가 읽는 레포 규칙 1장
├── README.md            # 한 줄 소개 + 실행 방법 + 문서 지도 (발표 때 심사위원이 보는 입구)
├── docs/
│   ├── decisions/       # ADR 사본(원본은 Notion Decisions DB). 발표 전날 export
│   ├── architecture.md  # 설계 문서(발표용). Notion과 같은 내용이면 링크만
│   └── runbook.md       # 데모 순서 + 장애 시 대응
├── apps/                # 서비스 코드. apps/api, apps/web, apps/agent …
├── infra/               # Terraform (EC2·네트워크·클러스터)
├── manifests/           # k8s: base/ + overlays/{dev,demo}  (kustomize)
├── scripts/             # up.sh / down.sh / smoke.sh 같은 한 방 스크립트
└── tests/               # 부하·e2e. 측정 결과는 docs/measurements/
```

`TODO(team)`: `apps/` 아래 이름은 주제가 나온 뒤 첫 회의에서 정한다. 나머지는 킥오프 전에 만들어 둔다.

## 2. 브랜치: `main` 하나 + 짧은 작업 브랜치 (GitHub Flow)

- 선택: 기본 브랜치 `main` 하나. 모든 작업은 `main`에서 딴 브랜치 → PR → squash 병합 → 브랜치 자동 삭제. `main`은 항상 "지금 데모 가능한 상태".
- 버린 대안:
  - `dev` + `main` 두 단계(Git Flow 축소판, rising-sun Backend 방식): 【사실】 `dev`가 `main`보다 630커밋 앞서서 이미지가 안 나오는 상황이 실제로 났다. 9일짜리에선 합칠 시간이 없다.
  - 브랜치 없이 `main` 직접 push(Green `web` 방식): 리뷰·CI가 없어지고, 누가 뭘 했는지 PR 목록에서 안 보인다.
- 브랜치 이름: `<type>/<이슈번호>-<짧은-영문-슬러그>`
  - 예: `feat/12-deploy-api`, `fix/31-probe-port`, `docs/40-adr-runtime`, `infra/18-k3s-userdata`
  - type은 커밋 타입과 같은 단어를 쓴다(아래 4절). 이슈 번호가 들어가니 "이 브랜치가 어느 작업인지" 바로 연결된다.
  - 버린 대안: `jeong/feat#10`(camellia 방식, 사람 이름 접두어). 브랜치 목록에서 담당자가 보이는 장점이 있지만, 담당자는 이슈 assignee와 PR 작성자로 이미 보인다. `#`은 셸에서 따옴표가 필요할 때가 있어 뺐다.
- 브랜치 수명: 하루 이내. 이틀 넘게 열려 있으면 쪼개서 먼저 합친다(`main`에 넣어도 안 깨지는 단위로). 기능 플래그가 필요하면 환경변수 하나로.
- `main` 보호 규칙(스크립트가 설정): PR 필수, CI 통과 필수, 승인 1개 필수, 강제 push 금지. 관리자(리드)도 예외 없음 — 단 데모 당일 긴급 수정만 리드가 bypass 하고 사후 PR을 남긴다.
  - 【사실】 GitHub Free 플랜에서 브랜치 보호는 **public 레포에서만** 된다. private로 가려면 Team 플랜이 필요하다. `TODO(team)`: 레포 public 여부. 작년 두 팀 모두 public이었다.

## 3. 이슈 · PR 흐름과 Notion의 경계

Notion 스레드 제안(기능 단위 Tasks DB 15~30개, 태스크마다 PR 링크)에 **동의**한다. GitHub Projects 보드는 만들지 않는다. 이유: 보드가 둘이면 둘 다 안 맞게 된다. "진행 상황을 한 군데서 본다"는 요구는 Notion 보드가 맡고, GitHub는 코드 단위 추적만 한다.

| 층 | 어디 | 단위 | 누가 만들나 |
|---|---|---|---|
| 계획·설계·회의록·일정 | Notion | 기능(T01~T30) | 리드/PM. 회의 때 |
| 코드 작업 | GitHub Issue | 1 이슈 = 1 PR = 반나절 이하 | 작업자 본인. 시작할 때 |
| 논의 | Slack 스레드 | — | 아무나. **결론 한 줄은 이슈나 Notion에 복사** |
| 결정 | Notion Decisions DB (ADR) | 결정 1개 | 결정한 사람. PR에 링크 |

연결 규칙(이게 전부다):
- Notion 태스크의 `링크` 속성에 GitHub 이슈 URL. 이슈 본문 첫 줄에 Notion 태스크 URL (이슈 템플릿에 칸 있음). 양방향 링크 두 개면 끝. 번호 접두어 같은 건 안 쓴다(Notion DB에 번호 속성이 없고, 지키는 사람이 줄어든다).
- PR 본문 첫 줄 `Closes #12` → 병합되면 이슈가 자동으로 닫힌다. (GitHub 기능: `Closes`/`Fixes` + 번호) → Notion 카드는 작업자가 Done으로.
- Slack에 GitHub 앱을 붙여 PR 열림·리뷰 요청·병합이 `#dev` 채널에 자동으로 뜨게 한다(5절 체크리스트). 이게 "슬랙 댓글 + 스레드로 소통"과 GitHub를 잇는 선이다.

리뷰 규칙:
- 승인 1개. 누구나 리뷰어가 될 수 있다(CODEOWNERS 없음, 아래 6절).
- PR 올리면 Slack 자동 알림 + 작성자가 리뷰어 1명을 직접 지정. 30분 안에 반응 없으면 Slack에서 다른 사람 호출. 1시간 넘으면 `skip-review` 라벨 달고 사유 한 줄 쓴 뒤 본인이 병합(리드 승인 대체). 리뷰 대기로 사람이 노는 것이 리뷰 없는 병합보다 비싸다.
- 리뷰어가 보는 것 3가지만: (1) PR 템플릿의 "대안·검증" 칸이 비었나 (2) CI 녹색인가 (3) 데모 경로를 깨뜨리나. 코드 스타일 지적은 안 한다.
- PR 크기: 변경 300줄 이하 권장. 넘으면 쪼갠다.

## 4. 커밋 규칙: Conventional Commits + 한국어 제목

- 형식: `<type>(<scope>): <한국어 설명 50자 이내>` — 예: `feat(api): 배포 생성 엔드포인트 뼈대`, `fix(manifests): live readiness 포트 9090으로`
- type: `feat` `fix` `docs` `infra` `ci` `test` `chore` `refactor` (8개만)
- scope: 최상위 디렉터리 이름(`api`, `web`, `infra`, `manifests`, `docs`, `scripts`). 모르면 생략 가능.
- 본문(선택): "왜"만. 무엇을 했는지는 diff가 말한다.
- 버린 대안: camellia식 긴 한국어 문장 제목. 【사실】 `git log --oneline`에서 한 줄을 넘겨 훑기가 어려웠다. 영어 제목 강제: 팀원이 빨리 쓰는 쪽이 한국어라 포기.
- **squash 병합이라 작업 브랜치 안의 커밋은 아무렇게나 해도 된다.** 규칙이 적용되는 건 PR 제목(= main에 남는 한 줄)뿐. PR 제목을 위 형식으로 쓰면 끝. 이걸로 "컨벤션 지키느라 느려지는" 비용을 없앤다.

## 5. 라벨: 12개만

| 종류 | 라벨 | 용도 |
|---|---|---|
| 영역(자동) | `area:apps` `area:infra` `area:manifests` `area:docs` `area:ci` | labeler가 바뀐 경로를 보고 붙임. 타입(feat/fix)은 PR 제목 접두어로 이미 보이니 라벨로 중복하지 않음 |
| 우선순위 | `P0-demo` `P1` `P2` | P0 = 데모 경로. P0만 보면 "지금 가장 급한 것"이 나온다 |
| 상태 | `blocked` `needs-decision` `skip-review` | `needs-decision`은 Notion 결정 안건으로 올릴 것 |
| 심사 | `judging-evidence` | 측정값·ADR·대안 비교가 들어간 PR. 발표 전 이 라벨만 모으면 증거 목록이 된다 |

버린 대안: rising-sun식 서비스별 라벨(`service:live` …). 주제가 나온 뒤 `labeler.yml`에 디렉터리를 추가하면 되니 Day-1엔 안 만든다.

## 6. CODEOWNERS: 쓰지 않는다

- 이유: CODEOWNERS는 "그 경로가 바뀌면 그 사람 승인 필수"다. 6명이 9일 동안 서로의 영역을 넘나드는데, 담당자가 자고 있으면 PR이 선다. 리뷰어 분산이 목표라 반대 방향이다.
- 대신: `labeler.yml`이 경로별 라벨을 붙이고, Slack 알림에서 라벨을 보고 아는 사람이 집어 간다.
- 예외 `TODO(team)`: `docs/decisions/**`만 리드 리뷰 필수로 두고 싶으면 `files/.github/CODEOWNERS.example`을 이름만 바꿔 쓴다.

## 7. CI 뼈대: "렌더링 + kind 배포 한 번"

`files/.github/workflows/ci.yml` 하나. PR마다 돌고, 바뀐 경로만 실행한다.

| 잡 | 조건 | 하는 일 | 목적 |
|---|---|---|---|
| `workflows` | `.github/**` 변경 | `actionlint` | 워크플로 자체 오타 |
| `manifests` | `manifests/**` 변경 | overlay마다 `kubectl kustomize` 렌더링 → `kubeconform`으로 스키마 검증 | YAML 오타·참조 깨짐을 클러스터 없이 잡기 |
| `infra` | `infra/**` 변경 | `terraform fmt -check` + `terraform validate` (apply 없음) | HCL 문법. **AWS 자격증명 없음** |
| `kind-smoke` | `manifests/**` 또는 `apps/**` 변경 | GitHub 러너 안에 kind 클러스터 생성 → `overlays/dev` 적용 → 모든 Deployment가 Available 될 때까지 대기 → 서비스에 `curl` | "실제로 뜨나"를 PR 단계에서 확인. 약 2~3분 |
| `app` | `apps/**` 변경 | `TODO(team)`: 언어 정해지면 빌드·테스트 한 줄 추가 | |
| `ci` | 항상 | 위 잡들의 결과를 모아 하나로 판정 | `main` 보호 규칙이 요구하는 체크 이름은 이것 하나. 경로 필터로 건너뛴 잡 때문에 PR이 영원히 "대기"에 걸리는 문제를 피한다 |

- 버린 대안: CI 없음(Green·camellia). 【사실】 둘 다 PR 검증이 없었고, Green은 매니페스트 오류를 클러스터에 넣어야 알 수 있었다【추정】.
- 버린 대안: CI에서 AWS에 배포(camellia `deploy-platform.yml`). 본선 초반엔 배포 대상이 없고, 있어도 Argo CD가 당기는 쪽(pull)이 push보다 안전하다. CD는 주제가 나온 뒤 Argo CD `Application`으로 붙인다.
- 처음 보는 도구 설명:
  - `kustomize`: YAML 여러 장을 base + 환경별 덮어쓰기(overlay)로 조립하는 도구. `kubectl kustomize <폴더>`가 조립 결과를 출력만 한다(적용 안 함).
  - `kubeconform`: 조립된 YAML이 쿠버네티스 스키마에 맞는지(필드 이름 오타 등) 클러스터 없이 검사하는 도구.
  - `kind`: 도커 컨테이너 하나를 쿠버네티스 노드처럼 띄우는 도구. CI 러너에서 1분 안에 진짜 클러스터가 생긴다.
  - `actionlint`: GitHub Actions 워크플로 YAML 검사기.

## 8. AI 에이전트 규칙 파일 `AGENTS.md`

- 팀원이 각자 Claude Code·Codex·Cursor를 쓴다고 가정. 레포 루트의 `AGENTS.md` 한 장에 디렉터리 지도·브랜치/커밋 규칙·"하지 말 것"(terraform apply, 시크릿 커밋)을 적어 두면 6명의 에이전트가 같은 규칙을 따른다.
- 【사실】 camellia(`CLAUDE.md`), rising-sun(`AGENTS.md`) 둘 다 있었다. `CLAUDE.md`는 `AGENTS.md`를 가리키는 한 줄만 둔다(도구마다 읽는 파일 이름이 달라서).
- 심사 "AI 활용 10점"에 "개발 과정에서 AI를 어떻게 통제했나"를 보여 줄 증거도 된다.

## 9. 결정 기록(ADR): 원본은 Notion, 레포엔 사본

- 선택: ADR 원본은 Notion Decisions DB(노션 스타터팩 `03-decisions-db.md`의 템플릿). 레포의 `docs/decisions/`는 발표 전날 한 번 export한 사본 + Notion 링크만.
- 버린 대안: 레포 `docs/decisions/NNNN-*.md`를 원본으로(camellia 방식). 버린 이유: 설계 문서·회의록이 Notion에 있고 발표도 Notion으로 하는데 결정만 레포에 있으면 두 군데가 어긋난다. 작성 장벽도 PR보다 Notion 카드가 낮다.
- 규칙: 설계 선택이 들어간 PR은 템플릿 "대안" 칸에 Notion ADR 링크를 붙인다. 작은 대안(라이브러리 선택 수준)은 PR 칸에만 적어도 된다 — 발표 전 `judging-evidence` 라벨 PR을 훑으면 그것도 증거가 된다.
- 레포 사본을 두는 이유: 심사위원·HR이 나중에 레포만 볼 수 있다(Team Green은 대회 뒤에도 README를 다듬었다【사실】).

## 10. Day-1 10분 셋업 (킥오프 끝나자마자, 리드가)

`scripts/day1-setup.sh`가 1~6을 자동으로 한다. 7~9는 손으로.

1. 조직 생성(웹) → 레포 생성 + 스타터 파일 push (`files/` 전체)
2. 병합 설정: squash만 허용, 병합 시 브랜치 자동 삭제
3. 라벨 12개 생성
4. `main` 보호 규칙(PR 필수·CI 필수·승인 1·force-push 금지)
5. Issues 켜기, Projects·Wiki 끄기(Notion이 대신)
6. 팀원 초대(write 권한)
7. Slack `#dev` 채널에서 `/github subscribe <org>/<repo> pulls reviews comments` (GitHub Slack 앱 설치 필요)
8. 각자 `git clone` → `scripts/smoke.sh`로 로컬 kind 배포 한 번 → 성공 스크린샷을 Slack에 (환경 확인 겸 첫 상호작용)
9. 첫 이슈 3개 만들기(리드, Notion 초기 카드와 1:1): `로컬 kind 부팅 스크립트 확인`, `CI 스켈레톤 동작 확인`, `각자 아키텍처 초안 1장` → 바로 첫 PR 연습

---

## 핵심 결정 3개 (+대안)

1. **모노레포 + `main` 하나 + squash** — 대안: 플레인별 멀티레포 + `dev` 브랜치 + merge 커밋. 버린 이유: 작년·하반기 팀에서 레포 간 어긋남과 630커밋 격차가 실제로 났고, 9일엔 그걸 맞출 시간이 없다.
2. **Notion = 기능 단위 보드 + ADR 원본, GitHub Issue = 코드 단위, Projects 보드 없음** — 대안: GitHub Projects 단독, 또는 레포 `docs/decisions/`를 ADR 원본으로. 버린 이유: 회의록·설계·일정·발표가 Notion인데 보드나 결정만 GitHub면 두 군데를 봐야 한다. 양방향 URL 링크 + `Closes #N` 규칙으로 잇는다.
3. **PR 템플릿에 "검토한 대안·버린 이유 / 검증 방법·출력" 칸 필수 + `judging-evidence` 라벨** — 대안: 자유 서술 PR. 버린 이유: 심사 20점이 "대안 문서화"이고 작년 우승팀 심사평이 그걸 짚었는데, 조사한 네 팀 중 PR 템플릿에 그 칸을 둔 팀이 없었다.

## 셀프 연습 1개

`files/` 전체를 네 개인 레포(예: `Pionia5375/finals-sandbox`)에 복사하고 `scripts/day1-setup.sh`를 돌려 본 뒤, 이슈 하나 → 브랜치 `feat/1-hello` → `manifests/base/hello/deployment.yaml`의 `replicas`를 2로 바꾸는 PR을 올려서 CI 4개 잡이 다 녹색이 되는지 본다. 걸린 시간을 재 둔다(목표: 셋업 10분, 첫 PR 녹색까지 10분).

## 검증 명령과 기대 출력

```sh
# 1) 셋업 스크립트가 설정한 병합 방식 확인
gh repo view <org>/<repo> --json squashMergeAllowed,mergeCommitAllowed,rebaseMergeAllowed,deleteBranchOnMerge
# {"deleteBranchOnMerge":true,"mergeCommitAllowed":false,"rebaseMergeAllowed":false,"squashMergeAllowed":true}

# 2) 라벨 12개
gh label list --repo <org>/<repo> | wc -l     # 12

# 3) main 보호
gh api repos/<org>/<repo>/branches/main/protection --jq '.required_pull_request_reviews.required_approving_review_count'   # 1

# 4) 매니페스트가 로컬에서 렌더링되는지 (클러스터 불필요)
kubectl kustomize manifests/overlays/dev | grep -c '^kind:'   # 3 이상 (Namespace, Deployment, Service)
```
