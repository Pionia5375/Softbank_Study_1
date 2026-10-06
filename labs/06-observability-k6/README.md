로드맵 위치: W1 D5–D6 (10/9–10/10 분량, 10/6 진행) / P0-2 측정 루프: kube-prometheus-stack + Loki + Grafana Alloy + k6, PromQL 5개, 튜닝 전/후 p95 / 본선 연결점: "그 성능 주장은 무엇으로 쟀나? 조건과 p95는?" 질문에 대시보드와 표 한 장으로 답하는 재료. 완성도·데모 30, 클라우드 활용 30.

# Lab 06 — 관측(지표·로그) + k6 로 p95 재기

지금까지는 `curl` 반복과 `kubectl top` 으로 쟀다. 이번엔 "부하를 일정하게 넣고 → 지표와 로그를 모으고 → p95 를 표로" 의 고리를 한 번 끝까지 돌린다.

| 단계 | 무엇 | 질문 |
|---|---|---|
| 1–2 | Prometheus + Grafana, Traefik 지표 | 요청 수·에러율·지연·CPU·메모리를 한 화면에서 볼 수 있나 |
| 3 | Loki + Alloy | 같은 화면에서 hello 로그도 보이나 |
| 4–5 | k6 | 1초에 N개를 일정하게 보낼 때 p50/p95/p99 와 에러율은 |
| 6 | 튜닝 전/후 | replicas 1 vs 3, CPU limit 없음 vs 500m 에서 p95 가 어떻게 바뀌나 (Lab 02 의 "노드 하나에서 분산이 의미 있나" 질문) |
| 7 | 비용 | 관측 스택 자체가 메모리를 얼마나 먹나 |

출발 상태 = Lab 05 클러스터 그대로: kind `lab05` (control-plane 1 + worker 2), Traefik(`traefik` 네임스페이스, NodePort 30080 ← Mac 8088), hello 3개(Lab 05 차트 + values-demo.yaml, preStop 5s), metrics-server.
앱은 고치지 않는다. 지표는 Traefik(앞단)과 kubelet/cAdvisor·kube-state-metrics(뒷단)에서 얻는다.

## 용어

| 용어 | 한 줄 뜻 |
|---|---|
| Prometheus | 정해진 주소(`/metrics`)를 15초마다 긁어서 숫자를 시간순으로 쌓는 DB |
| kube-prometheus-stack | Prometheus + Grafana + kube-state-metrics + node-exporter + Operator 를 한 번에 까는 Helm 차트 |
| Prometheus Operator | `ServiceMonitor` 같은 K8s 파일을 보고 Prometheus 설정을 대신 써 주는 컨트롤러 |
| ServiceMonitor | "이 Service 의 이 포트를 긁어라" 를 적은 K8s 리소스 |
| cAdvisor | kubelet 안에 들어 있는 컨테이너 CPU·메모리 측정기. `container_*` 지표의 출처 |
| kube-state-metrics | K8s API 를 보고 "requests 가 얼마, Pod 가 몇 개 준비됨" 같은 설정·상태를 숫자로 내놓는 부품 |
| node-exporter | 노드(여기선 kind 컨테이너) 단위 CPU·메모리·디스크 측정기. 노드마다 1개 |
| Grafana | Prometheus·Loki 에 질의해서 그래프로 그려 주는 화면 |
| Loki | 로그 저장소. 본문은 그대로 두고 라벨(namespace, pod, app)로만 색인해서 가볍다 |
| Grafana Alloy | 로그·지표를 모아 보내는 수집기. Promtail 후속 (Promtail 은 2026-03-02 지원 종료) |
| k6 | JavaScript 로 시나리오를 쓰는 부하 도구 |
| arrival rate (도착률) | "1초에 N개 요청을 시작한다" 로 부하를 고정. 서버가 느려져도 보내는 양이 줄지 않는다 |
| p95 | 요청을 빠른 순으로 줄 세웠을 때 95% 지점의 시간. "100명 중 95명은 이 안에 받는다" |
| 히스토그램 | "5ms 이하 몇 개, 10ms 이하 몇 개..." 칸별 개수. Prometheus 는 이걸로 p95 를 근사한다 |
| working set | 컨테이너 메모리 중 커널이 당장 못 돌려받는 부분. OOMKilled 판정 기준 |
| throttling | CPU limit 을 다 쓴 컨테이너를 100ms 주기의 남은 시간 동안 멈춰 두는 것. 응답이 느려진다 |

