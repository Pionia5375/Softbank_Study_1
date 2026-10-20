로드맵 위치: 3주차 10/21~10/26 / 완성된 FaaS PoC 분석 / 본선 연결점: 설계 문서의 아키텍처·요청 흐름·결정 표 초안이자, 심사 Q&A 에서 "왜 이렇게 했나, 깨지면 어떻게 되나" 에 답하는 연습

# PoC 분석 가이드

[RUN-ALL.md](RUN-ALL.md) 로 전체를 한 번 돌린 다음 이 문서를 본다. 순서: 전체 그림(1절) → 요청 4가지가 흐르는 길(2절) → 단계별로 파일 읽고 설정 하나씩 깨뜨리기(3절) → 말로 답해 보기(4절).

원칙: 읽기만 하지 않는다. 단계마다 **예상을 먼저 적고** 깨뜨린 다음, 결과가 예상과 같았는지 비교한다. 본선은 개인 평가라 "돌아간다" 보다 "왜 이렇게 했고 깨지면 어디를 보나" 를 말할 수 있어야 한다.

---

## 1. 전체 그림

```
맥 (Docker Desktop)
 ├─ localhost:8080 ─ port-forward ─ Argo CD UI
 ├─ localhost:8081 ─────────────────────────────┐ (kind extraPortMappings → 노드 31080)
 ├─ localhost:8090 ─ port-forward ─ 컨트롤 플레인 API
 ├─ localhost:5001 ─ kind-registry (registry:2 컨테이너, 노드들과 같은 docker 네트워크 "kind")
 └─ Claude Code ─ MCP(stdio) ─ ops_mcp ─ ops-agent 토큰 ─┐
                                                        │
kind 클러스터 "faas"  (CNI = Cilium + Hubble)            ▼
 ┌ control-plane 노드 ───── API 서버, etcd, 스케줄러 (NodePort 31080 받는 곳)
 ├ system 풀 (taint 없음) ─ argocd, argo-rollouts, monitoring(Prometheus), knative-serving(activator·autoscaler·controller),
 │                          kourier-system(Envoy 입구), faas-system(컨트롤 플레인), fn-demo, fn-canary(podinfo),
 │                          tenant-a/b 의 hello-fn (toleration 없는 건 전부 여기로)
 ├ build 풀 (pool=build:NoSchedule) ─ faas-build 의 kaniko Job, fn-build 의 4단계 빌드 Job
 └ exec 풀  (pool=exec:NoSchedule)  ─ Knative 함수 파드 (fn-runtime 의 hello-runc/gvisor, tenant-a 의 hello), gVisor(runsc) 설치됨

Git (GitHub main) ← Argo CD 가 2~3분마다 읽음 (01 values: reconciliation 120s + jitter 60s)
 root ─ App of Apps → hello-fn, bye-fn                          (01)
 podinfo (kubectl apply)                                        (02)
 tenants ApplicationSet → tenant-a, tenant-b (울타리)            (03)
 tenant-a-hello, tenant-b-hello (테넌트 AppProject 안)           (03)
 faas-functions → fn-runtime 의 ksvc 3개                          (04)
 platform-05 → faas-system, faas-build, RBAC, ops-agent           (05)

테넌트 울타리 6겹 (03): Namespace+PSA baseline / ResourceQuota / LimitRange / NetworkPolicy(default deny) / RBAC / AppProject
```

두 갈래를 구분해서 기억한다.
- **플랫폼**(Argo CD, Rollouts, 울타리, 컨트롤 플레인 자체)은 GitOps: Git 이 정답, Argo CD 가 맞춘다.
- **사용자 함수**(05)는 컨트롤 플레인이 쿠버네티스 API 로 직접 만든다. 함수 이력은 Git 이 아니라 Knative Revision + 감사 로그에 있다. (05 결정 1)

## 2. 요청 4가지가 흐르는 길

각 화살표마다 "여기가 끊기면 무슨 증상이 나나" 를 같이 적어 두었다. 분석할 때 화살표 하나씩 직접 확인한다.

### 2.1 함수 배포 (05): `POST /api/v1/tenants/tenant-a/functions`

