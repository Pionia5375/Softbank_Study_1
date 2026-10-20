package com.example.controlplane.deploy;

import com.example.controlplane.FaasProperties;
import com.example.controlplane.api.DeployAccepted;
import com.example.controlplane.api.DeployRequest;
import com.example.controlplane.api.FunctionStatus;
import com.example.controlplane.audit.AuditLog;
import io.fabric8.kubernetes.api.model.ConfigMap;
import io.fabric8.kubernetes.api.model.ConfigMapBuilder;
import io.fabric8.kubernetes.api.model.ContainerStatus;
import io.fabric8.kubernetes.api.model.GenericKubernetesResource;
import io.fabric8.kubernetes.api.model.Namespace;
import io.fabric8.kubernetes.api.model.OwnerReferenceBuilder;
import io.fabric8.kubernetes.api.model.Pod;
import io.fabric8.kubernetes.api.model.batch.v1.Job;
import io.fabric8.kubernetes.client.KubernetesClient;
import io.fabric8.kubernetes.client.dsl.NonNamespaceOperation;
import io.fabric8.kubernetes.client.dsl.Resource;
import io.fabric8.kubernetes.api.model.GenericKubernetesResourceList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * 함수 배포의 실제 일. 흐름 (README 1.3 그림):
 *
 *   startDeploy (요청 스레드, 1초 안에 끝남)
 *     1) 빌드 Job 생성 (templates/build-job.yaml)  ← 이미 있으면 건너뜀 (같은 코드 = 같은 Job 이름)
 *     2) 소스 ConfigMap 생성 (handler.py + server.py + Dockerfile). 주인(owner)을 Job 으로 → Job 이 지워지면 같이 지워짐
 *     3) finishDeploy 를 백그라운드에 맡기고 바로 202 반환
 *
 *   finishDeploy (백그라운드)
 *     4) Job 이 끝날 때까지 watch 로 기다림
 *     5) kaniko 가 termination message 에 남긴 이미지 digest(sha256:...) 를 읽음
 *     6) Knative Service 를 server-side apply (templates/ksvc.yaml) → Knative 가 새 Revision 을 만들고 트래픽을 옮김
 */
@Service
public class FunctionDeployer {

    private static final Logger log = LoggerFactory.getLogger(FunctionDeployer.class);

    // 라벨 키. 템플릿(build-job.yaml, ksvc.yaml)에도 같은 키를 써야 상태 조회가 찾는다
    public static final String LABEL_TENANT = "faas.poc/tenant";
    public static final String LABEL_FUNCTION = "faas.poc/function";
    public static final String ANNOTATION_BUILD_ID = "faas.poc/build-id";
    // server-side apply 때 "이 필드는 컨트롤 플레인이 주인" 이라고 남는 이름. kubectl get ksvc -o yaml --show-managed-fields 로 보인다
    static final String FIELD_MANAGER = "faas-control-plane";
    static final String KANIKO_CONTAINER = "kaniko";

    private final KubernetesClient k8s;
    private final FaasProperties props;
    private final ManifestRenderer renderer;
    private final AuditLog audit;
    // 빌드를 기다리는 일은 대부분 "가만히 기다림" 이라 가상 스레드가 맞다 (스레드 하나에 메모리 몇 KB)
    private final ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor();
    // 지금 기다리는 중인 빌드 ID. 같은 요청이 두 번 와도 기다리는 스레드는 하나만
    private final Set<String> inFlight = ConcurrentHashMap.newKeySet();

    public FunctionDeployer(KubernetesClient k8s, FaasProperties props, ManifestRenderer renderer, AuditLog audit) {
        this.k8s = k8s;
        this.props = props;
        this.renderer = renderer;
        this.audit = audit;
    }

    /**
     * namespace 가 있고, 3단계 tenant 차트가 붙인 라벨(tenant=<이름>)이 있는가.
     * kube-system 같은 곳에 배포하는 걸 막는 첫 문 (두 번째 문은 RBAC: 테넌트에만 RoleBinding 이 있다)
     */
    public boolean tenantExists(String tenant) {
        Namespace ns = k8s.namespaces().withName(tenant).get();
        return ns != null
                && ns.getMetadata().getLabels() != null
                && tenant.equals(ns.getMetadata().getLabels().get(props.tenantLabel()));
    }