## 구조

```
labs/06-observability-k6/
├── values/
│   ├── kps-values.yaml              kube-prometheus-stack 다이어트 (alertmanager 끔, 보관 1d, 작은 requests)
│   ├── traefik-metrics-values.yaml  Traefik 에 metrics Service + ServiceMonitor + 촘촘한 히스토그램 칸
│   ├── loki-values.yaml             Loki 단일 프로세스 + 파일 저장 2Gi, 캐시 끔
│   └── alloy-values.yaml            Alloy 1개, Pod 로그 → Loki
├── k6/hello.js                      도착률 고정 부하 + p50/p95/p99/에러율 요약 (TODO(human) 1곳: RPS)
├── scripts/
│   ├── k6-run.sh                    k6 를 클러스터 안 Pod 로 실행, 결과 + Pod 수·CPU 최댓값
│   ├── load-dashboard.sh            대시보드 JSON → ConfigMap (Grafana 가 자동으로 읽음)
│   └── stack-mem.sh                 네임스페이스별 메모리 합, kind 노드 docker stats
├── dashboards/hello-dashboard.json  PromQL 5개 + Pod 수 + Loki 로그 패널
├── promql.md                        PromQL 5개와 한 줄 설명
└── results/                         *.log (git 제외)
```

차트 버전 (2026-10-06 기준 최신, 각 저장소 gh-pages `index.yaml` 에서 확인):

| 차트 | 버전 (앱 버전) | Helm 저장소 |
|---|---|---|
| prometheus-community/kube-prometheus-stack | 91.9.0 (Operator v0.94.1, 안에 grafana 13.2.7 / kube-state-metrics 8.6.0 / node-exporter 4.59.0) | https://prometheus-community.github.io/helm-charts |
| grafana-community/loki | 18.13.8 (Loki 3.7.8) | https://grafana-community.github.io/helm-charts |
| grafana/alloy | 1.13.0 (Alloy v1.20.0) | https://grafana.github.io/helm-charts |
| traefik/traefik | Lab 05 에 설치된 그대로 (41.x, Traefik v3.7) | https://traefik.github.io/charts |
| k6 이미지 | grafana/k6:2.3.0 | Docker Hub |

values 4개는 위 버전 차트에 `helm template` / `helm lint` (helm v4.2.3) 로 렌더링까지 확인했다 (Service 이름 kps-prometheus, kps-grafana, loki, traefik-metrics 도 렌더링 결과 기준). Alloy 설정은 `alloy validate` (v1.20.0), k6 스크립트는 k6 2.3.0 으로 로컬 HTTP 서버에 돌려 봤다. 실제 kind 클러스터 적용은 아직 안 해 봤다 【미확인】.

Loki 주의: OSS Loki 차트는 2026-03-16 부터 `grafana-community` 로 옮겨졌다. 블로그 글에 나오는 `grafana/loki` 는 이제 엔터프라이즈용이다 【사실: grafana/loki 저장소 production/helm/loki/README.md】.

## 진행 순서

모든 명령은 이 폴더에서: `cd labs/06-observability-k6`

### 0. 출발 상태 확인 + 메모리 기준선

```bash
kubectl config current-context        # kind-lab05 인지
kubectl get nodes                     # 3개 Ready
kubectl get pods -o wide              # hello 3개 Running, 어느 worker 에 있는지
kubectl get hpa 2>/dev/null           # 아무것도 없어야 한다 (HPA 가 있으면 6단계의 replicas 설정을 HPA 가 덮어씀)
curl -s localhost:8088/hello; echo    # Mac → Traefik → hello 길이 살아 있는지
scripts/stack-mem.sh before           # 관측 스택 깔기 전 메모리. results/mem-before.log
```