```
deploy-fn.sh ─POST {name, code}→ 컨트롤 플레인 (faas-system)
  1. 테넌트 확인: namespace tenant-a 에 라벨 tenant=tenant-a 가 있나            ✗ → 404 (kube-system 같은 곳에 못 넣게)
  2. buildId = 코드 해시. 같은 코드면 빌드 재사용 (멱등)
  3. ConfigMap src-<id> + kaniko Job build-<id> 생성 (faas-build ns)          ✗ RBAC → 403, AUDIT 줄에 error
  4. Job 파드 → build 풀 (nodeSelector + toleration)                         ✗ toleration 없음 → Pending
     initContainer 가 ConfigMap 을 cp -L 로 복사 → kaniko 가 이미지 빌드
     → push kind-registry:5000/tenant-a/hello:<id>, digest 를 /dev/termination-log 에
  5. 컨트롤 플레인이 Job 완료를 보고 digest 를 읽음 (백그라운드 스레드, 메모리에만 있음 ← 05 알려진 한계 1)
  6. Knative Service 를 server-side apply (image = localhost:5001/tenant-a/hello@sha256:...)
  7. Knative controller → Configuration → Revision hello-0000N → Deployment → 파드 (exec 풀)
     노드의 containerd 가 localhost:5001 을 kind-registry:5000 으로 바꿔 받음 (04 setup.sh 의 hosts.toml)
  8. 상태 조회 GET … → BUILDING → DEPLOYING → READY
```

### 2.2 함수 호출: `curl -H "Host: hello.tenant-a.faas.local" localhost:8081`

```
맥 8081 → kind control-plane 노드 31080 (NodePort) → Kourier Envoy (kourier-system)
  Host 헤더로 어느 함수인지 고름 (<이름>.<ns>.faas.local)
  ├ 파드가 1개 이상: Envoy → 함수 파드의 queue-proxy(8012) → 사용자 컨테이너(8080)
  └ 파드가 0개: Envoy → activator(knative-serving) 가 요청을 잡아 둠 → autoscaler 에 "수요 있음"
               → Deployment replicas 0→1 → 스케줄(exec 풀) → 이미지 받기 → 시작 → 준비 → activator 가 넘김   = 콜드 스타트
  tenant-a 로 들어오는 순간 Cilium 이 NetworkPolicy 검사:
     allow-from-namespaces(knative-serving, kourier-system) 가 없으면 → DROPPED, curl 은 타임아웃   ← 10/20 고친 이음새
```

### 2.3 플랫폼 변경 (GitOps): `git push`

```
git push → GitHub → argocd-repo-server 가 2~3분마다 clone (Chart.yaml 있으면 helm template)
 → argocd-application-controller 가 원하는 상태 vs 실제 상태 비교 → 다르면 apply (sync)
 → selfHeal: 누가 kubectl 로 바꾸면 되돌림 / prune: Git 에서 지우면 클러스터에서도 지움
 ApplicationSet(tenants): tenants/*.yaml 파일 하나 = Application 하나 = namespace 하나
```

### 2.4 나쁜 버전 배포와 자동 롤백 (02): podinfo

```
git push (나쁜 이미지) → Argo CD sync → Rollout 이 새 ReplicaSet 을 조금만(카나리 단계)
 → AnalysisRun 이 15초마다 Prometheus 에 "카나리 2xx 비율" 질의 (prometheus-server.monitoring:80)
 → 0.95 미만 n번 → abort → 카나리 파드 0개 → 안정 버전 100%
 질의 자체가 실패해도(주소 오타) abort = fail-closed
```

## 3. 단계별 분석 (하루 1~2단계)

각 단계: ① 읽을 파일(순서대로) ② 핵심 결정 3개 한 줄 요약 (자세한 대안 표는 그 단계 README 하단) ③ 깨뜨렸다 고치기. 깨뜨릴 때는 **예상 → 실행 → 관찰 → 고치기 → 한 줄 정리** 를 스레드에 남긴다.

### 01 Argo CD (이미 직접 함)
- 결정: pull GitOps(vs CI push), Helm 차트(vs 평범한 YAML/Kustomize), App of Apps(vs Application 손으로)
- 깨뜨리기: README 5절 (selfHeal 드리프트, 라벨 불일치, prune). 이미 했으면 건너뜀.

### 02 Rollouts
- 읽기: `app/rollout.yaml` → `app/analysis-template.yaml` → `platform/prometheus/values.yaml`
- 결정: Argo Rollouts(vs Flagger), 비율 = 파드 수로 근사(vs Gateway API/Istio), 판정 = 2xx ≥ 0.95(vs p95 지연)
- 깨뜨리기
  - B1. AnalysisTemplate 주소 `prometheus-server` → `prometheus-svr` 후 **좋은** 배포 → 그래도 abort 되나? (README 4절, fail-closed)
  - B2. 부하(`scripts/load.sh`)를 끄고 배포 → 요청 0 이면 NaN → 멀쩡한 배포가 실패. 왜 부하가 필요한지 체감
  - 측정: `scripts/measure-rollback.sh 3` → detect_s, clean_s, error_pct

