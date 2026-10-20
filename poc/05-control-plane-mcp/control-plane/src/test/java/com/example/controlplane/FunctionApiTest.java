package com.example.controlplane;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import io.fabric8.kubernetes.api.model.ConfigMap;
import io.fabric8.kubernetes.api.model.GenericKubernetesResource;
import io.fabric8.kubernetes.api.model.NamespaceBuilder;
import io.fabric8.kubernetes.api.model.Pod;
import io.fabric8.kubernetes.api.model.PodBuilder;
import io.fabric8.kubernetes.api.model.batch.v1.Job;
import io.fabric8.kubernetes.api.model.batch.v1.JobStatusBuilder;
import io.fabric8.kubernetes.client.KubernetesClient;
import io.fabric8.kubernetes.client.NamespacedKubernetesClient;
import io.fabric8.kubernetes.client.dsl.base.CustomResourceDefinitionContext;
import io.fabric8.kubernetes.client.server.mock.KubernetesCrudDispatcher;
import io.fabric8.kubernetes.client.server.mock.KubernetesMockServer;
import io.fabric8.mockwebserver.Context;
import io.fabric8.mockwebserver.MockWebServer;
import io.fabric8.mockwebserver.dsl.HttpMethod;
import io.fabric8.mockwebserver.http.Buffer;
import io.fabric8.mockwebserver.http.MockResponse;
import io.fabric8.mockwebserver.http.RecordedRequest;
import java.time.Duration;
import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Supplier;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

/**
 * 진짜 클러스터 없이 "가짜 API 서버"(fabric8 mock, 메모리에 리소스를 저장)로 API 를 검사한다.
 * Jeong 이 채운 것 세 개(FunctionController.deploy, build-job.yaml, ksvc.yaml)가 맞으면 전부 통과한다.
 *
 * 실행: ./mvnw test   (control-plane 폴더에서)
 */
@SpringBootTest(properties = "logging.level.io.fabric8.mockwebserver=WARN")
@AutoConfigureMockMvc
class FunctionApiTest {

    static final String TENANT = "tenant-a";
    static final String BUILD_NS = "faas-build";
    static final String CODE = "def handle(body):\n    return {'hello': body.decode() or 'world'}\n";
    static final String DIGEST = "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

    static final CustomResourceDefinitionContext KSVC = new CustomResourceDefinitionContext.Builder()
            .withGroup("serving.knative.dev").withVersion("v1").withPlural("services").withKind("Service")
            .withScope("Namespaced").build();

    static final KubernetesMockServer server;
    static final NamespacedKubernetesClient client;

    static {
        server = new KubernetesMockServer(new Context(), new MockWebServer(), new HashMap<>(),
                new ApplyCreatesDispatcher(List.of(KSVC)), false);
        server.init();
        server.expectCustomResource(KSVC);
        client = server.createClient();
    }

    /**
     * 진짜 API 서버는 server-side apply 대상이 없으면 새로 만든다. 가짜 서버는 404 를 내서, 그 경우만 생성으로 바꿔 준다.
     */
    static class ApplyCreatesDispatcher extends KubernetesCrudDispatcher {
        ApplyCreatesDispatcher(List<CustomResourceDefinitionContext> crds) {
            super(crds);
        }

        @Override
        public MockResponse handlePatch(RecordedRequest req) {
            byte[] body = req.getBody().getBytes();
            MockResponse res = super.handlePatch(new RecordedRequest(req.getHttpVersion(), HttpMethod.PATCH, req.getPath(), req.getHeaders(), new Buffer(body)));
            if (res.code() == 404 && String.valueOf(req.getHeader("Content-Type")).startsWith("application/apply-patch")) {
                String path = req.getPath().split("\\?")[0];
                String collection = path.substring(0, path.lastIndexOf('/'));
                return super.handleCreate(new RecordedRequest(req.getHttpVersion(), HttpMethod.POST, collection, req.getHeaders(), new Buffer(body)));
            }
            return res;
        }
    }

    @TestConfiguration
    static class MockClusterConfig {
        @Bean(destroyMethod = "")
        @Primary
        KubernetesClient mockKubernetesClient() {
            return client;
        }
    }

    @AfterAll
    static void stop() {
        client.close();
        server.destroy();
    }

    @Autowired
    MockMvc mvc;

    @BeforeEach
    void cleanCluster() {
        client.batch().v1().jobs().inNamespace(BUILD_NS).delete();
        client.configMaps().inNamespace(BUILD_NS).delete();
        client.pods().inNamespace(BUILD_NS).delete();
        client.genericKubernetesResources("serving.knative.dev/v1", "Service").inNamespace(TENANT).delete();
        client.namespaces().resource(new NamespaceBuilder().withNewMetadata().withName(TENANT)
                .addToLabels("tenant", TENANT).endMetadata().build()).createOr(r -> r.update());
        client.namespaces().resource(new NamespaceBuilder().withNewMetadata().withName("kube-system")
                .endMetadata().build()).createOr(r -> r.update());
    }

