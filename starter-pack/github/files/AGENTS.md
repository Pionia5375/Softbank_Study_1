# AGENTS.md — 이 레포에서 AI 에이전트(Claude Code · Codex · Cursor 등)가 지킬 규칙

사람 팀원도 같은 규칙을 따른다. 사람용 긴 설명은 `docs/`에, 여기는 에이전트가 매번 읽는 1장.

## 레포 지도
- `apps/` 서비스 코드 (TODO(team): 주제 확정 후 하위 이름)
- `infra/` Terraform. **절대 `terraform apply`/`destroy`를 실행하지 않는다.** `fmt`·`validate`·`plan`까지만.
- `manifests/` kustomize. `base/` + `overlays/{dev,demo}`. 적용 전에 `kubectl kustomize <overlay>`로 렌더링 확인.
- `docs/decisions/` ADR 사본. 원본은 Notion Decisions DB — 설계 선택이 들어간 변경은 PR에 Notion ADR 링크를 붙인다. 이 폴더는 발표 전날 export한 것이라 직접 고치지 않는다.
- `docs/runbook.md` 데모 순서. 데모 경로를 바꾸면 같이 고친다.
- `scripts/` `up.sh`(로컬 kind 기동) `smoke.sh`(배포 확인). 새 스크립트는 첫 줄 주석에 용도.

## 브랜치 · 커밋 · PR
- `main`에 직접 push 금지. 브랜치 `<type>/<이슈번호>-<slug>` (예 `feat/12-deploy-api`).
- squash 병합이라 브랜치 안 커밋은 자유. **PR 제목**이 main에 남는 한 줄: `<type>(<scope>): 한국어 설명` — type은 feat fix docs infra ci test chore refactor 중 하나, scope는 최상위 디렉터리.
- PR 본문은 템플릿 칸을 다 채운다. 특히 "검토한 대안과 버린 이유", "어떻게 검증했나(명령+출력)".
- PR 첫 줄 `Closes #<이슈>`.

## 하지 말 것
- 시크릿·키·`.tfvars`·`kubeconfig` 커밋. `.env.example`만.
- 테스트를 끄거나 건너뛰어서 CI를 녹색으로 만들기.
- 요청받지 않은 리팩터링·포맷 변경을 같은 PR에 섞기.
- 결정이 필요한 선택을 혼자 정하기 → `[결정]` 이슈 템플릿으로 올리고 `needs-decision` 라벨.

## 검증 명령 (PR 전에 로컬에서)
```sh
kubectl kustomize manifests/overlays/dev | head          # 렌더링 되는지
bash scripts/up.sh && bash scripts/smoke.sh              # kind에 올려서 응답 확인
terraform -chdir=infra fmt -check -recursive             # infra 건드렸으면
```

## 답변 형식
- 한국어. 결론 먼저. 확정 안 된 것은 확정처럼 쓰지 않는다.
- 측정값은 숫자와 조건(몇 회, 어떤 환경)을 같이.