    public DeployAccepted startDeploy(String tenant, DeployRequest req, String actor) {
        String name = req.name();
        String buildId = BuildIds.of(tenant, name, req.code());
        String jobName = "build-" + buildId;
        String buildNs = props.buildNamespace();

        Map<String, String> vars = Map.of(
                "TENANT", tenant,
                "NAME", name,
                "BUILD_ID", buildId,
                "BUILD_NAMESPACE", buildNs,
                "PUSH_IMAGE", props.registryPush() + "/" + tenant + "/" + name + ":" + buildId);

        Job job = k8s.batch().v1().jobs().inNamespace(buildNs).withName(jobName).get();
        boolean reused = job != null;
        if (!reused) {
            Job desired = renderer.render("build-job.yaml", vars, Job.class);
            requireName(desired.getMetadata().getName(), jobName, "build-job.yaml");
            job = k8s.batch().v1().jobs().inNamespace(buildNs).resource(desired).create();

            ConfigMap source = new ConfigMapBuilder()
                    .withNewMetadata()
                        .withName("src-" + buildId)
                        .withNamespace(buildNs)
                        .addToLabels(LABEL_TENANT, tenant)
                        .addToLabels(LABEL_FUNCTION, name)
                        .withOwnerReferences(new OwnerReferenceBuilder()
                                .withApiVersion("batch/v1").withKind("Job")
                                .withName(job.getMetadata().getName()).withUid(job.getMetadata().getUid())
                                .build())
                    .endMetadata()
                    .addToData("handler.py", req.code())
                    .addToData("server.py", renderer.readRuntimeFile("python/server.py"))
                    .addToData("Dockerfile", renderer.readRuntimeFile("python/Dockerfile"))
                    .build();
            // Job 파드는 ConfigMap 이 생길 때까지 ContainerCreating 에서 기다렸다가 뜬다 (kubelet 이 다시 시도)
            k8s.configMaps().inNamespace(buildNs).resource(source).create();
        }
        audit.record(actor, "deploy.accepted", tenant, name, "ok", "buildId=" + buildId + (reused ? " (같은 코드, 빌드 재사용)" : ""));

        if (inFlight.add(buildId)) {
            executor.submit(() -> finishDeploy(tenant, name, buildId, actor));
        }
        String statusUrl = "/api/v1/tenants/" + tenant + "/functions/" + name;
        return new DeployAccepted(tenant, name, buildId, "BUILDING", statusUrl);
    }

    void finishDeploy(String tenant, String name, String buildId, String actor) {
        String jobName = "build-" + buildId;
        try {
            Job done = k8s.batch().v1().jobs().inNamespace(props.buildNamespace()).withName(jobName)
                    .waitUntilCondition(j -> j == null || isFinished(j), props.buildTimeout().toSeconds(), TimeUnit.SECONDS);
            if (done == null || !isSucceeded(done)) {
                audit.record(actor, "deploy.build", tenant, name, "failed", "job=" + jobName);
                return;
            }
            String digest = readDigest(jobName);
            String image = props.registryPull() + "/" + tenant + "/" + name + "@" + digest;

            GenericKubernetesResource ksvc = renderer.render("ksvc.yaml", Map.of(
                    "TENANT", tenant,
                    "NAME", name,
                    "BUILD_ID", buildId,
                    "IMAGE", image), GenericKubernetesResource.class);
            requireName(ksvc.getMetadata().getName(), name, "ksvc.yaml");
            // server-side apply: "내가 적은 필드는 이 값이어야 한다" 를 API 서버에 맡긴다.
            //   - 처음이면 생성, 있으면 내가 주인인 필드만 갱신
            //   - forceConflicts: 다른 주인(예: 에이전트가 롤백으로 바꾼 traffic)이 있어도 새 배포가 이긴다
            //   - 내가 안 적은 필드(에이전트가 바꾼 min-scale)는 건드리지 않는다
            knativeServices(tenant).resource(ksvc).fieldManager(FIELD_MANAGER).forceConflicts().serverSideApply();
            audit.record(actor, "deploy.apply", tenant, name, "ok", "image=" + image);
        } catch (Exception e) {
            log.warn("deploy failed tenant={} name={} buildId={}", tenant, name, buildId, e);
            audit.record(actor, "deploy.apply", tenant, name, "error", e.getMessage());
        } finally {
            inFlight.remove(buildId);
        }
    }

    public FunctionStatus status(String tenant, String name) {
        Job job = latestBuild(tenant, name);
        GenericKubernetesResource ksvc = knativeServices(tenant).withName(name).get();
        if (job == null && ksvc == null) {
            return FunctionStatus.notFound(tenant, name);
        }

        String buildId = job == null ? null : job.getMetadata().getLabels().get("faas.poc/build-id");
        String servingBuildId = ksvc == null ? null : str(ksvc, "spec", "template", "metadata", "annotations", ANNOTATION_BUILD_ID);
        String image = ksvc == null ? null : firstContainerImage(ksvc);
        String url = ksvc == null ? null : str(ksvc, "status", "url");
        String revision = ksvc == null ? null : str(ksvc, "status", "latestReadyRevisionName");

        if (job != null && !isFinished(job)) {
            return new FunctionStatus(tenant, name, "BUILDING", buildId, image, url, revision, null);
        }
        if (job != null && !isSucceeded(job)) {
            return new FunctionStatus(tenant, name, "BUILD_FAILED", buildId, image, url, revision,
                    "kubectl -n " + props.buildNamespace() + " logs job/" + job.getMetadata().getName() + " -c " + KANIKO_CONTAINER);
        }
        // 빌드는 끝났는데 Knative Service 가 아직 이 빌드를 안 가리킨다 = 백그라운드가 apply 하기 직전
        if (ksvc == null || (buildId != null && !buildId.equals(servingBuildId))) {
            return new FunctionStatus(tenant, name, "DEPLOYING", buildId, image, url, revision, null);
        }
        Map<String, Object> ready = readyCondition(ksvc);
        String readyStatus = ready == null ? null : (String) ready.get("status");
        String phase = "True".equals(readyStatus) ? "READY" : "False".equals(readyStatus) ? "FAILED" : "DEPLOYING";
        String message = ready == null ? null : (String) ready.get("message");
        return new FunctionStatus(tenant, name, phase, servingBuildId, image, url, revision, message);
    }