### 1. kube-prometheus-stack 설치

```bash
# 차트 저장소 3개 등록 (traefik 은 Lab 05 에서 이미 등록)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add grafana-community https://grafana-community.github.io/helm-charts
helm repo update

# 고정한 버전이 저장소에 있는지 확인 (첫 줄에 91.9.0 이 보이면 OK)
helm search repo prometheus-community/kube-prometheus-stack --versions | head -3

# 설치. monitoring 네임스페이스를 같이 만든다. CRD 가 커서 1~3분 걸린다
time helm install kps prometheus-community/kube-prometheus-stack --version 91.9.0 \
  -n monitoring --create-namespace -f values/kps-values.yaml

# 다 뜰 때까지 지켜보기 (Ctrl+C 로 빠져나옴). prometheus-kps-prometheus-0 이 2/2 가 되면 끝
kubectl -n monitoring get pods -w
```

### 2. Traefik 지표를 Prometheus 에 연결

```bash
# 지금 설치된 Traefik 차트 버전 읽기 (같은 버전으로 upgrade 해야 값만 바뀐다)
TRAEFIK_VER=$(helm list -n traefik -o yaml | sed -n 's/^ *chart: traefik-//p'); echo "$TRAEFIK_VER"

# 값 얹기. --reuse-values = Lab 05 때 준 값(NodePort 30080 등)은 그대로
helm upgrade traefik traefik/traefik -n traefik --version "$TRAEFIK_VER" \
  --reuse-values -f values/traefik-metrics-values.yaml
kubectl -n traefik rollout status deployment/traefik    # 히스토그램 칸이 바뀌어서 Traefik Pod 가 한 번 재시작된다

kubectl -n traefik get servicemonitor,svc               # ServiceMonitor traefik, Service traefik-metrics(9100) 가 생겼는지
curl -s localhost:8088/hello; echo                       # 재시작 뒤에도 8088 이 살아 있는지
```

Prometheus 가 실제로 긁는지 확인. **새 터미널 탭**에서 port-forward 를 켜 둔다 (Mac 에 열린 포트는 8088 하나뿐이라, 나머지는 port-forward 로 잠깐 연다):

```bash
# 탭 2: Mac 의 9090 → Prometheus Service 9090. 켜 둔 동안만 유지된다
kubectl -n monitoring port-forward svc/kps-prometheus 9090:9090
```

```bash
# 탭 1: up = 마지막 긁기가 성공했으면 1
curl -s 'localhost:9090/api/v1/query' --data-urlencode 'query=up{namespace="traefik"}' ; echo
# hello 로 간 요청이 쌓이는지 (curl 몇 번 보낸 뒤). service 라벨 값을 여기서 확인해 둔다
for i in $(seq 20); do curl -s -o /dev/null localhost:8088/hello; done
curl -s 'localhost:9090/api/v1/query' --data-urlencode 'query=count by (service) (traefik_service_requests_total)'; echo
```

### 3. Loki + Alloy (로그)

```bash
# Loki: 프로세스 하나, 파일 저장 2Gi
helm install loki grafana-community/loki --version 18.13.8 -n monitoring -f values/loki-values.yaml
# Alloy: Pod 로그를 K8s API 로 읽어 Loki 로 보내는 수집기 1개
helm install alloy grafana/alloy --version 1.13.0 -n monitoring -f values/alloy-values.yaml

kubectl -n monitoring rollout status statefulset/loki
kubectl -n monitoring rollout status deployment/alloy
kubectl -n monitoring get pvc                            # loki 용 PVC 1개가 Bound 2Gi
kubectl -n monitoring logs deploy/alloy -c alloy --tail=20   # level=error 가 계속 나오지 않는지
```

### 4. Grafana 열기 + 대시보드 올리기

```bash
# 탭 3: Mac 의 3000 → Grafana Service 80
kubectl -n monitoring port-forward svc/kps-grafana 3000:80
```

