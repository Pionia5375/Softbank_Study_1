"""진짜 MCP 프로토콜로 서버에 붙어서 도구 목록과 호출을 확인한다 (메모리 안에서 클라이언트-서버 연결)."""
import json

import anyio
from mcp.shared.memory import create_connected_server_and_client_session

from ops_mcp.server import build_server


def test_도구는_딱_3개이고_tenant_인자는_없다(tools):
    async def run():
        server = build_server(tools)
        async with create_connected_server_and_client_session(server._mcp_server) as client:
            listed = await client.list_tools()
            names = sorted(t.name for t in listed.tools)
            assert names == ["get_metrics", "rollback", "scale"]
            for t in listed.tools:
                assert "tenant" not in t.inputSchema.get("properties", {})  # 가드레일 1
    anyio.run(run)


def test_거부는_에러가_아니라_이유로_돌아온다(tools, kn):
    kn.add_service("hello", "img@sha256:v2")

    async def run():
        server = build_server(tools)
        async with create_connected_server_and_client_session(server._mcp_server) as client:
            res = await client.call_tool("scale", {"function": "hello", "delta": 5})
            assert not res.isError
            assert "denied" in json.loads(res.content[0].text)
            ok = await client.call_tool("scale", {"function": "hello", "delta": 1})
            assert json.loads(ok.content[0].text)["min_scale_to"] == 1
    anyio.run(run)


def test_RBAC_403_은_forbidden_으로_돌아오고_감사로그에_남는다(tools, kn, audit_lines):
    from kubernetes.client.rest import ApiException
    kn.add_service("hello", "img@sha256:v2")

    def forbidden(*a, **k):
        raise ApiException(status=403, reason="Forbidden")
    kn.patch_service = forbidden

    async def run():
        server = build_server(tools)
        async with create_connected_server_and_client_session(server._mcp_server) as client:
            res = await client.call_tool("scale", {"function": "hello", "delta": 1})
            assert "forbidden" in json.loads(res.content[0].text)
    anyio.run(run)
    assert audit_lines()[-1]["decision"] == "error"
