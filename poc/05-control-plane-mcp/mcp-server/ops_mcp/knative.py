"""쿠버네티스 API 호출을 한곳에 모은 얇은 층.

- namespace 는 생성자에서 한 번 정하고 메서드 인자로 받지 않는다 (가드레일 1 을 코드 구조로도 강제)
- 실제 권한 경계는 여기가 아니라 RBAC(k8s/ops-agent/rbac.yaml)다. 이 코드에 버그가 있어도
  ServiceAccount 가 할 수 없는 일은 API 서버가 403 으로 막는다 (가드레일 2)
- 테스트는 이 클래스를 FakeKnative 로 바꿔 끼운다 (tests/fakes.py)
"""
from kubernetes import client, config
from kubernetes.client.rest import ApiException

SERVING = ("serving.knative.dev", "v1")
AUTOSCALING = ("autoscaling.internal.knative.dev", "v1alpha1")
METRICS = ("metrics.k8s.io", "v1beta1")


class KnativeApi:
    def __init__(self, namespace: str, kubeconfig: str | None = None):
        if kubeconfig:
            config.load_kube_config(config_file=kubeconfig)
        else:
            try:
                config.load_incluster_config()  # 파드 안에서 돌 때
            except config.ConfigException:
                config.load_kube_config()
        self.ns = namespace
        self.custom = client.CustomObjectsApi()
        self.core = client.CoreV1Api()

    def get_service(self, name: str) -> dict | None:
        try:
            return self.custom.get_namespaced_custom_object(*SERVING, self.ns, "services", name)
        except ApiException as e:
            if e.status == 404:
                return None
            raise

    def list_revisions(self, service: str) -> list[dict]:
        res = self.custom.list_namespaced_custom_object(
            *SERVING, self.ns, "revisions", label_selector=f"serving.knative.dev/service={service}")
        return res.get("items", [])

    def get_podautoscaler(self, revision: str) -> dict | None:
        """Knative 오토스케일러의 판단: desiredScale(원하는 파드 수), actualScale(지금 파드 수)"""
        try:
            return self.custom.get_namespaced_custom_object(*AUTOSCALING, self.ns, "podautoscalers", revision)
        except ApiException as e:
            if e.status in (403, 404):
                return None
            raise

    def list_pods(self, service: str) -> list:
        return self.core.list_namespaced_pod(self.ns, label_selector=f"serving.knative.dev/service={service}").items

    def pod_metrics(self, service: str) -> list[dict] | None:
        """metrics-server 가 없거나 권한이 없으면 None (Lab 04 에서 설치했다면 있음)"""
        try:
            res = self.custom.list_namespaced_custom_object(
                *METRICS, self.ns, "pods", label_selector=f"serving.knative.dev/service={service}")
            return res.get("items", [])
        except ApiException:
            return None

    def patch_service(self, name: str, patch: dict, dry_run: bool = False) -> dict:
        """JSON merge patch. dry_run=True 면 API 서버가 검사(RBAC·스키마·웹훅)만 하고 저장하지 않는다 (가드레일 4)"""
        kwargs = {"dry_run": "All"} if dry_run else {}
        return self.custom.patch_namespaced_custom_object(
            *SERVING, self.ns, "services", name, patch, field_manager="ops-agent", **kwargs)