```bash
# 탭 1: 데이터소스 2개(prometheus, loki) 가 있는지
curl -s -u admin:admin localhost:3000/api/datasources | grep -o '"uid":"[a-z]*"'
# 대시보드 JSON → ConfigMap. Grafana 옆 sidecar 가 grafana_dashboard=1 라벨을 보고 자동으로 올린다
scripts/load-dashboard.sh
```

브라우저 http://localhost:3000 (admin / admin) → Dashboards → **Lab 06 hello**. Explore → Loki 에서 `{namespace="default", app="hello"}` 로 Spring 기동 로그가 보이는지도 본다.

### 5. k6 한 번 돌려 보기 (스모크)

TODO(human): `k6/hello.js` 의 `RATE` (1초당 요청 수) 를 정한다. 추천 기본값 200, 이유는 파일 주석.

```bash
# 30초짜리로 먼저 길이 뚫렸는지만 본다. k6 Pod 가 뜨고(이미지 첫 다운로드 1분쯤) → 몸풀기 20s → 본측정 30s → 요약
scripts/k6-run.sh smoke traefik 50 30s
```

마지막에 `RESULT | ... |` 와 `TOP | ...` 두 줄이 나오면 성공. Grafana 대시보드에서도 RPS 50 근처 선이 생긴다.

### 6. 튜닝 전/후: replicas × CPU limit

같은 RPS 로 네 조건을 잰다. 각 2분 + 몸풀기 20초. 조건 바꾸기 → 롤아웃 끝 확인 → k6 순서.

```bash
CHART=../05-k8s-scheduling/chart/hello     # Lab 05 차트 (values-demo.yaml 에 preStop 5s 포함)

# A1. replicas 1, CPU limit 없음
helm upgrade hello $CHART --reuse-values --set replicaCount=1
kubectl rollout status deployment/hello
scripts/k6-run.sh a1-r1

# A2. replicas 3, CPU limit 없음 (= Lab 05 상태)
helm upgrade hello $CHART --reuse-values --set replicaCount=3
kubectl rollout status deployment/hello
scripts/k6-run.sh a2-r3

# B1. replicas 1, CPU limit 500m (Pod 하나가 CPU 0.5개까지만)
#   200m 은 피한다: Spring 기동이 느려져 liveness(20s + 10s×3) 안에 못 뜨고 재시작될 수 있다 【추정】
helm upgrade hello $CHART --reuse-values --set replicaCount=1 --set resources.limits.cpu=500m
kubectl rollout status deployment/hello --timeout=3m
scripts/k6-run.sh b1-r1-cpu500

# B2. replicas 3, CPU limit 500m
helm upgrade hello $CHART --reuse-values --set replicaCount=3 --set resources.limits.cpu=500m
kubectl rollout status deployment/hello --timeout=3m
scripts/k6-run.sh b2-r3-cpu500
```

각 실행 중 Grafana 의 3번(p95)·4번(CPU ÷ requests) 패널을 같이 본다. 실행 끝의 `RESULT` / `TOP` 줄을 아래 표에 옮긴다. B 조건에서는 `promql.md` 의 "덤" throttling 쿼리도 Prometheus 에 붙여 본다.

다 끝나면 Lab 05 상태로 되돌린다:

```bash
helm upgrade hello $CHART -f $CHART/values-demo.yaml
kubectl rollout status deployment/hello
kubectl get deploy hello -o jsonpath='{.spec.template.spec.containers[0].resources}'; echo   # limits 에 cpu 가 없어야 함
```

### 7. 관측 스택의 메모리 비용

```bash
scripts/stack-mem.sh after            # results/mem-after.log
diff results/mem-before.log results/mem-after.log | head -40
```

`monitoring` 합계와, docker stats 의 kind 노드 3개 합이 0단계보다 얼마 늘었는지를 표 마지막 줄에 적는다.

## 측정표

RPS = k6 가 실제로 보낸 1초당 요청 수 (목표 RATE 와 같아야 정상, 모자라면 `dropped` 를 본다). p50/p95/p99 = k6 가 잰 값 (k6 Pod → Traefik → hello 왕복). 최대 Pod 수·CPU = `TOP` 줄 (10초마다 `kubectl top` 중 최댓값).

