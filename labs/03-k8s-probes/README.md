로드맵 위치: W1 D2 (10/6, 10/7 분량 선행) / probe와 resources / 본선 연결점: 장애 조치·스케일 데모에서 "Pod가 바뀌는 순간에도 요청이 안 끊긴다"를 숫자로 보여 주는 바탕. 완성도·데모 30점.

# Lab 03 — probe와 resources: Pod 교체 중 끊기는 요청 0개로 만들기

Lab 02 에서 찾은 구멍 두 개를 메운다.

1. Pod 가 뜨자마자 READY 1/1 이 되지만 Spring 은 4~5초 뒤에야 응답한다. 그 사이 들어온 요청은 실패한다 → **readinessProbe**
2. Pod 가 메모리를 얼마나 써도 되는지 정해 두지 않았다 → **resources (requests / limits)**

Lab 02 의 kind 클러스터(lab02)와 Traefik 을 그대로 쓴다. 차트는 Lab 02 것을 복사해 probe·resources 만 더했다.

## 용어

| 용어 | 한 줄 뜻 |
|---|---|
| readinessProbe | kubelet 이 주기적으로 `/health` 를 불러 본다. 실패하면 그 Pod 를 Service 명단(endpoints)에서 뺀다. 재시작은 안 한다 |
| livenessProbe | 같은 검사인데, 연속으로 실패하면 컨테이너를 **재시작**한다. "멈춰 버린 앱 살리기" 용 |
| requests | "이 Pod 는 최소 이만큼 쓴다" 는 신고. 스케줄러가 노드 자리를 고를 때 이 값으로 계산한다 |
| limits | 상한. 메모리가 넘으면 커널이 컨테이너를 죽인다(OOMKilled). CPU 가 넘으면 느려진다(죽진 않음) |
| 롤아웃 | Deployment 의 Pod 를 새 것으로 하나씩 갈아 끼우는 것. `kubectl rollout restart` 로 일부러 일으킬 수 있다 |

## 구조

```
labs/03-k8s-probes/
├── chart/hello/
│   ├── Chart.yaml              version 0.2.0
│   ├── values.yaml             probes / resources 추가, TODO(human) 3곳
│   ├── values-demo.yaml        replicaCount: 3 (Lab 02 그대로)
│   └── templates/deployment.yaml   probe·resources 블록 추가 ("Lab 03" 주석)
├── scripts/rollout-errors.sh   롤아웃 중 실패한 요청 수 세기
└── results/                    *.log (git 제외)
```

## 진행 순서

모든 명령은 이 폴더에서: `cd labs/03-k8s-probes`

### 0. 출발 상태 맞추기

```bash
kubectl get pods -n traefik                                   # Traefik Running
helm upgrade hello chart/hello -f chart/hello/values-demo.yaml # Lab 03 차트로 갈아타기 (probe 아직 off)
kubectl get pods                                              # hello 3개 Running
```

### 1. probe 없이 롤아웃 → 실패 수 재기 (기준선)

```bash
scripts/rollout-errors.sh no-probe
```

### 2. readinessProbe / livenessProbe 켜기

TODO(human): `values.yaml` 의 `probes.readiness.periodSeconds`, `probes.liveness.initialDelaySeconds` 를 채우고 `enabled: true`.

```bash
helm upgrade hello chart/hello -f chart/hello/values-demo.yaml
kubectl get pods -w                  # 이번엔 READY 0/1 → 1/1 까지 몇 초 걸리는지 본다
scripts/rollout-errors.sh probe
```

### 3. 일부러 망가뜨리기: liveness 를 너무 빡빡하게

```bash
helm upgrade hello chart/hello -f chart/hello/values-demo.yaml \
  --set probes.liveness.initialDelaySeconds=1 --set probes.liveness.periodSeconds=1 --set probes.liveness.failureThreshold=1
kubectl get pods -w                  # RESTARTS 가 계속 오르는지
kubectl describe pod <이름> | tail -15   # Events 에 "Liveness probe failed" 가 보이는지
helm rollback hello                  # 원래대로
```

### 4. resources: 메모리 상한

```bash
# 너무 작은 상한부터
helm upgrade hello chart/hello -f chart/hello/values-demo.yaml --set resources.limits.memory=128Mi
kubectl get pods -w                  # STATUS 에 OOMKilled 가 나오는지
helm rollback hello
```

TODO(human): `values.yaml` 의 `resources` 에 `requests.memory`, `requests.cpu`, `limits.memory` 를 채운다. 근거는 Lab 02 측정값(hello Pod 1개 대기 상태 약 175MB).

```bash
helm upgrade hello chart/hello -f chart/hello/values-demo.yaml
kubectl describe node lab02-control-plane | grep -A8 "Allocated resources"   # requests 합계가 노드에 잡혔는지
scripts/rollout-errors.sh probe-limits
```

