로드맵 위치: W1 D3 (10/7 분량, 10/6 진행) / preStop·롤아웃·롤백·HPA / 본선 연결점: "배포 중 무중단", "잘못된 배포 즉시 복구", "부하에 맞춰 자동 확장" 을 숫자로 보여 주는 데모 재료. 완성도·데모 30, 클라우드 활용 30.

# Lab 04 — preStop, 롤아웃/롤백, HPA

Lab 03 차트에 세 가지를 더한다.

| 단계 | 무엇 | 질문 |
|---|---|---|
| 1 | preStop | Lab 03 에서 남은 실패 3% 를 0 으로 만들 수 있나 |
| 2 | 이미지 버전 롤아웃 / 롤백 | 새 버전 배포, 잘못된 버전 배포 → 되돌리기까지 몇 초 |
| 3 | HPA | 부하가 오면 Pod 가 몇 초 만에 몇 개까지 늘고, 끝나면 언제 줄어드나 |

클러스터는 그대로 lab02 (kind) + Traefik.

## 용어

| 용어 | 한 줄 뜻 |
|---|---|
| preStop | Pod 를 끄기 직전에 실행하는 단계. 여기선 "N초 그냥 기다리기". 그 사이 Service 명단에서 빠진 사실이 Traefik 까지 퍼진다 |
| 롤백 | 바로 전(또는 지정한) 버전으로 되돌리기. `helm rollback` 은 Helm 기록까지 같이 되돌린다 |
| ImagePullBackOff | 이미지를 못 받아서 재시도 간격을 늘리며 기다리는 상태. 잘못된 태그를 배포했을 때 나온다 |
| metrics-server | 각 노드의 kubelet 에서 Pod CPU·메모리를 모아 주는 부품. `kubectl top` 과 HPA 가 이걸 본다 |
| HPA | "평균 CPU 가 목표치를 넘으면 Pod 를 늘리고, 내려가면 줄여" 를 자동으로 하는 컨트롤러 |

## 구조

```
labs/04-k8s-rollout-hpa/
├── chart/hello/
│   ├── values.yaml          preStop.sleepSeconds, autoscaling 추가
│   ├── values-demo.yaml     replicaCount: 3
│   ├── values-hpa.yaml      3단계용 (preStop 5s + HPA on)
│   └── templates/
│       ├── deployment.yaml  preStop 블록, HPA 켜면 replicas 줄 생략
│       └── hpa.yaml         새 파일
├── scripts/
│   ├── rollout-errors.sh    Lab 03 과 같음
│   ├── load.sh              클러스터 안 부하 Pod 띄우기/지우기
│   └── watch-hpa.sh         5초마다 HPA 상태 기록
└── results/                 *.log (git 제외)
```

## 진행 순서

모든 명령은 이 폴더에서: `cd labs/04-k8s-rollout-hpa`

### 0. Lab 04 차트로 갈아타기

```bash
git status | head -1                 # On branch main 인지
helm upgrade hello chart/hello -f chart/hello/values-demo.yaml
kubectl rollout status deployment/hello
```

### 1. preStop: 남은 3% 잡기

```bash
scripts/rollout-errors.sh prestop-0                         # 기준선 (Lab 03 과 같은 설정)
helm upgrade hello chart/hello -f chart/hello/values-demo.yaml --set preStop.sleepSeconds=5
kubectl rollout status deployment/hello
scripts/rollout-errors.sh prestop-5
```

### 2. 이미지 버전 롤아웃 → 잘못된 배포 → 롤백

```bash
# 같은 이미지에 v2 이름표만 붙여 kind 에 넣는다 (태그가 바뀌면 K8s 는 새 버전으로 본다)
docker tag lab01-hello:multi lab01-hello:v2
kind load docker-image lab01-hello:v2 --name lab02

helm upgrade hello chart/hello -f chart/hello/values-demo.yaml --set preStop.sleepSeconds=5 --set image.tag=v2
kubectl rollout status deployment/hello
kubectl rollout history deployment/hello

# 없는 태그 배포 (잘못된 배포 흉내)
helm upgrade hello chart/hello -f chart/hello/values-demo.yaml --set preStop.sleepSeconds=5 --set image.tag=broken
kubectl get pods                     # 새 Pod 1개가 ErrImagePull / ImagePullBackOff, 옛 Pod 3개는 그대로
curl -s localhost:8088/hello; echo   # 계속 응답하는지

time helm rollback hello             # 되돌리기 걸린 시간
kubectl get pods
helm history hello | tail -4
```

### 3. HPA