| 조건 | RPS | p50 | p95 | p99 | 에러율 | 최대 Pod 수 | CPU (합 / Pod 당 최대) |
|---|---|---|---|---|---|---|---|
| smoke (50 RPS, 30s) | | | | | | | |
| A1 replicas 1, CPU limit 없음 | | | | | | | |
| A2 replicas 3, CPU limit 없음 | | | | | | | |
| B1 replicas 1, CPU limit 500m | | | | | | | |
| B2 replicas 3, CPU limit 500m | | | | | | | |
| 관측 스택 메모리 (`monitoring` 합 / kind 노드 증가분) | — | — | — | — | — | — | |

| 항목 | 방법 | 결과 |
|---|---|---|
| kube-prometheus-stack 설치 시간 | 1단계 `time` | |
| 같은 구간의 Traefik p95 (Grafana 3번 패널) vs k6 p95 | 6단계 A2 | |
| Loki 에서 hello 로그가 보이기까지 | 3–4단계 | |

읽는 법 (실험 전 가설, 결과를 보고 고친다):

- kind 의 worker 2개는 같은 Docker VM 위의 컨테이너라 CPU 16개를 나눠 쓴다. CPU limit 이 없으면 Pod 1개도 CPU 를 여러 개 쓸 수 있어서 A1 과 A2 의 p95 차이는 작을 것이다 【추정】. 이 경우 replicas 3 의 이득은 "빨라짐" 이 아니라 "하나 죽어도 응답" (Lab 02) 이다.
- CPU limit 이 걸리면 Pod 1개의 처리량에 천장이 생긴다. B1 에서 p95·p99 가 크게 늘고, B2 에서 다시 줄어들면 "Pod 당 자원이 묶여 있을 때 분산이 효과가 있다" 는 증거가 된다 【추정】.
- k6 p95 와 Traefik p95 는 다르다. k6 는 k6 → Traefik 구간까지 포함하고, Traefik 쪽은 히스토그램 칸 사이를 직선으로 짐작한 값이다.
- k6 Pod 도 같은 VM 의 CPU 를 쓴다. 부하를 만드는 쪽이 재는 대상의 CPU 를 빼앗는 구조라, 아주 높은 RPS 에선 결과가 흐려진다.

## 핵심 결정 3개와 대안

1. **k6 를 클러스터 안 Pod 로 (`kubectl run ... k6 run -`), 대상은 Traefik Service**
   - 대안 A: Mac 에 `brew install k6` 후 `localhost:8088` 로. 설치가 쉽고 "사용자 입장" 에 가깝지만, Mac → Docker Desktop 포트 전달 → kind 노드 → NodePort 를 거쳐서 그 구간의 흔들림이 p95 에 섞인다
   - 대안 B: k6 Operator (`TestRun` CRD 로 여러 Pod 에 나눠 실행). 큰 부하엔 맞지만 부품이 하나 더 늘고, 지금 RPS 엔 필요 없다
   - 이유: 재는 길이 "Traefik → Service → Pod" 로 짧고 반복해도 같다. 스크립트를 stdin 으로 넘겨서 ConfigMap 도 필요 없다. 대가: 부하 Pod 가 같은 VM CPU 를 쓴다, Mac 에서 들어오는 실제 경로는 안 잰다 (`k6-run.sh` 에 `direct` 모드를 둬서 Traefik 을 뺀 값과 비교는 가능)
2. **부하 모델 = `constant-arrival-rate` (1초에 N개 고정) + 몸풀기 20초 제외**
   - 대안: `constant-vus` (가상 사용자 N명이 응답 받자마자 다음 요청). 서버가 느려지면 보내는 양도 같이 줄어서, 느려진 만큼이 p95 에 덜 드러난다
   - 이유: 조건만 바꾸고 부하는 똑같이 둬야 전/후 비교가 된다. JVM 은 막 뜬 직후(JIT 전) 느려서 그 구간을 빼야 롤아웃 직후 측정이 공정하다. 대가: 서버가 못 버티면 k6 가 VU 를 계속 늘려 k6 자신이 무거워진다 (`maxVUs: 400` 에서 멈추고 `dropped` 로 표시)