### 03 테넌트 격리
- 읽기: `charts/tenant/templates/` 6장 (namespace → resourcequota → limitrange → networkpolicy → rbac → appproject) → `gitops/tenants-appset.yaml`
- 결정: 차트 1개 + ApplicationSet(vs Capsule/vCluster), Cilium + 표준 NetworkPolicy(vs kindnet/Calico), 한도 숫자·PSA baseline
- 깨뜨리기
  - B3. allow-dns 블록 주석 → 같은 namespace 인데 이름으로는 실패, IP 로는 성공. Hubble 로 53번 DROPPED 확인 (README 7절)
  - B4. **(새, 10/20 이음새)** `tenants/tenant-a.yaml` 의 `network:` 4줄을 지우고 push → `kubectl -n tenant-a get ksvc hello` 는 READY 인데 `curl … hello.tenant-a.faas.local` 은 타임아웃. `hubble observe --namespace tenant-a --verdict DROPPED` 에 kourier/activator 출발 패킷이 보이는지. "READY 와 실제로 닿는다는 다르다" 를 설명할 수 있으면 통과
  - B5. `tenants/` 에 tenant-c.yaml 추가 → push → namespace·울타리가 몇 초에 생기나 (`scripts/measure.sh onboard 1`)
  - 측정: `scripts/measure.sh neighbor` (옆집 폭주 때 p95)

### 04 함수 런타임
- 읽기: `cluster/kind-config.yaml` → `scripts/setup.sh` → `build/kaniko-job.yaml` → `functions/ksvc/hello-runc.yaml` → `hello-gvisor.yaml` → `platform/runtimeclass-gvisor.yaml`
- 결정: Knative + Kourier(vs KEDA HTTP), Kaniko Job + build 풀(vs BuildKit/외부 CI), gVisor RuntimeClass(vs Kata/WASM)
- 깨뜨리기
  - B6. Knative 기능 플래그 `kubernetes.podspec-tolerations` 를 disabled → 함수 하나 변경 push → Argo CD 에서 SYNC FAILED, 기존 함수는 계속 응답 (README 7단계)
  - B7. `hello-runc.yaml` 에서 tolerations 를 빼고 push → 새 Revision 파드 Pending (`untolerated taint {pool: exec}`) → 그동안 트래픽은 옛 Revision 이 받는지
  - B8. RuntimeClass 의 `scheduling.nodeSelector` 를 지우고 hello-gvisor 의 nodeSelector 도 지우면? gVisor 가 없는 노드에 갈 수 있나 (taint 가 막아 주는지, 무엇이 마지막 벽인지)
  - 측정: `scripts/coldstart.sh hello-runc 10`, `hello-gvisor 10`, `scripts/build-noise.sh`

### 05 컨트롤 플레인 + MCP
- 읽기: `deploy/FunctionDeployer.java` (startDeploy → finishDeploy) → `templates/build-job.yaml` → `templates/ksvc.yaml` → `k8s/platform/control-plane/rbac.yaml` → `mcp-server/ops_mcp/tools.py` → `guardrails.py`
- 결정: 함수는 API 직접(vs 함수도 GitOps), 클러스터 안 kaniko + digest 고정(vs 태그), 별도 MCP 서버 + 좁은 SA + 5층 가드레일(vs Spring 내장/관리자 kubeconfig)
- 깨뜨리기
  - B9. `k8s/platform/control-plane/tenant-a.yaml` 의 RoleBinding 삭제 push → 배포가 BUILDING → ? 에서 멈추나. AUDIT 줄로 어느 단계인지 (README 5단계 확인 질문)
  - B10. 빌드 중에 `kubectl -n faas-system delete pod -l app=control-plane` → Job 은 끝났는데 ksvc 가 안 생김 (알려진 한계 1). 고치는 설계 2가지를 말로
  - B11. ops-agent Role 에서 `patch` 제거 → MCP scale 이 파이썬 가드레일은 통과하고 RBAC 403 에서 막힘 (README 9단계)
  - 측정: `scripts/measure-deploy.sh 3` (새 빌드 3회 + 재사용 1회)
  - MCP 연결은 README 7단계 (`claude mcp add faas-ops …`). 맥의 Claude Code 에서 한다