    @Test
    void 배포하면_202와_빌드Job과_소스ConfigMap이_생긴다() throws Exception {
        mvc.perform(deploy(TENANT, "hello", CODE))
                .andExpect(status().isAccepted())
                .andExpect(header().string("Location", "/api/v1/tenants/tenant-a/functions/hello"))
                .andExpect(jsonPath("$.buildId").value(org.hamcrest.Matchers.startsWith("hello-")))
                .andExpect(jsonPath("$.phase").value("BUILDING"));

        Job job = onlyJob();
        assertThat(job.getMetadata().getName()).startsWith("build-hello-");
        assertThat(job.getMetadata().getLabels())
                .containsEntry("faas.poc/tenant", TENANT)
                .containsEntry("faas.poc/function", "hello");
        assertThat(job.getSpec().getBackoffLimit()).as("빌드 실패는 재시도하지 않는다").isZero();
        var pod = job.getSpec().getTemplate().getSpec();
        assertThat(pod.getRestartPolicy()).isEqualTo("Never");
        assertThat(pod.getNodeSelector()).as("빌드 노드 풀").containsEntry("pool", "build");
        assertThat(pod.getTolerations()).anyMatch(t -> "pool".equals(t.getKey()) && "NoSchedule".equals(t.getEffect()));
        var kaniko = pod.getContainers().stream().filter(c -> c.getName().equals("kaniko")).findFirst().orElseThrow();
        String buildId = job.getMetadata().getLabels().get("faas.poc/build-id");
        assertThat(kaniko.getArgs()).contains(
                "--destination=kind-registry:5000/tenant-a/hello:" + buildId,
                "--digest-file=/dev/termination-log");
        assertThat(pod.getVolumes()).anyMatch(v -> v.getConfigMap() != null && ("src-" + buildId).equals(v.getConfigMap().getName()));

        ConfigMap src = client.configMaps().inNamespace(BUILD_NS).withName("src-" + buildId).get();
        assertThat(src.getData()).containsEntry("handler.py", CODE).containsKeys("server.py", "Dockerfile");
        assertThat(src.getMetadata().getOwnerReferences()).singleElement()
                .satisfies(o -> assertThat(o.getName()).isEqualTo(job.getMetadata().getName()));
    }

