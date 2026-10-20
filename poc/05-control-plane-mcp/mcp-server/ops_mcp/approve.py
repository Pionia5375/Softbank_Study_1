"""사람이 쓰는 승인 CLI. 에이전트가 아니라 Jeong 이 자기 터미널에서 친다.

  python -m ops_mcp.approve            # 대기 중인 요청 보기
  python -m ops_mcp.approve <id>       # 내용을 보여 주고 yes 를 입력하면 승인
  python -m ops_mcp.approve deny <id>  # 거절

에이전트가 이 명령을 직접 치는 걸 막는 장치 두 겹 (README 1.6, 셀프 연습)
  - 터미널(TTY)이 아니면 거부한다. 에이전트의 Bash 도구는 TTY 가 아니다
  - Claude Code 설정 permissions.deny 에 이 명령을 넣는다 (.claude/settings.json 예시는 README)
"""
import os
import sys
from pathlib import Path

from .guardrails import Approvals, GuardrailError


def main(argv: list[str]) -> int:
    state = Path(os.environ.get("OPS_MCP_STATE_DIR", str(Path.home() / ".ops-mcp")))
    approvals = Approvals(state / "approvals")

    if not argv:
        pending = approvals.list_pending()
        if not pending:
            print("대기 중인 승인 요청 없음")
        for p in pending:
            print(f"{p['id']}  {p['tool']}  {p['summary']}")
        return 0

    if not sys.stdin.isatty():
        print("거부: 승인은 사람이 터미널에서 직접 해야 한다 (stdin 이 TTY 가 아님)", file=sys.stderr)
        return 2

    try:
        if argv[0] == "deny" and len(argv) == 2:
            approvals.deny(argv[1])
            print(f"거절함: {argv[1]}")
            return 0
        approval_id = argv[0]
        pending = {p["id"]: p for p in approvals.list_pending()}
        if approval_id not in pending:
            print(f"대기 중인 요청이 없다: {approval_id}", file=sys.stderr)
            return 1
        print(f"승인할 내용: {pending[approval_id]['summary']}")
        if input("실행을 허락하려면 yes 입력: ").strip() != "yes":
            print("취소")
            return 1
        approvals.approve(approval_id)
        print(f"승인함: {approval_id} (15분 안에 에이전트가 실행해야 한다)")
        return 0
    except (GuardrailError, FileNotFoundError) as e:
        print(f"오류: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
