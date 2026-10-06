로드맵 위치: W1 D3–D4 (10/7–10/8 분량, 10/6 진행) / 노드 여러 대 + 배치 규칙(taint·nodeSelector·PriorityClass) + 다중 서비스 / 본선 연결점: 본선 가설 "여러 환경에 배치·장애 조치", "공유 자원 위 우선순위 스케줄링" 의 가장 작은 버전. 셋업 드릴(10/11 게이트)의 출발점.

# Lab 05 — 노드 3대에서 "어디에 띄울지" 정하기

지금까지는 노드 1대라 "어디에" 를 고민할 필요가 없었다. 노드를 3대(컨트롤 플레인 1 + 워커 2)로 늘리고 네 가지를 해 본다.

1. **셋업 드릴**: 클러스터부터 앱 응답까지 스크립트 하나로, 시간 재기
2. **taint / toleration**: 배치 전용 노드에 일반 Pod 가 못 오게 막기
3. **PriorityClass**: 자리가 꽉 찼을 때 중요한 Pod 가 덜 중요한 Pod 를 밀어내기(선점)
4. **다중 서비스**: 같은 차트로 서비스 2개 (hello, hello2), Ingress 는 Host 로 나누고 서비스끼리는 이름으로 호출

## 용어

| 용어 | 한 줄 뜻 |
|---|---|
| 라벨 (node label) | 노드에 붙인 이름표. `tier=app` 처럼. Pod 는 nodeSelector 로 "이 이름표 노드에만" 을 고른다 |
| taint | 노드에 거는 출입 금지 표시. 허가(toleration)가 없는 Pod 는 그 노드에 못 온다 |
| toleration | Pod 쪽 허가증. "이 taint 는 괜찮아" |
| PriorityClass | Pod 의 중요도 숫자. 자리가 없으면 큰 숫자가 작은 숫자 Pod 를 쫓아내고(선점, preemption) 들어간다 |
| requests 로 자리 계산 | 스케줄러는 실제 사용량이 아니라 requests 합계로 "이 노드에 자리 있나" 를 본다 |
| topologySpreadConstraints | Pod 를 노드마다 고르게 나눠 놓으라는 규칙 |

## 구조

```
labs/05-k8s-scheduling/
├── kind-config.yaml        컨트롤 플레인 1 + 워커 2 (tier=app / tier=batch)
├── traefik-values.yaml     Lab 02 와 같음
├── scripts/
│   ├── setup.sh            셋업 드릴 (클러스터 → 이미지 → Traefik → metrics-server → hello)
│   └── fill-node.sh        노드 CPU 자리를 low Pod 로 채우기
├── k8s/
│   ├── priorityclasses.yaml   high(1000) / low(100)
│   └── batch-job.yaml         tier=batch 노드에서만 도는 Job
├── chart/hello/            Lab 04 차트 + priorityClassName, nodeSelector, tolerations, spreadAcrossNodes
└── results/
```

## 진행 순서

모든 명령은 이 폴더에서: `cd labs/05-k8s-scheduling`

### 1. 셋업 드릴 (lab02 지우고 lab05 새로)

```bash
kind delete cluster --name lab02        # 8088 포트를 쓰는 옛 클러스터를 지운다
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ 2>/dev/null; helm repo update
time scripts/setup.sh                    # 단계별 [Ns] 와 총 시간을 기록
```

`kubectl get pods -o wide` 의 NODE 칸을 본다. hello 3개가 워커 2대에 나뉘어 있을 것이다. 컨트롤 플레인에는 안 간다(컨트롤 플레인에도 기본 taint 가 있다: `kubectl describe node lab05-control-plane | grep Taints`).

### 2. taint: 배치 노드를 비우기

```bash
kubectl taint node lab05-worker2 dedicated=batch:NoSchedule   # 출입 금지 표시. 이미 있는 Pod 는 안 쫓아낸다
kubectl rollout restart deployment/hello && kubectl rollout status deployment/hello
kubectl get pods -o wide                 # hello 가 전부 lab05-worker 로
kubectl apply -f k8s/batch-job.yaml
kubectl get pods -o wide -l job-name=batch   # Job 은 toleration 이 있어서 lab05-worker2 로
kubectl logs -l job-name=batch --tail=1 --prefix
```

### 3. PriorityClass: 자리가 꽉 찼을 때