3. **앱 지표는 Traefik + cAdvisor/kube-state-metrics 로 (앱 수정 없음)**
   - 대안: Spring Boot Actuator + Micrometer 로 `/actuator/prometheus` 를 열기. 엔드포인트별 지연, JVM 힙·GC·스레드까지 보이지만 의존성 추가 → 이미지 다시 빌드 → `kind load` 가 필요하다. 다중 서비스 앱(스타터 킷)에선 이쪽으로 가는 게 맞다 【추정】
   - 이유: 오늘 목표는 측정 고리를 한 바퀴 돌리는 것. Traefik 은 모든 요청이 지나가는 곳이라 RPS·에러율·지연을 앱 손대지 않고 얻는다. 대가: Traefik 을 거치지 않는 요청(`direct`, Pod 끼리 호출)은 안 보인다. 지연 정밀도는 히스토그램 칸에 묶인다 (그래서 칸을 4개 → 10개로 늘림)

로그 쪽 선택 (Loki 단일 프로세스 + Alloy 1개, `loki.source.kubernetes`)의 이유와 대안은 `values/loki-values.yaml`, `values/alloy-values.yaml` 맨 위 주석에 적었다. 요약: Promtail 은 지원 종료, ELK/OpenSearch 는 JVM 이라 GB 단위로 무겁다. 운영 환경 표준은 Alloy DaemonSet 이 노드의 `/var/log/pods` 파일을 직접 읽는 방식이다.

## 스스로 풀어 볼 문제 1개

B1 조건(replicas 1, CPU limit 500m)에 Lab 04 의 HPA(`values-hpa.yaml`, min 2 / max 6, CPU 50%)를 켜고 같은 k6 를 3분 돌리면, p95 는 B1 과 B2 중 어느 쪽에 가까울까? 그리고 Pod 가 늘어나는 동안의 p99 는? 예상을 먼저 적고 → `helm upgrade hello $CHART --reuse-values -f $CHART/values-hpa.yaml --set resources.limits.cpu=500m` → `scripts/k6-run.sh hpa traefik 200 3m` → 대시보드 6번 패널(Pod 수)과 3번 패널(p95)을 시간축으로 맞춰 본다. (힌트: HPA 는 15초마다 판단하고, 새 Pod 는 readiness 통과까지 몇 초 걸린다. 그 사이 요청은 누가 받나)

## 검증 명령과 기대 출력

```bash
helm list -A                                    # kps / loki / alloy 가 monitoring 에 deployed, traefik revision +1
kubectl -n monitoring get pods                  # 전부 Running. prometheus-kps-prometheus-0 2/2, loki-0 2/2, kps-grafana-... 3/3
                                                # alloy-... 2/2, node-exporter 3개(노드마다), alertmanager 없음
kubectl -n traefik get servicemonitor traefik   # 있음
curl -s 'localhost:9090/api/v1/query' --data-urlencode 'query=up{namespace="traefik"}' | grep -o '"value":\[[^]]*\]'
                                                # "value":[<시각>,"1"]   (탭 2 port-forward 필요)
kubectl -n monitoring port-forward svc/loki 3100:3100 &   # 잠깐 열기
curl -s localhost:3100/ready                    # ready
curl -s localhost:3100/loki/api/v1/labels       # "app","container","namespace","pod" 가 보임
kill %1
curl -s -u admin:admin 'localhost:3000/api/search?query=Lab%2006' | grep -o '"title":"[^"]*"'
                                                # "title":"Lab 06 hello"   (탭 3 port-forward 필요)
ls results/                                     # k6-*.log, top-*.log, mem-before.log, mem-after.log
```

정리 (메모리를 돌려받고 싶을 때. 다음 Lab 에서 또 쓸 거면 두기):

```bash
helm uninstall alloy loki kps -n monitoring
kubectl delete ns monitoring
```
