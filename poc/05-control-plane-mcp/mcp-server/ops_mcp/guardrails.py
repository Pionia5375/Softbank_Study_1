"""가드레일 부품: 감사 로그, 사람 승인, 이름 검사.

5층 가드레일 중 이 파일이 맡는 것 (README 1.6 표)
- 3층 승인: 위험한 행동(rollback)은 사람이 터미널에서 승인해야 실행된다
- 5층 감사: 모든 도구 호출을 "허용/거부/승인대기/실행" 과 함께 한 줄씩 남긴다
"""
import hashlib
import json
import re
import secrets
import time
from pathlib import Path

NAME_RE = re.compile(r"^[a-z]([-a-z0-9]{0,28}[a-z0-9])?$")


class GuardrailError(Exception):
    """가드레일이 막았다. 에이전트에게 이유를 그대로 돌려준다 (다음 행동을 고칠 수 있게)."""


def check_function_name(name: str) -> str:
    if not isinstance(name, str) or not NAME_RE.match(name):
        raise GuardrailError(f"함수 이름 규칙 위반: {name!r} (소문자로 시작, 소문자·숫자·하이픈, 30자 이하)")
    return name


class AuditLog:
    """JSONL(한 줄에 JSON 하나) 파일. 지우거나 고치는 도구는 일부러 없다."""

    def __init__(self, path: Path):
        self.path = path
        self.path.parent.mkdir(parents=True, exist_ok=True)

    def record(self, tenant: str, tool: str, args: dict, decision: str, detail: str = "") -> None:
        entry = {
            "ts": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
            "actor": "ops-agent",
            "tenant": tenant,
            "tool": tool,
            "args": args,
            # allowed / denied / pending_approval / executed / error
            "decision": decision,
            "detail": detail,
        }
        with self.path.open("a", encoding="utf-8") as f:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")


def _fingerprint(tool: str, tenant: str, args: dict) -> str:
    raw = json.dumps({"tool": tool, "tenant": tenant, "args": args}, sort_keys=True)
    return hashlib.sha256(raw.encode()).hexdigest()


class Approvals:
    """파일로 하는 사람 승인.

    흐름: 도구가 request() → pending/<id>.json 생성 → 사람이 `python -m ops_mcp.approve <id>` →
          approved/<id>.json 생성 → 에이전트가 같은 도구를 approval_id 와 함께 다시 부름 → is_approved() → consume()

    승인은 "도구 + 테넌트 + 인자" 지문(fingerprint)에 묶인다.
    그래서 "hello 를 rev-1 로 롤백" 승인을 받아 놓고 "bye 를 롤백" 하는 데 쓸 수 없다.
    """

    def __init__(self, root: Path, ttl_seconds: int = 900):
        self.root = root
        self.ttl = ttl_seconds
        for sub in ("pending", "approved", "used"):
            (root / sub).mkdir(parents=True, exist_ok=True)

    def request(self, tool: str, tenant: str, args: dict, summary: str) -> str:
        approval_id = secrets.token_hex(4)
        doc = {
            "id": approval_id,
            "tool": tool,
            "tenant": tenant,
            "args": args,
            "summary": summary,
            "fingerprint": _fingerprint(tool, tenant, args),
            "requested_at": time.time(),
        }
        (self.root / "pending" / f"{approval_id}.json").write_text(json.dumps(doc, ensure_ascii=False, indent=2))
        return approval_id

    def is_approved(self, approval_id: str, tool: str, tenant: str, args: dict) -> tuple[bool, str]:
        if not re.fullmatch(r"[0-9a-f]{8}", approval_id or ""):
            return False, "approval_id 형식이 틀렸다"
        path = self.root / "approved" / f"{approval_id}.json"
        if not path.exists():
            return False, "아직 사람이 승인하지 않았다"
        doc = json.loads(path.read_text())
        if doc["fingerprint"] != _fingerprint(tool, tenant, args):
            return False, "승인받은 행동과 지금 요청한 행동이 다르다 (대상 Revision 이 바뀌었을 수 있음). 다시 요청할 것"
        if time.time() - doc["approved_at"] > self.ttl:
            return False, f"승인이 {self.ttl}초가 지나 만료됐다. 다시 요청할 것"
        return True, "ok"

    def consume(self, approval_id: str) -> None:
        """한 번 쓴 승인은 used/ 로 옮긴다 → 같은 승인으로 두 번 실행 못 한다."""
        src = self.root / "approved" / f"{approval_id}.json"
        src.rename(self.root / "used" / f"{approval_id}.json")

    # ---- 사람 쪽 (approve.py 가 부름) ----

    def list_pending(self) -> list[dict]:
        return [json.loads(p.read_text()) for p in sorted((self.root / "pending").glob("*.json"))]

    def approve(self, approval_id: str) -> dict:
        src = self.root / "pending" / f"{approval_id}.json"
        if not src.exists():
            raise GuardrailError(f"대기 중인 승인 요청이 없다: {approval_id}")
        doc = json.loads(src.read_text())
        doc["approved_at"] = time.time()
        (self.root / "approved" / f"{approval_id}.json").write_text(json.dumps(doc, ensure_ascii=False, indent=2))
        src.unlink()
        return doc

    def deny(self, approval_id: str) -> None:
        (self.root / "pending" / f"{approval_id}.json").unlink(missing_ok=False)