```bash
# hello 를 앱 노드에만, 중요도 high 로
helm upgrade hello chart/hello -f chart/hello/values-demo.yaml --set priorityClassName=high --set nodeSelector.tier=app
kubectl rollout status deployment/hello

scripts/fill-node.sh lab05-worker        # 앱 노드의 남은 CPU 자리를 low Pod 하나로 거의 다 채운다
kubectl describe node lab05-worker | grep -A6 "Allocated resources"   # cpu requests 99% 근처

# hello 를 5개로 늘린다. 새 Pod 2개가 들어갈 자리가 없다
helm upgrade hello chart/hello -f chart/hello/values-demo.yaml --set priorityClassName=high --set nodeSelector.tier=app --set replicaCount=5
kubectl get pods -o wide -w              # filler 가 Terminating → Pending, hello 5개 Running. 보고 Ctrl+C
kubectl get events --field-selector reason=Preempted
```

### 4. 다중 서비스: hello2

```bash
# 같은 차트, 다른 이름(릴리스)으로 하나 더. Ingress 는 Host 헤더가 hello2.local 인 요청만 받는다
helm install hello2 chart/hello --set ingress.host=hello2.local --set nodeSelector.tier=app
kubectl rollout status deployment/hello2

curl -s localhost:8088/hello; echo                          # Host 없음 → hello
curl -s -H "Host: hello2.local" localhost:8088/hello; echo  # → hello2
kubectl exec deploy/hello -- curl -s http://hello2/hello; echo   # 클러스터 안: 서비스 이름으로 바로 호출
```

### 5. 정리 (다음 Lab 06 은 이 클러스터를 그대로 쓴다)

```bash
scripts/fill-node.sh delete
kubectl delete job batch
helm uninstall hello2
helm upgrade hello chart/hello -f chart/hello/values-demo.yaml --set spreadAcrossNodes=true
kubectl get pods -o wide                 # hello 3개가 워커에 고르게
```

## 측정표

| 항목 | 방법 | 결과 |
|---|---|---|
| 셋업 드릴 총 시간 (클러스터 → 응답) | 1단계 `time` | |
| 그중 클러스터 생성 / Traefik / metrics-server / hello | 1단계 `[Ns]` 로그 | |
| 노드 3대 클러스터 메모리 (K8s 부품 합) | `docker stats --no-stream` | |
| taint 후 hello 위치 | 2단계 | |
| 선점: replicas 5 적용 → 5개 Running 까지 | 3단계 `-w` | |
| 선점된 Pod | 3단계 events | |
| hello2 호출 (Ingress / 서비스 이름) | 4단계 | |

## 핵심 결정 3개와 대안

1. **노드 역할을 라벨 + taint 로 나눈다**
   - 대안: 네임스페이스만 나누기 (논리적 구분일 뿐 같은 노드를 나눠 씀), 노드 친화성 affinity (nodeSelector 보다 표현력이 큼: "가능하면 여기" 같은 선호도 가능)
   - 이유: 가장 단순하고, 본선의 "환경별 배치" 를 "이 이름표 노드로" 로 바로 보여 줄 수 있다. 다음 단계는 affinity 의 선호도 점수
2. **선점은 high(1000) / low(100) 두 단계, low 는 `preemptionPolicy: Never`**
   - 대안: 우선순위 없이 ResourceQuota 로 팀별 상한만 두기, 클러스터 오토스케일러로 노드를 늘리기 (클라우드 전용)
   - 이유: 노드를 늘릴 수 없는 공유 자원(온프레, 로컬)에서는 "누구를 먼저 살릴까" 가 유일한 답. 대가는 배치 작업이 밀려나 늦어진다
3. **다중 서비스 = 같은 차트 2릴리스, Host 기반 라우팅**
   - 대안: Path 기반 (`/a`, `/b`. Traefik StripPrefix 미들웨어 필요), 서비스마다 차트 따로
   - 이유: 차트 하나를 값만 바꿔 재사용하는 게 Helm 의 핵심. 한계: 진짜 다중 서비스(API + DB 등 서로 다른 앱)는 아니다. 예선 앱 이식은 W2 이후
   - 【사실】 예선 레포의 다중 서비스 앱은 이번 Lab 에서 다루지 않는다 (로드맵 원문 대비 축소)

## 스스로 풀어 볼 문제 1개

3단계에서 hello 의 `priorityClassName=high` 를 빼고 replicas 5 를 적용하면 어떻게 될까? (힌트: 새 Pod 의 STATUS 와 `kubectl describe pod` 의 Events 메시지 `Insufficient cpu`)

## 검증 명령과 기대 출력

```bash
kubectl get nodes -L tier                    # control-plane, worker(tier=app), worker2(tier=batch)
kubectl describe node lab05-worker2 | grep Taints    # dedicated=batch:NoSchedule
kubectl get priorityclass high low
kubectl get pods -o wide                     # hello 3개 Running, NODE 가 워커
curl -s localhost:8088/hello; echo
```