### 06 장애 주입 (대역 클러스터)
- 읽기: `scripts/s1-node-down.sh` → `defenses/fn-resilience-patch.yaml` → `defenses/pdb.yaml` → `runbooks/RB-01-node-down.md`
- 결정: kubectl+docker 스크립트(vs Chaos Mesh/Litmus), 프로브+알림+상태 3겹 같은 t0, tolerationSeconds 20 + 흩어 놓기 + PDB 1
- 깨뜨리기
  - B12. PDB minAvailable 2 → spot 모드 drain 이 안 끝나 예고 없는 장애로 (README 4.4)
  - B13. 분석이 stable 을 보게 → 나쁜 버전 승격 (README 6절)
  - B14. tenant-b NetworkPolicy 삭제 → 어느 공격이 FAIL 로 바뀌나 (README 7절)

### 07 EC2 + k3s (코드만)
- 읽기: `README.md` 2절 큰 그림 → `terraform/cluster/pools.tf` → `k3s/*.tftpl` → `RUNBOOK.md`
- 결정: EC2+k3s(vs EKS/kubeadm), 풀별 구매(시스템 온디맨드/실행 스팟/빌드 온디맨드), taint 는 시스템·빌드에만
- 주의: 로컬(04)은 exec 풀에 taint 를 걸고 07 은 안 건다. 왜 다르게 했는지 07 결정 3 을 읽고 한 줄로 말할 수 있어야 한다
- AWS apply 는 하지 않는다 (승인 + 로컬 세션에서만)

## 4. 말로 답해 보기 (심사 Q&A 연습)

한 문항당 30초 안에, 숫자 하나 이상 넣어서.
1. 사용자가 코드를 올리고 첫 응답을 받기까지 무슨 일이 일어나나? 가장 오래 걸리는 구간은? (2.1 + deploy-times.csv)
2. 테넌트 A 가 B 를 못 부르는 건 정확히 무엇 때문인가? Cilium 을 빼면? (03 결정 2, B4)
3. 콜드 스타트를 줄이는 방법 3가지와 각각의 비용은? (min-scale, 이미지 크기, runc vs gVisor 숫자)
4. 나쁜 버전이 나가면 몇 초 만에, 사용자 몇 %가 에러를 보고 되돌아가나? (02 rollback.csv)
5. 컨트롤 플레인이 죽으면 이미 떠 있는 함수는? 진행 중 배포는? (B10)
6. AI 에이전트가 클러스터를 망가뜨리지 못하게 하는 장치 5층은? 그중 진짜 벽은? (B11)
7. 노드 하나가 죽으면 몇 초간 장애이고, 무엇으로 줄였나? (06 s1 csv: 방어 전 vs 후)

## 핵심 결정 3개 (+대안)

| 결정 | 선택 | 대안과 버린 이유 |
|---|---|---|
| 1. 분석 단위 | 요청 흐름(2절) 화살표 하나씩 + 단계별 깨뜨리기 | (가) 파일 순서대로 읽기: 파일 사이 연결(이음새)을 놓친다. 10/20 에 찾은 NetworkPolicy 문제가 그런 종류 |
| 2. 깨뜨릴 대상 | 단계당 2~3개, "증상이 다른 곳에서 나는 것" 위주 (READY 인데 안 닿음, 가드레일 통과 후 RBAC 403) | (가) 단계당 하나: 시간은 줄지만 Q&A 에서 자주 나오는 "겉보기 정상" 장애를 못 겪는다 |
| 3. 06 위치 | 대역 클러스터 | (가) 진짜 faas: PDB·프로브 라벨이 안 맞고(Knative 파드 라벨), 망가지면 05까지 다시 세워야 한다 |

## 셀프 연습 1개

2.2 의 화살표 중 하나를 골라, 그 구간만 끊는 방법을 스스로 하나 더 만든다 (예: Kourier 파드를 0개로). 예상 증상을 먼저 적고 돌려 본 뒤, 4절 질문 중 어디에 쓸 수 있는 숫자가 나왔는지 적는다.

## 검증 명령과 기대 출력

```bash
kubectl -n tenant-a get networkpolicy
#   기대: default-deny-all, allow-same-namespace, allow-dns, allow-from-namespaces (4개)
kubectl -n tenant-a get ksvc hello -o jsonpath='{.status.latestReadyRevisionName}{"\n"}'
#   기대: hello-00001 (배포 횟수만큼 번호 증가)
kubectl get pods -A -o wide --field-selector spec.nodeName=faas-worker3 | grep -v kube-system
#   기대: exec 노드엔 함수 파드(fn-runtime, tenant-a)만. 노드 이름은 kubectl get nodes -L pool 로 확인
```
