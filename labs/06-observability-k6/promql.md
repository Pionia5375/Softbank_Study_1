# PromQL 5개

Prometheus UI (`kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090` → http://localhost:9090) 나 Grafana Explore 에 붙여 넣어 본다.

먼저 알아 둘 것 두 개:

- `rate(x[1m])` = 카운터(계속 늘기만 하는 숫자)가 최근 1분 동안 **1초에 평균 몇씩** 늘었나. 15초마다 긁으니 1분 창 안에 점 4개가 들어간다
- Traefik 의 `service` 라벨 값은 `<네임스페이스>-<서비스이름>-<포트>@kubernetes` 모양이다 【추정: Ingress provider 이름 규칙】. 그래서 `service=~"default-hello-.*"` 로 고른다. 실제 값은 아래로 먼저 확인:

```promql
count by (service) (traefik_service_requests_total)
```

지표 이름 출처:
- Traefik: `traefik_service_requests_total`, `traefik_service_request_duration_seconds` (Histogram, 라벨 code/method/protocol/service) 【사실: https://github.com/traefik/traefik/blob/v3.7/docs/content/reference/install-configuration/observability/metrics.md】
- cAdvisor: `container_cpu_usage_seconds_total`, `container_memory_working_set_bytes`, `container_cpu_cfs_throttled_periods_total` 【사실: https://github.com/google/cadvisor/blob/master/docs/storage/prometheus.md】
- kube-state-metrics: `kube_pod_container_resource_requests`, `kube_pod_container_resource_limits` (라벨 resource, unit), `kube_deployment_status_replicas_available` 【사실: https://github.com/kubernetes/kube-state-metrics/tree/main/docs/metrics/workload】

---

## 1. 서비스별 요청 수 (RPS)

```promql
sum by (service) (rate(traefik_service_requests_total{service=~"default-hello-.*"}[1m]))
```

Traefik 이 hello 로 넘긴 요청이 1초에 몇 개인지. k6 의 RATE 와 거의 같아야 한다 (다르면 k6 가 목표를 못 채웠거나 `direct` 모드로 돌린 것).

## 2. 에러율 (5xx 비율)

```promql
  (sum(rate(traefik_service_requests_total{service=~"default-hello-.*", code=~"5.."}[1m])) or vector(0))
/
  sum(rate(traefik_service_requests_total{service=~"default-hello-.*"}[1m]))
```

전체 요청 중 5xx(서버 쪽 실패)의 비율. 0.01 = 1%. 5xx 가 하나도 없으면 분자가 "빈 결과" 가 되어 그래프가 끊기므로 `or vector(0)` 으로 0 을 채운다.

## 3. p95 지연 시간

```promql
histogram_quantile(0.95,
  sum by (le) (rate(traefik_service_request_duration_seconds_bucket{service=~"default-hello-.*"}[1m])))
```

최근 1분 요청 중 95% 가 이 시간(초) 안에 끝났다. `_bucket` 은 "0.005초 이하 몇 개, 0.01초 이하 몇 개..." 칸별 누적 개수이고, `le` 는 그 칸의 경계. 칸 사이 값은 직선으로 짐작하므로 칸이 성기면 부정확하다 (그래서 `traefik-metrics-values.yaml` 에서 칸을 10개로 늘렸다). 0.5 / 0.99 로 바꾸면 p50 / p99.

## 4. Pod CPU 사용량 ÷ requests

```promql
  sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="default", container="hello"}[1m]))
/
  sum by (pod) (kube_pod_container_resource_requests{namespace="default", container="hello", resource="cpu"})
```

Pod 마다 "신고한 CPU(100m) 의 몇 배를 쓰고 있나". 1 = 100%. HPA 의 CPU% 와 같은 계산이다 (HPA 는 metrics-server 값을 쓰지만 출처는 같은 kubelet/cAdvisor). CPU limit 이 없으면 1 을 훌쩍 넘을 수 있다.

## 5. Pod 메모리(working set) ÷ limit

```promql
  sum by (pod) (container_memory_working_set_bytes{namespace="default", container="hello"})
/
  sum by (pod) (kube_pod_container_resource_limits{namespace="default", container="hello", resource="memory"})
```

Pod 마다 "메모리 상한(512Mi) 의 몇 % 를 쓰나". working set = 커널이 당장 돌려받을 수 없는 메모리. 이게 상한에 닿으면 OOMKilled 다 (Lab 03). 1 에 가까워지면 위험.

---

## 덤 (실험 해석용, 5개에 안 셈)

```promql
# CPU 제한에 걸려 멈춘 비율. 0.3 = 100ms 주기 중 30% 에서 "CPU 다 썼으니 기다려" 를 당함
  sum by (pod) (rate(container_cpu_cfs_throttled_periods_total{namespace="default", container="hello"}[1m]))
/
  sum by (pod) (rate(container_cpu_cfs_periods_total{namespace="default", container="hello"}[1m]))

# 응답 가능한 hello Pod 수
kube_deployment_status_replicas_available{namespace="default", deployment="hello"}

# 관측 스택 자체의 메모리 (MiB)
sum by (pod) (container_memory_working_set_bytes{namespace="monitoring", container!=""}) / 1024 / 1024
```

`container!=""` 는 cAdvisor 가 Pod 전체 합계 줄(container="")도 같이 내기 때문에, 그걸 빼서 두 번 세지 않으려는 것.
