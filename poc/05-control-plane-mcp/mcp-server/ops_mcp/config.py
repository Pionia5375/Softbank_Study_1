"""설정. 전부 환경 변수로 받는다 (Claude Code 의 .mcp.json 에서 넣어 줌)."""
import os
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Settings:
    # 가드레일 1: 테넌트는 서버를 띄울 때 정한다. 도구 인자로 받지 않으니 에이전트가 다른 테넌트를 고를 방법 자체가 없다
    tenant: str
    # kubeconfig 경로. make-agent-kubeconfig.sh 가 만든 "ops-agent ServiceAccount 토큰만 든" 파일 (가드레일 2)
    kubeconfig: str | None
    # Knative 입구(Kourier) 주소. port-forward 한 주소. 없으면 get_metrics 가 합성 요청을 건너뛴다
    gateway: str | None
    # 감사 로그·승인 파일이 쌓이는 곳
    state_dir: Path
    # 가드레일 4: scale 한 번에 바꿀 수 있는 최대 폭과 min-scale 상한
    max_step: int = 2
    min_scale_cap: int = 5
    # 승인 유효 시간(초). 오래된 승인으로 나중에 실행하는 걸 막는다
    approval_ttl_seconds: int = 900

    @staticmethod
    def from_env() -> "Settings":
        tenant = os.environ.get("OPS_MCP_TENANT")
        if not tenant:
            raise SystemExit("OPS_MCP_TENANT 가 없다. 이 서버는 테넌트 하나에만 묶여서 뜬다")
        return Settings(
            tenant=tenant,
            kubeconfig=os.environ.get("OPS_MCP_KUBECONFIG"),
            gateway=os.environ.get("OPS_MCP_GATEWAY"),
            state_dir=Path(os.environ.get("OPS_MCP_STATE_DIR", str(Path.home() / ".ops-mcp"))),
            max_step=int(os.environ.get("OPS_MCP_MAX_STEP", "2")),
            min_scale_cap=int(os.environ.get("OPS_MCP_MIN_SCALE_CAP", "5")),
        )
