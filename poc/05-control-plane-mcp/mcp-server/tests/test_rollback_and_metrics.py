"""rollback(승인 흐름)과 get_metrics 검사 (Claude 작성 부분)."""
import pytest

from ops_mcp.guardrails import GuardrailError

from .fakes import revision


@pytest.fixture
def two_versions(kn):
    kn.add_service("hello", "img@sha256:v2")
    kn.revisions["hello"] = [
        revision("hello-00001", 1, "img@sha256:v1"),
        revision("hello-00002", 2, "img@sha256:v2"),
        revision("hello-00003", 3, "img@sha256:v2"),  # scale 로 생긴 같은 이미지 Revision
    ]
    return kn


def test_승인_없이는_요청만_만들고_실행하지_않는다(tools, two_versions, audit_lines):
    out = tools.rollback("hello")
    assert out["status"] == "approval_required"
    assert out["plan"]["to_revision"] == "hello-00001"  # 같은 이미지(00003, 00002)는 건너뛴다
    assert two_versions.patches == []
    assert audit_lines()[-1]["decision"] == "pending_approval"


def test_사람이_승인하면_한번만_실행된다(tools, two_versions):
    approval_id = tools.rollback("hello")["approval_id"]
    with pytest.raises(GuardrailError, match="아직"):
        tools.rollback("hello", approval_id=approval_id)

    tools.approvals.approve(approval_id)  # 사람이 approve CLI 로 한 것과 같다
    out = tools.rollback("hello", approval_id=approval_id)
    assert out["status"] == "rolled_back"
    assert two_versions.services["hello"]["spec"]["traffic"] == [{"revisionName": "hello-00001", "percent": 100}]

    with pytest.raises(GuardrailError):  # 같은 승인으로 두 번은 안 된다
        tools.rollback("hello", approval_id=approval_id)


def test_승인은_다른_함수에_못_쓴다(tools, two_versions):
    two_versions.add_service("bye", "img@sha256:b2")
    two_versions.revisions["bye"] = [revision("bye-00001", 1, "img@sha256:b1")]
    approval_id = tools.rollback("hello")["approval_id"]
    tools.approvals.approve(approval_id)
    with pytest.raises(GuardrailError, match="다르다"):
        tools.rollback("bye", approval_id=approval_id)


def test_dry_run_은_승인_없이_계획만(tools, two_versions):
    out = tools.rollback("hello", dry_run=True)
    assert out["status"] == "dry_run_ok"
    assert two_versions.patches[-1][2] is True


def test_되돌아갈_곳이_없으면_거부(tools, kn):
    kn.add_service("hello", "img@sha256:v1")
    kn.revisions["hello"] = [revision("hello-00001", 1, "img@sha256:v1")]
    with pytest.raises(GuardrailError, match="되돌아갈"):
        tools.rollback("hello")


def test_get_metrics_는_숫자를_돌려주고_아무것도_안_바꾼다(tools, two_versions, audit_lines):
    out = tools.get_metrics("hello", probe=False)
    assert out["tenant"] == "tenant-a"
    assert out["ready"] is True and out["min_scale"] == 0 and out["max_scale"] == 5
    assert out["pods"] == {"total": 1, "ready": 1, "restarts": 0}
    assert out["autoscaler"] == {"desired": 1, "actual": 1}
    assert two_versions.patches == []
    assert audit_lines()[-1]["tool"] == "get_metrics"
