"""도구 3개의 실제 로직. server.py 는 이걸 MCP 도구로 감싸기만 한다.

도구마다 같은 순서를 지킨다:
  1) 입력 검사 (이름 규칙, 한도)          → 어기면 GuardrailError, 감사 로그 "denied"
  2) 현재 상태 읽기
  3) 바꾸는 도구면: dry_run 이면 API 서버 검사만, 아니면 실제 반영
  4) 감사 로그 남기고 결과를 dict 로 돌려줌 (에이전트가 다음 판단에 쓸 수 있게 숫자 위주)
"""
import statistics
import time
from urllib.parse import urlparse

import httpx

from .config import Settings
from .guardrails import Approvals, AuditLog, GuardrailError, check_function_name

MIN_SCALE = "autoscaling.knative.dev/min-scale"
MAX_SCALE = "autoscaling.knative.dev/max-scale"


def _annotations(svc: dict) -> dict:
    return svc.get("spec", {}).get("template", {}).get("metadata", {}).get("annotations", {}) or {}


def _image(obj_spec: dict) -> str | None:
    containers = obj_spec.get("containers") or []
    return containers[0].get("image") if containers else None


def _is_ready(obj: dict) -> bool:
    return any(c.get("type") == "Ready" and c.get("status") == "True"
               for c in obj.get("status", {}).get("conditions", []) or [])


def _generation(rev: dict) -> int:
    return int(rev["metadata"].get("labels", {}).get("serving.knative.dev/configurationGeneration", "0"))


def _traffic_pinned(svc: dict) -> bool:
    """spec.traffic 에 latestRevision: true 가 없으면 = 누가(rollback) 특정 Revision 에 고정해 둔 상태"""
    traffic = svc.get("spec", {}).get("traffic") or []
    return bool(traffic) and not any(t.get("latestRevision") for t in traffic)


