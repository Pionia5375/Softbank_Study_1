import json

import pytest

from ops_mcp.config import Settings
from ops_mcp.guardrails import Approvals, AuditLog
from ops_mcp.tools import OpsTools

from .fakes import FakeKnative


@pytest.fixture
def kn():
    return FakeKnative()


@pytest.fixture
def settings(tmp_path):
    return Settings(tenant="tenant-a", kubeconfig=None, gateway=None, state_dir=tmp_path)


@pytest.fixture
def tools(settings, kn):
    return OpsTools(settings, kn, AuditLog(settings.state_dir / "audit.jsonl"),
                    Approvals(settings.state_dir / "approvals"))


@pytest.fixture
def audit_lines(settings):
    def read():
        p = settings.state_dir / "audit.jsonl"
        return [json.loads(line) for line in p.read_text().splitlines()] if p.exists() else []
    return read
