"""진짜 클러스터 대신 쓰는 가짜 Knative API. KnativeApi 와 메서드 이름·모양이 같다."""
import copy
from types import SimpleNamespace


def revision(name: str, gen: int, image: str, ready: bool = True) -> dict:
    return {
        "metadata": {"name": name, "labels": {"serving.knative.dev/configurationGeneration": str(gen)}},
        "spec": {"containers": [{"image": image}]},
        "status": {"conditions": [{"type": "Ready", "status": "True" if ready else "False"}]},
    }


class FakeKnative:
    def __init__(self, namespace: str = "tenant-a"):
        self.ns = namespace
        self.services: dict[str, dict] = {}
        self.revisions: dict[str, list[dict]] = {}
        self.patches: list[tuple[str, dict, bool]] = []

    def add_service(self, name: str, image: str, min_scale: int | None = None, max_scale: int = 5):
        ann = {"autoscaling.knative.dev/max-scale": str(max_scale)}
        if min_scale is not None:
            ann["autoscaling.knative.dev/min-scale"] = str(min_scale)
        self.services[name] = {
            "metadata": {"name": name, "namespace": self.ns},
            "spec": {"template": {"metadata": {"annotations": ann}, "spec": {"containers": [{"image": image}]}},
                     "traffic": [{"latestRevision": True, "percent": 100}]},
            "status": {"url": f"http://{name}.{self.ns}.example.com", "latestReadyRevisionName": f"{name}-00002",
                       "traffic": [{"revisionName": f"{name}-00002", "percent": 100}],
                       "conditions": [{"type": "Ready", "status": "True"}]},
        }

    def get_service(self, name):
        s = self.services.get(name)
        return copy.deepcopy(s) if s else None

    def list_revisions(self, service):
        return copy.deepcopy(self.revisions.get(service, []))

    def get_podautoscaler(self, revision):
        return {"status": {"desiredScale": 1, "actualScale": 1}}

    def list_pods(self, service):
        ready = SimpleNamespace(type="Ready", status="True")
        cs = SimpleNamespace(restart_count=0)
        return [SimpleNamespace(status=SimpleNamespace(conditions=[ready], container_statuses=[cs]))]

    def pod_metrics(self, service):
        return None

    def patch_service(self, name, patch, dry_run=False):
        self.patches.append((name, patch, dry_run))
        if dry_run:
            return self.get_service(name)
        svc = self.services[name]
        ann = patch.get("spec", {}).get("template", {}).get("metadata", {}).get("annotations")
        if ann:
            svc["spec"]["template"]["metadata"]["annotations"].update(ann)
        if "traffic" in patch.get("spec", {}):
            svc["spec"]["traffic"] = patch["spec"]["traffic"]
        return copy.deepcopy(svc)