class OpsTools:
    def __init__(self, settings: Settings, kn, audit: AuditLog, approvals: Approvals, http: httpx.Client | None = None):
        self.s = settings
        self.kn = kn
        self.audit = audit
        self.approvals = approvals
        self.http = http

    # ------------------------------------------------------------------ get_metrics (읽기 전용)

    def get_metrics(self, function: str, probe: bool = True) -> dict:
        args = {"function": function, "probe": probe}
        try:
            name = check_function_name(function)
            svc = self._require_service(name)
            ann = _annotations(svc)
            status = svc.get("status", {})
            revision = status.get("latestReadyRevisionName")
            pa = self.kn.get_podautoscaler(revision) if revision else None
            pods = self.kn.list_pods(name)
            usage = self.kn.pod_metrics(name)

            result = {
                "tenant": self.s.tenant,
                "function": name,
                "ready": _is_ready(svc),
                "url": status.get("url"),
                "image": _image(svc.get("spec", {}).get("template", {}).get("spec", {})),
                "latest_ready_revision": revision,
                "traffic": [{"revision": t.get("revisionName"), "percent": t.get("percent")}
                            for t in status.get("traffic", []) or []],
                "traffic_pinned": _traffic_pinned(svc),
                "min_scale": int(ann.get(MIN_SCALE, "0")),
                "max_scale": int(ann[MAX_SCALE]) if MAX_SCALE in ann else None,
                "autoscaler": None if pa is None else {
                    "desired": pa.get("status", {}).get("desiredScale"),
                    "actual": pa.get("status", {}).get("actualScale"),
                },
                "pods": {
                    "total": len(pods),
                    "ready": sum(1 for p in pods if any(c.type == "Ready" and c.status == "True"
                                                         for c in (p.status.conditions or []))),
                    "restarts": sum(cs.restart_count for p in pods for cs in (p.status.container_statuses or [])),
                },
                "usage": None if usage is None else [
                    {"pod": m["metadata"]["name"],
                     "containers": {c["name"]: c["usage"] for c in m.get("containers", [])}} for m in usage],
                "probe": self._probe(status.get("url")) if probe else None,
            }
            self.audit.record(self.s.tenant, "get_metrics", args, "allowed")
            return result
        except GuardrailError as e:
            self.audit.record(self.s.tenant, "get_metrics", args, "denied", str(e))
            raise
        except Exception as e:  # RBAC 403 같은 API 서버 거절도 남긴다 (가드레일 2층이 막은 기록)
            self.audit.record(self.s.tenant, "get_metrics", args, "error", f"{type(e).__name__}: {getattr(e, 'status', '')} {getattr(e, 'reason', '') or e}")
            raise

    def _probe(self, url: str | None, n: int = 5) -> dict | None:
        """함수에 진짜 요청 n 번 → 성공 수, 에러 수, 지연 p50/max (ms). 쿠버네티스 지표로는 안 보이는 "500 을 내는 코드"를 잡는다"""
        if not url or not self.s.gateway or self.http is None:
            return None
        host = urlparse(url).hostname
        latencies, ok, errors = [], 0, 0
        for _ in range(n):
            t0 = time.perf_counter()
            try:
                r = self.http.get(self.s.gateway, headers={"Host": host}, timeout=10.0)
                ok += r.status_code < 500
                errors += r.status_code >= 500
            except httpx.HTTPError:
                errors += 1
            latencies.append((time.perf_counter() - t0) * 1000)
        return {"requests": n, "ok": ok, "errors": errors, "error_rate": errors / n,
                "p50_ms": round(statistics.median(latencies), 1), "max_ms": round(max(latencies), 1)}

    # ------------------------------------------------------------------ scale (자동 허용, 한도 안에서)

    def scale(self, function: str, delta: int, dry_run: bool = False) -> dict:
        """min-scale(항상 떠 있는 최소 파드 수)을 delta 만큼 바꾼다. 콜드 스타트를 줄이려고 미리 데워 두는 용도."""
        args = {"function": function, "delta": delta, "dry_run": dry_run}
        try:
            name = check_function_name(function)
            # 가드레일 4: 한 번에 바꾸는 폭 제한. 0 은 의미 없는 호출
            if not isinstance(delta, int) or delta == 0 or abs(delta) > self.s.max_step:
                raise GuardrailError(f"delta 는 0 이 아닌 -{self.s.max_step}~+{self.s.max_step} 정수여야 한다 (받은 값 {delta!r})")

            svc = self._require_service(name)
            if _traffic_pinned(svc):
                raise GuardrailError("트래픽이 특정 Revision 에 고정돼 있다(rollback 이후). 지금 scale 하면 트래픽 0% 인 새 Revision 만 데워진다")

            ann = _annotations(svc)
            current = int(ann.get(MIN_SCALE, "0"))
            max_scale = int(ann.get(MAX_SCALE, str(self.s.min_scale_cap)))
            ceiling = min(self.s.min_scale_cap, max_scale)
            target = current + delta
            if target < 0 or target > ceiling:
                raise GuardrailError(f"min-scale 은 0~{ceiling} 이어야 한다 (지금 {current}, 요청 {delta:+d} → {target})")

            # merge patch: annotations 중 min-scale 키 하나만 바꾼다. 컨트롤 플레인이 적은 다른 필드는 그대로
            patch = {"spec": {"template": {"metadata": {"annotations": {MIN_SCALE: str(target)}}}}}
            self.kn.patch_service(name, patch, dry_run=dry_run)

            self.audit.record(self.s.tenant, "scale", args, "allowed" if dry_run else "executed", f"{current}->{target}")
            return {"function": name, "min_scale_from": current, "min_scale_to": target, "dry_run": dry_run,
                    "note": "Knative 는 template 이 바뀌면 같은 이미지로 새 Revision 을 만들고 트래픽을 옮긴다"}
        except GuardrailError as e:
            self.audit.record(self.s.tenant, "scale", args, "denied", str(e))
            raise
        except Exception as e:  # RBAC 403 같은 API 서버 거절도 남긴다 (가드레일 2층이 막은 기록)
            self.audit.record(self.s.tenant, "scale", args, "error", f"{type(e).__name__}: {getattr(e, 'status', '')} {getattr(e, 'reason', '') or e}")
            raise

    # ------------------------------------------------------------------ rollback (사람 승인 필요)

    def rollback(self, function: str, approval_id: str | None = None, dry_run: bool = False) -> dict:
        """트래픽 100% 를 '지금과 다른 이미지를 가진, 바로 전 Ready Revision' 으로 고정한다."""
        args = {"function": function, "approval_id": approval_id, "dry_run": dry_run}
        try:
            name = check_function_name(function)
            svc = self._require_service(name)
            current_image = _image(svc.get("spec", {}).get("template", {}).get("spec", {}))
            revisions = sorted(self.kn.list_revisions(name), key=_generation, reverse=True)
            target = next((r for r in revisions
                           if _is_ready(r) and _image(r.get("spec", {})) != current_image), None)
            if target is None:
                raise GuardrailError("되돌아갈 곳이 없다: 지금과 다른 이미지를 가진 Ready Revision 이 없다")

            plan = {"function": name, "to_revision": target["metadata"]["name"], "to_image": _image(target["spec"]),
                    "from_image": current_image}
            patch = {"spec": {"traffic": [{"revisionName": plan["to_revision"], "percent": 100}]}}
            bound_args = {"function": name, "to_revision": plan["to_revision"]}

            if dry_run:
                self.kn.patch_service(name, patch, dry_run=True)
                self.audit.record(self.s.tenant, "rollback", args, "allowed", "dry_run " + plan["to_revision"])
                return {"status": "dry_run_ok", "plan": plan}

            # 가드레일 3: 승인 없이는 실행하지 않는다. 승인 요청만 만들고 돌아간다
            if not approval_id:
                new_id = self.approvals.request("rollback", self.s.tenant, bound_args,
                                                f"{self.s.tenant}/{name}: {current_image} → {plan['to_image']} ({plan['to_revision']})")
                self.audit.record(self.s.tenant, "rollback", args, "pending_approval", new_id)
                return {"status": "approval_required", "approval_id": new_id, "plan": plan,
                        "next": f"사람에게 터미널에서 `python -m ops_mcp.approve {new_id}` 를 부탁하고, 승인되면 approval_id 를 넣어 다시 호출"}

            approved, why = self.approvals.is_approved(approval_id, "rollback", self.s.tenant, bound_args)
            if not approved:
                raise GuardrailError(why)

            self.kn.patch_service(name, patch)
            self.approvals.consume(approval_id)
            self.audit.record(self.s.tenant, "rollback", args, "executed", plan["to_revision"])
            return {"status": "rolled_back", "plan": plan,
                    "undo": "컨트롤 플레인으로 새로 배포하면 traffic 이 latestRevision 으로 돌아온다"}
        except GuardrailError as e:
            self.audit.record(self.s.tenant, "rollback", args, "denied", str(e))
            raise
        except Exception as e:  # RBAC 403 같은 API 서버 거절도 남긴다 (가드레일 2층이 막은 기록)
            self.audit.record(self.s.tenant, "rollback", args, "error", f"{type(e).__name__}: {getattr(e, 'status', '')} {getattr(e, 'reason', '') or e}")
            raise

    # ------------------------------------------------------------------ 공통

    def _require_service(self, name: str) -> dict:
        svc = self.kn.get_service(name)
        if svc is None:
            raise GuardrailError(f"테넌트 {self.s.tenant} 에 함수 {name} 이 없다")
        return svc
