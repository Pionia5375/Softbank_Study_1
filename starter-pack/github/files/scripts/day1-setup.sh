#!/usr/bin/env bash
# 킥오프 직후 리드가 한 번 실행하는 레포 셋업. 약 2분.
# 사용법: 이 스타터 파일들을 복사한 폴더에서
#   git init && git add -A && git commit -m "chore: 레포 뼈대"
#   bash scripts/day1-setup.sh <org> <repo> [팀원 깃허브 핸들...]
# 필요한 것: gh CLI 로그인 상태(`gh auth status`), jq.
#   gh = GitHub를 터미널에서 조작하는 공식 CLI. https://cli.github.com
#   jq = JSON을 다루는 커맨드라인 도구.
set -euo pipefail

ORG="${1:?org 이름}"
REPO="${2:?repo 이름}"
shift 2
MEMBERS=("$@")
FULL="$ORG/$REPO"

echo "== 1) 레포 생성 + 현재 폴더 push (public: GitHub Free에서 브랜치 보호를 쓰려면 public이어야 한다)"
if gh repo view "$FULL" >/dev/null 2>&1; then
  echo "   이미 있음, 건너뜀"
else
  git branch -M main
  gh repo create "$FULL" --public --source=. --remote=origin --push
fi

echo "== 2) 병합 방식: squash만, 병합 후 브랜치 자동 삭제, Issues 켜고 Projects·Wiki 끔"
gh repo edit "$FULL" \
  --enable-squash-merge --enable-merge-commit=false --enable-rebase-merge=false \
  --delete-branch-on-merge \
  --enable-issues --enable-projects=false --enable-wiki=false

echo "== 3) 라벨 12개 (.github/labels.json)"
jq -c '.[]' "$(dirname "$0")/../.github/labels.json" | while read -r row; do
  name=$(jq -r .name <<<"$row"); color=$(jq -r .color <<<"$row"); desc=$(jq -r .description <<<"$row")
  gh label create "$name" --repo "$FULL" --color "$color" --description "$desc" --force >/dev/null
  echo "   $name"
done

echo "== 4) main 보호: PR 필수, 승인 1, CI 'ci' 체크 통과 필수, force-push·삭제 금지, 관리자도 적용"
# gh api = GitHub REST API를 직접 호출. -X PUT = 덮어쓰기. --input - = JSON을 표준입력으로.
gh api -X PUT "repos/$FULL/branches/main/protection" --input - >/dev/null <<'JSON'
{
  "required_status_checks": { "strict": false, "contexts": ["ci"] },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": false
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_linear_history": true
}
JSON

if ((${#MEMBERS[@]})); then
  echo "== 5) 팀원 초대 (write 권한)"
  for u in "${MEMBERS[@]}"; do
    gh api -X PUT "repos/$FULL/collaborators/$u" -f permission=push >/dev/null && echo "   $u"
  done
fi

echo
echo "완료. 남은 수동 작업:"
echo "  - Slack #dev 채널에서:  /github subscribe $FULL pulls reviews comments"
echo "  - 각자: git clone https://github.com/$FULL && cd $REPO && bash scripts/up.sh && bash scripts/smoke.sh"
echo "  - 리드: 첫 이슈 3개 ([T00] 아키텍처 초안 / 데모 시나리오 초안 / 로컬 환경 확인)"
echo
echo "확인:"
echo "  gh repo view $FULL --json squashMergeAllowed,mergeCommitAllowed,deleteBranchOnMerge"
echo "  gh label list --repo $FULL | wc -l        # 12"