    @Test
    void 빌드가_끝나면_KnativeService가_생기고_READY까지_간다() throws Exception {
        mvc.perform(deploy(TENANT, "hello", CODE)).andExpect(status().isAccepted());
        Job job = onlyJob();
        finishBuild(job, true);

        GenericKubernetesResource ksvc = waitFor(() ->
                client.genericKubernetesResources("serving.knative.dev/v1", "Service").inNamespace(TENANT).withName("hello").get());
        Map<String, Object> spec = map(ksvc.getAdditionalProperties().get("spec"));
        Map<String, Object> template = map(spec.get("template"));
        Map<String, Object> container = map(((List<?>) map(template.get("spec")).get("containers")).get(0));
        assertThat(container.get("image")).isEqualTo("localhost:5001/tenant-a/hello@" + DIGEST);
        assertThat(map(map(template.get("metadata")).get("annotations")))
                .containsEntry("faas.poc/build-id", job.getMetadata().getLabels().get("faas.poc/build-id"));
        assertThat(ksvc.getMetadata().getLabels()).containsEntry("faas.poc/function", "hello");
        assertThat((List<?>) spec.get("traffic")).singleElement()
                .satisfies(t -> assertThat(map(t)).containsEntry("latestRevision", true));

        mvc.perform(get("/api/v1/tenants/tenant-a/functions/hello"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.phase").value("DEPLOYING"));

        // Knative 컨트롤러가 할 일(상태 채우기)을 테스트가 대신한다
        ksvc.getAdditionalProperties().put("status", Map.of(
                "url", "http://hello.tenant-a.example.com",
                "latestReadyRevisionName", "hello-00001",
                "conditions", List.of(Map.of("type", "Ready", "status", "True"))));
        client.genericKubernetesResources("serving.knative.dev/v1", "Service").inNamespace(TENANT).resource(ksvc).update();

        mvc.perform(get("/api/v1/tenants/tenant-a/functions/hello"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.phase").value("READY"))
                .andExpect(jsonPath("$.url").value("http://hello.tenant-a.example.com"))
                .andExpect(jsonPath("$.image").value("localhost:5001/tenant-a/hello@" + DIGEST));
    }

    @Test
    void 빌드가_실패하면_BUILD_FAILED() throws Exception {
        mvc.perform(deploy(TENANT, "broken", CODE)).andExpect(status().isAccepted());
        finishBuild(onlyJob(), false);
        mvc.perform(get("/api/v1/tenants/tenant-a/functions/broken"))
                .andExpect(jsonPath("$.phase").value("BUILD_FAILED"));
    }

    @Test
    void 같은_코드를_두번_보내면_빌드는_한번() throws Exception {
        String first = mvc.perform(deploy(TENANT, "hello", CODE)).andReturn().getResponse().getContentAsString();
        String second = mvc.perform(deploy(TENANT, "hello", CODE)).andReturn().getResponse().getContentAsString();
        assertThat(client.batch().v1().jobs().inNamespace(BUILD_NS).list().getItems()).hasSize(1);
        assertThat(jsonField(first, "buildId")).isEqualTo(jsonField(second, "buildId"));
    }

    @Test
    void 없는_테넌트나_테넌트_라벨_없는_namespace는_404() throws Exception {
        mvc.perform(deploy("tenant-zzz", "hello", CODE)).andExpect(status().isNotFound());
        mvc.perform(deploy("kube-system", "hello", CODE)).andExpect(status().isNotFound());
        assertThat(client.batch().v1().jobs().inNamespace(BUILD_NS).list().getItems()).isEmpty();
    }

    @Test
    void 이름이_규칙에_안_맞으면_400() throws Exception {
        mvc.perform(deploy(TENANT, "Hello_World", CODE)).andExpect(status().isBadRequest());
        mvc.perform(deploy(TENANT, "a-very-long-function-name-over-thirty", CODE)).andExpect(status().isBadRequest());
    }

    @Test
    void 코드가_너무_크면_413() throws Exception {
        String huge = "x = '" + "a".repeat(300_000) + "'\n";
        mvc.perform(deploy(TENANT, "huge", huge)).andExpect(status().isContentTooLarge());
    }

    @Test
    void 처음_보는_함수_상태는_404() throws Exception {
        mvc.perform(get("/api/v1/tenants/tenant-a/functions/nothing"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.phase").value("NOT_FOUND"));
    }

    // ---- 도우미 ----

    static org.springframework.test.web.servlet.RequestBuilder deploy(String tenant, String name, String code) {
        String body = "{\"name\":\"" + name + "\",\"code\":" + jsonString(code) + "}";
        return post("/api/v1/tenants/" + tenant + "/functions")
                .header("X-Actor", "test")
                .contentType(MediaType.APPLICATION_JSON)
                .content(body);
    }

    /** 쿠버네티스의 Job 컨트롤러 + kubelet 이 할 일(상태 채우기, 파드 종료 메시지)을 테스트가 대신한다 */
    static void finishBuild(Job job, boolean success) {
        String jobName = job.getMetadata().getName();
        if (success) {
            Pod pod = new PodBuilder()
                    .withNewMetadata().withName(jobName + "-abcde").withNamespace(BUILD_NS)
                        .addToLabels("job-name", jobName).endMetadata()
                    .withNewStatus().addNewContainerStatus().withName("kaniko")
                        .withNewState().withNewTerminated().withExitCode(0).withMessage(DIGEST).endTerminated().endState()
                    .endContainerStatus().endStatus()
                    .build();
            client.pods().inNamespace(BUILD_NS).resource(pod).create();
        }
        job.setStatus(success
                ? new JobStatusBuilder().withSucceeded(1).build()
                : new JobStatusBuilder().withFailed(1).build());
        client.batch().v1().jobs().inNamespace(BUILD_NS).resource(job).updateStatus();
    }

    static Job onlyJob() {
        List<Job> jobs = client.batch().v1().jobs().inNamespace(BUILD_NS).list().getItems();
        assertThat(jobs).hasSize(1);
        return jobs.get(0);
    }

    static <T> T waitFor(Supplier<T> s) throws InterruptedException {
        Instant end = Instant.now().plus(Duration.ofSeconds(10));
        while (Instant.now().isBefore(end)) {
            T v = s.get();
            if (v != null) return v;
            Thread.sleep(100);
        }
        throw new AssertionError("10초 안에 안 생겼다");
    }

    @SuppressWarnings("unchecked")
    static Map<String, Object> map(Object o) {
        return (Map<String, Object>) o;
    }

    static String jsonString(String s) {
        return "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n") + "\"";
    }

    static String jsonField(String json, String field) {
        var m = java.util.regex.Pattern.compile("\"" + field + "\":\"([^\"]+)\"").matcher(json);
        return m.find() ? m.group(1) : null;
    }
}