## 측정표

| 항목 | 방법 | 결과 |
|---|---|---|
| probe 없음, 롤아웃 중 실패 요청 | 1단계 | **29/57 (51%)**: 502 ×28, 000 ×1. 롤아웃 3s |
| probe 있음, 롤아웃 중 실패 요청 | 2단계 | **4/125 (3%)**: 000 ×3, 502 ×1. 롤아웃 15s |
| probe + resources, 롤아웃 중 실패 요청 | 4단계 | 5/128 (4%): 000 ×3, 502 ×2. 롤아웃 15s (probe 만일 때와 차이 없음) |
| Pod 생성 → READY 1/1 | 2단계 `-w` AGE | 약 5~7s |
| liveness 1s/1s/1회 | 3단계 | 새 Pod 1개가 97s 동안 RESTARTS 5, CrashLoopBackOff. 롤아웃이 멈추고 옛 Pod 3개가 계속 응답 (curl 정상) |
| limits.memory 128Mi | 4단계 | 기동·응답은 됨. MaxHeapSize 64MB (상한의 50%), 실제 사용 약 120MB = 상한의 약 90%. 같은 컨테이너에서 `kubectl exec ... java -version` 을 띄운 뒤 RESTARTS 1 【추정: 두 번째 JVM 때문에 상한 초과】 |
| limits.memory 64Mi | 4단계 | 기동 2s 만에 OOMKilled (Exit 137 = SIGKILL), CrashLoopBackOff. 옛 Pod 가 계속 응답 |
| 고른 requests / limits | 4단계 | requests cpu 100m, memory 200Mi / limits memory 512Mi (CPU limit 없음). 실제 사용 약 125~131MB, QoS Burstable |

읽는 법:

- probe 없을 때 3s 만에 끝난 롤아웃은 "빨라서 좋은 것" 이 아니라 "준비 안 된 Pod 를 준비됐다고 믿은 것" 이다. 시간 12s 를 내고 실패 요청을 51% → 3% 로 줄였다.
- 남은 3~4% 는 옛 Pod 가 꺼지는 순간의 실패로 본다 【추정】. 10/7 `preStop` 으로 확인한다.
- Lab 02 의 "Pod 1개 약 175MB" 는 상한이 없어서 JVM 이 넉넉히 가져간 양이었다. JVM 은 상한을 보고 힙을 정한다 (작은 상한에선 50%, 큰 상한에선 25% 【사실: JVM MinRAMPercentage / MaxRAMPercentage 기본값】). 그래서 limits 는 "지금 쓰는 양" 만 보고 정하면 안 된다.
- 512Mi 는 대기 상태 기준으로 여유가 충분하다. 요청이 몰릴 때 사용량은 10/10 k6 로 잰다.

## 핵심 결정 3개와 대안

1. **readiness 와 liveness 를 같은 `/health` 로** (TODO(human) 값 채운 뒤 확정)
   - 대안: Spring Boot Actuator 의 `/actuator/health/readiness`, `/liveness` 분리. DB 연결이 생기면 "DB 끊김 = 준비 안 됨, 하지만 재시작은 불필요" 를 나눌 수 있다
   - 지금은 의존하는 것이 없는 앱이라 하나로 충분. 다중 서비스 앱(10/7 이후)에서 다시 본다
2. **startupProbe 대신 liveness `initialDelaySeconds`**
   - 대안: startupProbe (기동이 끝날 때까지 liveness 를 미뤄 줌). 기동 시간이 들쭉날쭉한 앱에 맞다
   - 지금은 기동 4~5s 로 일정해서 고정 지연으로 충분 【추정: 1회 측정 기준】
3. **CPU 는 requests 만, limits 는 메모리만**
   - 대안: CPU limits 도 건다. 한 Pod 가 CPU 를 독차지하는 걸 막지만, Spring 기동처럼 순간적으로 CPU 를 많이 쓰는 구간이 느려진다(throttling)
   - 측정 거리: CPU limit 200m 일 때 READY 까지 시간이 얼마나 느는지

## 스스로 풀어 볼 문제 1개

probe 를 켠 상태에서도 실패가 몇 개 남는다면, 어느 순간(새 Pod 가 뜰 때 / 옛 Pod 가 꺼질 때)의 실패일까? `results/rollout-probe.log` 에서 실패가 몰린 위치와 `kubectl get pods -w` 출력을 맞춰 보고 예상을 적는다. (힌트: 10/7 주제 `preStop`)

## 검증 명령과 기대 출력

```bash
kubectl get deploy hello -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}'   # httpGet /health 가 보임
kubectl get pods                       # 3개 READY 1/1, RESTARTS 0
kubectl top pod 2>/dev/null || echo "metrics-server 없음 (10/7 HPA 때 설치)"
helm history hello                     # 단계마다 revision 이 쌓임
```