    // ---- 아래는 도우미 ----

    private NonNamespaceOperation<GenericKubernetesResource, GenericKubernetesResourceList, Resource<GenericKubernetesResource>> knativeServices(String tenant) {
        return k8s.genericKubernetesResources("serving.knative.dev/v1", "Service").inNamespace(tenant);
    }

    private Job latestBuild(String tenant, String name) {
        List<Job> jobs = k8s.batch().v1().jobs().inNamespace(props.buildNamespace())
                .withLabel(LABEL_TENANT, tenant)
                .withLabel(LABEL_FUNCTION, name)
                .list().getItems();
        return jobs.stream()
                .max(Comparator.comparing((Job j) -> j.getMetadata().getCreationTimestamp(), Comparator.nullsFirst(Comparator.naturalOrder())))
                .orElse(null);
    }

    /** kaniko 의 --digest-file=/dev/termination-log 덕분에, 끝난 컨테이너 상태의 message 에 digest 가 들어 있다 */
    private String readDigest(String jobName) {
        List<Pod> pods = k8s.pods().inNamespace(props.buildNamespace()).withLabel("job-name", jobName).list().getItems();
        return pods.stream()
                .flatMap(p -> p.getStatus() == null || p.getStatus().getContainerStatuses() == null
                        ? java.util.stream.Stream.<ContainerStatus>empty()
                        : p.getStatus().getContainerStatuses().stream())
                .filter(cs -> KANIKO_CONTAINER.equals(cs.getName()))
                .map(cs -> cs.getState() == null || cs.getState().getTerminated() == null ? null : cs.getState().getTerminated().getMessage())
                .filter(Objects::nonNull)
                .map(String::trim)
                .filter(m -> m.startsWith("sha256:"))
                .findFirst()
                .orElseThrow(() -> new IllegalStateException("빌드 파드에서 digest 를 못 찾았다. build-job.yaml 의 컨테이너 이름이 " + KANIKO_CONTAINER
                        + " 이고 --digest-file=/dev/termination-log 가 있는지 확인"));
    }

    private static boolean isFinished(Job j) {
        return j.getStatus() != null && (nz(j.getStatus().getSucceeded()) > 0 || nz(j.getStatus().getFailed()) > 0);
    }

    private static boolean isSucceeded(Job j) {
        return j.getStatus() != null && nz(j.getStatus().getSucceeded()) > 0;
    }

    private static int nz(Integer i) {
        return i == null ? 0 : i;
    }

    private static void requireName(String actual, String expected, String template) {
        if (!expected.equals(actual)) {
            throw new IllegalStateException(template + " 의 metadata.name 이 " + expected + " 가 되어야 하는데 " + actual + " 이다");
        }
    }

    // GenericKubernetesResource 는 metadata 만 자바 필드이고 spec·status 는 Map 안에 들어 있다. 경로를 따라 내려간다
    @SuppressWarnings("unchecked")
    private static Object at(GenericKubernetesResource r, String... path) {
        Object cur = r.getAdditionalProperties();
        for (String p : path) {
            if (!(cur instanceof Map<?, ?> map)) return null;
            cur = ((Map<String, Object>) map).get(p);
        }
        return cur;
    }

    private static String str(GenericKubernetesResource r, String... path) {
        Object v = at(r, path);
        return v == null ? null : v.toString();
    }

    @SuppressWarnings("unchecked")
    private static String firstContainerImage(GenericKubernetesResource r) {
        Object containers = at(r, "spec", "template", "spec", "containers");
        if (containers instanceof List<?> list && !list.isEmpty() && list.get(0) instanceof Map<?, ?> c) {
            Object image = ((Map<String, Object>) c).get("image");
            return image == null ? null : image.toString();
        }
        return null;
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> readyCondition(GenericKubernetesResource r) {
        Object conditions = at(r, "status", "conditions");
        if (!(conditions instanceof List<?> list)) return null;
        return list.stream()
                .filter(c -> c instanceof Map<?, ?> m && "Ready".equals(m.get("type")))
                .map(c -> (Map<String, Object>) c)
                .findFirst()
                .orElse(null);
    }
}
