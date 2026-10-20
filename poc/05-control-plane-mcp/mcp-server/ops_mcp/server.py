"""MCP 서버 입구. Claude Code 같은 MCP 클라이언트가 이 파일을 stdio(표준 입출력)로 띄우고 도구를 부른다.

실행: OPS_MCP_TENANT=tenant-a OPS_MCP_KUBECONFIG=... python -m ops_mcp.server
문서: https://modelcontextprotocol.io/docs/concepts/tools
      https://github.com/modelcontextprotocol/python-sdk (FastMCP)

여기 docstring 은 그대로 LLM 에게 "도구 설명서" 로 간다. 무엇을 하는지·한도·부작용을 짧고 정확하게 쓴다.
"""
import httpx
from kubernetes.client.rest import ApiException
from mcp.server.fastmcp import FastMCP

from .config import Settings
from .guardrails import Approvals, AuditLog, GuardrailError
from .tools import OpsTools


def build_server(tools: OpsTools) -> FastMCP:
    mcp = FastMCP("faas-ops")
    tenant = tools.s.tenant

    @mcp.tool(description=(
        f"테넌트 {tenant} 의 함수 하나의 상태를 읽는다 (읽기 전용, 승인 불필요). "
        "Ready 여부, 트래픽 분배, min/max-scale, 오토스케일러 desired/actual, 파드 수·재시작 수, CPU/메모리, "
        "probe=true 면 함수에 요청 5번을 보내 에러율과 지연(ms)을 잰다."))
    def get_metrics(function: str, probe: bool = True) -> dict:
        return _call(tools.get_metrics, function=function, probe=probe)

    @mcp.tool(description=(
        f"테넌트 {tenant} 함수의 min-scale(항상 떠 있는 최소 파드 수)을 delta 만큼 바꾼다. "
        f"delta 는 -{tools.s.max_step}~+{tools.s.max_step}, 결과는 0~{tools.s.min_scale_cap}. 승인 불필요. "
        "콜드 스타트를 줄이려고 미리 데우거나, 트래픽이 끝나 비용을 줄일 때 쓴다. dry_run=true 면 검사만 한다."))
    def scale(function: str, delta: int, dry_run: bool = False) -> dict:
        return _call(tools.scale, function=function, delta=delta, dry_run=dry_run)

    @mcp.tool(description=(
        f"테넌트 {tenant} 함수의 트래픽 100% 를 지금과 다른 이미지를 가진 직전 Ready Revision 으로 되돌린다. "
        "위험한 행동이라 사람 승인이 필요하다: approval_id 없이 부르면 승인 요청만 만들고 approval_id 를 돌려준다. "
        "사람이 승인한 뒤 같은 function 과 approval_id 로 다시 부르면 실행된다. dry_run=true 면 승인 없이 계획만 검사한다."))
    def rollback(function: str, approval_id: str | None = None, dry_run: bool = False) -> dict:
        return _call(tools.rollback, function=function, approval_id=approval_id, dry_run=dry_run)

    return mcp


def _call(fn, **kwargs) -> dict:
    """거부는 예외 대신 이유를 담은 dict 로 돌려준다 → 에이전트가 이유를 읽고 행동을 고칠 수 있다
    - {"denied": ...}: 파이썬 가드레일(1·3·4층)이 막음
    - {"forbidden": ...}: 쿠버네티스 RBAC(2층)이 막음. 에이전트에게 "권한 밖이니 사람에게 넘겨라" 신호
    """
    try:
        return fn(**kwargs)
    except GuardrailError as e:
        return {"denied": str(e)}
    except ApiException as e:
        if e.status == 403:
            return {"forbidden": f"쿠버네티스 RBAC 가 거부했다 ({e.reason}). 이 도구의 권한 밖이다. 사람에게 넘길 것"}
        return {"error": f"쿠버네티스 API {e.status} {e.reason}"}


def main() -> None:
    from .knative import KnativeApi

    s = Settings.from_env()
    tools = OpsTools(
        settings=s,
        kn=KnativeApi(namespace=s.tenant, kubeconfig=s.kubeconfig),
        audit=AuditLog(s.state_dir / "audit.jsonl"),
        approvals=Approvals(s.state_dir / "approvals", ttl_seconds=s.approval_ttl_seconds),
        http=httpx.Client() if s.gateway else None,
    )
    build_server(tools).run()  # 기본 transport = stdio


if __name__ == "__main__":
    main()