```bash
# metrics-server 설치. kind 의 kubelet 인증서는 자체 서명이라 --kubelet-insecure-tls 가 필요하다 (로컬 실습 전용)
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ && helm repo update
helm install metrics-server metrics-server/metrics-server -n kube-system --set 'args={--kubelet-insecure-tls}'
kubectl -n kube-system rollout status deployment/metrics-server
kubectl top pods                     # 1분쯤 지나야 숫자가 나온다

helm upgrade hello chart/hello -f chart/hello/values-demo.yaml -f chart/hello/values-hpa.yaml
kubectl get hpa hello                # TARGETS 가 cpu: x%/50%
```

터미널 탭 두 개:

```bash
# 탭 1
scripts/watch-hpa.sh load4

# 탭 2
scripts/load.sh start 4
# 탭 1 에서 Pod 가 늘어나는 걸 보고, 더 안 늘면
scripts/load.sh stop
# 탭 1 에서 줄어드는 걸 보고 Ctrl+C
```

## 측정표

| 항목 | 방법 | 결과 |
|---|---|---|
| preStop 0s, 롤아웃 중 실패 | 1단계 | 5/133 (4%): 000 ×3, 502 ×2. 롤아웃 16s |
| preStop 5s, 롤아웃 중 실패 / 롤아웃 시간 | 1단계 | **0/175 (0%)**, 롤아웃 15s (안 늘어남: 옛 Pod 가 기다리는 동안 다음 새 Pod 가 뜬다 【추정】) |
| 이미지 v2 롤아웃 시간 | 2단계 | 정상 완료 (시간 미측정) |
| 잘못된 태그 배포 중 curl | 2단계 | 새 Pod 1개 ErrImagePull, 롤링 멈춤, v2 Pod 3개가 계속 응답 (curl 정상) |
| `helm rollback` 시간 | 2단계 `time` | 명령 0.25s. 옛 Pod 를 안 껐으므로 서비스 중단 0 |
| 부하 시작 → 첫 scale up | 3단계 로그 | 부하 Pod 4개 시작 후 90s 안에 2 → 6 (정확한 시각은 미측정: 관찰을 늦게 시작) |
| 최대 Pod 수 / 그때 CPU% | 3단계 로그 | 6 (max) 에서 CPU 106~114% (목표 50%). 노드 1대라 Pod 를 늘려도 CPU 를 나눠 쓴다 【추정】 → Lab 06 에서 노드 2대로 재측정 |
| 부하 중지 → 2개로 돌아올 때까지 | 3단계 로그 | 약 75s: CPU 3% 까지 ~35s, desired 2 까지 +60s (stabilization), Pod 종료 +15s (preStop 5s 포함) |

## 핵심 결정 3개와 대안

1. **preStop = sleep 5s**
   - 대안: preStop 없음 (Lab 03, 약 3% 실패), 앱 쪽 graceful shutdown 만 (Spring 은 요청을 마무리하지만, Traefik 이 꺼지는 Pod 로 새 요청을 보내는 건 못 막는다)
   - 이유: 명단에서 빠진 사실이 Traefik 에 퍼지는 시간을 번다. 대가는 Pod 하나 끌 때마다 5s, 롤아웃 전체가 그만큼 길어진다
2. **롤백 = `helm rollback`** (`kubectl rollout undo` 아님)
   - 대안: `kubectl rollout undo` — Deployment 만 되돌리고 Helm 기록은 그대로라, 다음 `helm upgrade` 때 서로 어긋난다
   - 이유: 배포 도구가 하나(Helm)면 되돌리기도 같은 도구로
3. **HPA 기준 = CPU 50%, min 2 / max 6, 줄이기 대기 60s**
   - 대안: 메모리 기준 (JVM 은 메모리를 잘 안 돌려줘서 줄어들지 않는다 【추정】), 요청 수 기준 (Prometheus 어댑터 필요, 10/9 이후), KEDA (이벤트 기반, 0개까지 줄이기 가능)
   - 이유: 추가 부품 없이 metrics-server 만으로 된다. min 2 는 하나가 죽어도 응답하도록 (Lab 02 replicas 이유와 같음)

## 스스로 풀어 볼 문제 1개

HPA 를 켠 채로 `helm upgrade hello chart/hello -f chart/hello/values-demo.yaml` (values-hpa.yaml 빼고) 를 하면 Pod 수와 HPA 는 어떻게 될까? 예상 → 실행 → `kubectl get hpa,deploy` 로 확인.

## 검증 명령과 기대 출력

```bash
kubectl get deploy hello -o jsonpath='{.spec.template.spec.containers[0].lifecycle}'; echo   # {"preStop":{"sleep":{"seconds":5}}}
kubectl get hpa hello            # MINPODS 2, MAXPODS 6
kubectl top pods                 # CPU(cores), MEMORY(bytes)
helm history hello | tail -3
```
