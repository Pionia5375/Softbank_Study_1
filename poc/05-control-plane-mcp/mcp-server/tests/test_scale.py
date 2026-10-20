"""scale 도구 검사. Jeong 이 tools.py 의 scale 을 채우면 전부 통과해야 한다.  실행: .venv/bin/pytest -q"""
import pytest

from ops_mcp.guardrails import GuardrailError
from ops_mcp.tools import MIN_SCALE


def min_scale(kn, name="hello"):
    return kn.services[name]["spec"]["template"]["metadata"]["annotations"].get(MIN_SCALE)


def test_올리면_min_scale_이_바뀌고_감사로그가_남는다(tools, kn, audit_lines):
    kn.add_service("hello", "img@sha256:v2")
    out = tools.scale("hello", 2)
    assert out["min_scale_from"] == 0 and out["min_scale_to"] == 2
    assert min_scale(kn) == "2"
    assert audit_lines()[-1]["decision"] == "executed"


def test_dry_run_이면_실제로는_안_바뀐다(tools, kn):
    kn.add_service("hello", "img@sha256:v2", min_scale=1)
    out = tools.scale("hello", 1, dry_run=True)
    assert out["min_scale_to"] == 2 and out["dry_run"] is True
    assert min_scale(kn) == "1"
    assert kn.patches[-1][2] is True  # API 서버에 dry_run 으로 보냈다


@pytest.mark.parametrize("delta", [0, 3, -3, 10])
def test_한번에_2_넘게는_못_바꾼다(tools, kn, delta, audit_lines):
    kn.add_service("hello", "img@sha256:v2")
    with pytest.raises(GuardrailError):
        tools.scale("hello", delta)
    assert kn.patches == []
    assert audit_lines()[-1]["decision"] == "denied"


def test_0_아래나_상한_위로는_못_간다(tools, kn):
    kn.add_service("hello", "img@sha256:v2", min_scale=0)
    with pytest.raises(GuardrailError):
        tools.scale("hello", -1)
    kn.add_service("big", "img@sha256:v2", min_scale=4, max_scale=5)
    with pytest.raises(GuardrailError):
        tools.scale("big", 2)  # 4+2=6 > 5


def test_max_scale_이_상한보다_작으면_max_scale_이_천장(tools, kn):
    kn.add_service("small", "img@sha256:v2", min_scale=2, max_scale=3)
    with pytest.raises(GuardrailError):
        tools.scale("small", 2)  # 2+2=4 > max-scale 3
    assert tools.scale("small", 1)["min_scale_to"] == 3


def test_없는_함수나_이상한_이름은_거부(tools, kn):
    with pytest.raises(GuardrailError):
        tools.scale("nothing", 1)
    with pytest.raises(GuardrailError):
        tools.scale("../kube-system", 1)


def test_rollback_으로_트래픽이_고정돼_있으면_거부(tools, kn):
    kn.add_service("hello", "img@sha256:v2")
    kn.services["hello"]["spec"]["traffic"] = [{"revisionName": "hello-00001", "percent": 100}]
    with pytest.raises(GuardrailError):
        tools.scale("hello", 1)
