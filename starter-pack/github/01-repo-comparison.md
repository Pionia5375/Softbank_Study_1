로드맵 위치: 본선 D-10 / 팀 GitHub 운영 전략 / 심사 "팀 개발(대안 문서화) 20점" + Day-1 병목 제거

# 네 팀의 GitHub 운영 비교 (2026-10-28 조사)

조사 방법: 공개 레포를 전부 clone해서 브랜치·커밋·`.github/` 폴더만 봤다. 코드 내용은 보지 않았다.
【사실】은 clone 결과에서 바로 센 숫자, 【추정】은 거기서 내가 읽어낸 판단.

## 0. 한눈에

| | Team Green (2025 본선 2위) | Blue (2025 본선 우승) | camellia (2026 예선, 우리) | rising-sun (하반기 팀 프로젝트) |
|---|---|---|---|---|
| 레포 수 | 【사실】 5개 (`.github` 프로필, `infra`, `manifest`, `codebuild-repo`, `web`) | 【사실】 공개 1개, README만 | 【사실】 모노레포 1개 + `.github` 프로필 | 【사실】 3개 (`Backend`, `Frontend`, `Infra`) |
| 기간·규모 | 【사실】 11/30~12/09, 커밋 237개, 5명 | 【사실】 커밋 6개, 1명 (쇼케이스용) | 【사실】 9/30~10/04 5일, 커밋 557개, 10명, PR #367까지 | 【사실】 8/31~10/27, Backend 716 + Infra 133 + Frontend 9 |
| 기본 브랜치 | `main` (web만 `develop`) | `main` | `main` 하나 | Backend `dev`, Frontend/Infra `main` |
| 작업 브랜치 이름 | 【사실】 `feat/multi-az`, `feat/codebuild-n` | — | 【사실】 `jeong/feat#10`, `minseong/wip-result-ja` (사람/타입#이슈) | 【사실】 `feat/#109-member-login`, `fix/#23-service-probe-startup` (타입/#이슈-설명) |
| 병합 방식 | 【사실】 merge commit ("Merge pull request #22 …"), infra 97커밋 중 17개가 merge | — | 【사실】 merge commit, 557커밋 중 212개가 merge | 【사실】 squash, Backend 285개 제목이 `(#N)`으로 끝남 |
| 커밋 메시지 | 【사실】 `feat:`/`fix:` 접두어, 한·영 혼용, `add:` `fix/` 같은 변형 섞임 | — | 【사실】 접두어 없는 한국어 긴 문장 (예: "코로 말풍선을 백엔드 동작에 맞게 — …") | 【사실】 `feat(live): 한국어 설명 (#312)` 형태로 통일 |
| PR 템플릿 | 【사실】 없음 (`.github/` 폴더 자체가 없음) | — | 【사실】 없음 | 【사실】 Frontend·Infra에 있음 (연관 이슈 / 작업 내용 / 테스트 결과 / 체크리스트) |
| 이슈 템플릿 | 없음 | — | 없음 | 【사실】 Frontend에 BUG·FEAT 2종 |
| 라벨 자동화 | 없음 | — | 없음 | 【사실】 `labeler.yml`로 디렉터리별 자동 라벨 (service:live, terraform, k8s …) |
| CI | 【사실】 GitHub Actions 없음. Terraform Cloud가 state·apply 담당(README) | — | 【사실】 CD만 3개 (`deploy-platform.yml`: main push → OIDC → SSM으로 EC2 배포, `terraform-platform.yml`, `agent-release.yml`) | 【사실】 PR마다 검증: Backend 빌드·테스트·계약 검사, Infra `kustomize build` 렌더링 + `terraform validate`. 배포 워크플로는 없음 |
| CODEOWNERS | 없음 | — | 없음 | 없음 |
| 결정 기록 | README 안에 설명 | README에 심사평 인용 | 【사실】 `docs/decisions.md` 표 (D-01~: 결정 / 버린 대안 / 이유) | 【사실】 Notion + 레포 docs |
| AI 에이전트 규칙 파일 | 없음 | — | 【사실】 `CLAUDE.md`, `HANDOFF.md`, `.claude/` | 【사실】 `AGENTS.md`, `CLAUDE.md`, `harness/` |

## 1. 팀별로 눈에 띈 것

### Team Green (2025 본선 2위, 서창덕 님 팀)
- 【사실】 레포를 플레인별로 4개로 쪼갰다: Terraform(`infra`), k3s 매니페스트(`manifest`, Argo CD app-of-apps + kustomize base), CodeBuild 스크립트, Next.js 웹. 조직 프로필 README에 레포 표를 두어 입구를 하나로 만들었다.
- 【사실】 같은 브랜치에서 PR을 여러 번 냈다 (`feat/codebuild-n` → PR #14, #16, #17; `feat/multi-az` → #21, #22). 브랜치를 길게 살려 두고 조금씩 main에 넣는 방식.
- 【사실】 `web`은 merge 커밋 0개, `develop`에 직접 push. 프론트 1~2명은 PR 없이 간 것으로 보인다【추정】.
- 【사실】 CI가 없다. 매니페스트 오류는 클러스터에 넣어 봐야 알았을 것【추정】.
- 【추정】 README는 매우 정성스럽다(한·일 양국어, 아키텍처 그림). 대회 끝난 뒤 12/9까지 README 커밋이 이어진다 → 레포 자체가 포트폴리오 역할.

### Blue (2025 우승)
- 【사실】 공개 레포는 결과 쇼케이스(README만, 커밋 6개). 작업 레포는 비공개거나 개인 계정에 있다【미확인】.
- 【사실】 README에 인용된 심사평: "팀 내 반대 의견과 PoC 검증을 통한 의사결정", "보안·비용·가용성을 함께 고려한 설계". → 우리가 PR·결정 기록에 남겨야 할 것이 정확히 이것.

### camellia (우리 예선 팀)
- 【사실】 모노레포(pnpm workspace: `apps/`, `packages/`, `infra/`, `tests/`, `tools/`, `docs/`). 5일에 PR 367개, 하루 최대 238커밋(10/2). 모노레포가 이 속도를 막지는 않았다.
- 【사실】 브랜치에 사람 이름을 앞에 붙였다(`jeong/feat#10`, `seohyun/…`). 브랜치 목록만 봐도 누가 뭘 하는지 보였다.
- 【사실】 커밋 제목이 긴 한국어 문장이라 `git log --oneline`이 한 줄에 안 들어온다. 접두어가 없어 타입별로 훑기 어렵다.
- 【사실】 merge 커밋 212개가 main 히스토리에 섞여 있다. 롤백 지점 찾기가 어렵다【추정】.
- 【사실】 PR 템플릿·이슈 템플릿·CI 검증이 없었다. CD만 있었다.
- 【사실】 `docs/decisions.md` 표와 `CLAUDE.md`가 있었다. 결정 기록 형식(결정 / 버린 대안 / 이유)은 그대로 가져갈 만하다.

### rising-sun (하반기 팀)
- 【사실】 레포 3개 + Backend는 `dev` 기본 브랜치. 10/19 조사 당시 `dev`가 `main`보다 630커밋 앞서 있었고 이미지 publish는 `main` push에서만 돌아 최신 코드 이미지가 안 나왔다 (`/mnt/project-files/rising-sun/01-github-status.md`).
- 【사실】 PR 검증 CI가 있다: Infra는 overlay별 `kubectl kustomize` 렌더링, Backend는 바뀐 경로만 골라 테스트. 디렉터리별 자동 라벨.
- 【사실】 PR 템플릿은 잘 짜여 있지만 "대안·트레이드오프" 칸이 없다. 심사 20점과 직접 연결되는 칸은 우리가 추가해야 한다.
- 【사실】 레포가 갈라지니 Infra 매니페스트와 Backend 코드가 어긋났다(probe 포트 8080 vs 9090 등, 01 문서 4장).

## 2. 여기서 끌어낸 결론 (02-strategy.md의 근거)

1. 【추정】 **레포는 하나.** 쪼갠 두 팀(Green, rising-sun) 모두 레포 사이 어긋남·가시성 문제가 있었고, 모노레포인 camellia는 5일 367 PR을 소화했다. Argo CD는 레포 안 경로(`manifests/`)를 가리키면 되므로 매니페스트 레포를 따로 둘 이유가 없다.
2. 【추정】 **`dev` 브랜치 금지, `main` 하나.** rising-sun의 630커밋 격차가 교훈. 1주일짜리 대회에서 "main = 데모 가능한 상태"가 되려면 중간 브랜치가 없어야 한다.
3. 【추정】 **squash 병합.** rising-sun 방식. main 한 줄 = PR 하나 = 이슈 하나. 롤백·blame이 쉽다. Green·camellia의 merge 커밋 더미는 피한다.
4. 【추정】 **PR 템플릿에 "검토한 대안과 버린 이유" 칸을 넣는다.** 네 팀 중 아무도 안 했지만 심사 20점이 여기서 나오고, Blue 심사평이 그걸 증명한다.
5. 【추정】 **PR마다 돌아가는 검증 CI가 필요하다.** Green·camellia는 없었다. 매니페스트 렌더링 + kind 배포 한 번이면 "클러스터에 넣어 봐야 아는" 실수를 PR 단계에서 잡는다.
6. 【추정】 **AI 규칙 파일(`AGENTS.md`) 하나를 Day-1에 둔다.** camellia·rising-sun 모두 있었다. 팀원 6명이 각자 Claude Code/Codex를 쓰면 이 파일이 컨벤션 통일 장치가 된다(AI 활용 10점과도 연결).

## 검증 명령 (조사 재현)

```sh
# 공개 레포를 받아서 숫자를 직접 세는 명령. 어디서든 실행 가능.
git clone -q https://github.com/Softbank-Hackathon-2025-Team-Green/infra && cd infra
git rev-list --count HEAD        # 97  (전체 커밋 수)
git log --merges --oneline | wc -l   # 17 (merge 커밋 수)
ls .github                       # "No such file" → CI·템플릿 없음
cd .. && git clone -q https://github.com/2026-Softbank-hackathon/Auto-Deployment-System && cd Auto-Deployment-System
git rev-list --count HEAD        # 557
git branch -r | sed 's/.*origin\///' | cut -d/ -f1 | sort | uniq -c   # 사람 이름별 브랜치 수
```
