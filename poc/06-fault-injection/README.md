로드맵 위치: 4주차 10/26 (월) / 장애 주입 + 런북 / 본선 연결점: 심사위원이 "노드가 죽으면? 나쁜 버전이 나가면? 옆 테넌트가 폭주하면?" 이라고 물을 때 "직접 죽여 봤고, 감지 N초·복구 M초였고, 그래서 이 값을 골랐다" 로 답하는 재료. 데모 5분 안에 "장애 주입 → 자동 복구" 장면 하나를 라이브로 보여 줄 수 있게 된다

# PoC 6단계: 일부러 고장 내고, 감지→복구를 초 단위로 재기

오늘 끝나면 되는 것 3개
1. 장애 4가지(노드 다운, 함수 폭주, 나쁜 배포, 테넌트 침범)를 스크립트 한 줄로 넣고, 각각 **감지 몇 초 / 복구 몇 초 / 사용자가 본 에러 몇 개** 가 CSV 에 있다
2. 그 숫자를 보고 방어 설정 3개(tolerationSeconds, PDB, 알림 규칙)를 직접 써서 넣었고, 넣기 전/후 숫자가 비교된다
3. 장애마다 런북(새벽 3시에 알림 받은 사람이 그대로 따라 할 문서)이 있다 → `runbooks/`

진행 방식
- 개념(1절) → 파일 지도(2절) → 준비(3절) → 시나리오마다: 스크립트 주석 읽기 → **방어 없이** 한 번 → 빈칸 채워 방어 넣기 → 다시 재기 → 확인 질문 → 출력 붙여 주기.
- 빈칸은 `___` 와 `TODO(human)` 주석. 파일 맨 위에 공식 문서 링크가 있다. 30분 막히면 `solution/` 같은 경로 파일을 본다.
- 분담: **Jeong** = 방어 설정 파일 4개(`defenses/` 3개 + `gitops/` 1개, 빈칸 22개). **Claude** = 장애 주입·측정 스크립트(`scripts/`, 완성본), 대역 클러스터(`standin/`), 런북 초안(`runbooks/`).
- 이 단계는 3·4단계가 끝난 클러스터(Cilium + 워커 system/build/exec + Knative + gVisor)를 친다. 그게 아직이면 `standin/`(대역)으로 똑같이 할 수 있다 (3절).

---

## 1. 개념 (0부터)

### 1.1 장애 주입이 뭔가

운영 중인 시스템에 **일부러, 통제된 방식으로** 고장을 넣고 시스템이 어떻게 버티는지 보는 일이다. 넷플릭스가 운영 서버를 무작위로 끄는 "Chaos Monkey" 로 유명해졌고, 지금은 카오스 엔지니어링이라고 부른다.

순서는 늘 같다.
1. **평소 상태를 숫자로 정한다** (예: 요청 성공률 100%, p95 4ms)
2. **가설을 세운다** ("노드 하나가 죽어도 요청은 계속 성공한다")
3. **고장을 넣는다** (노드를 멈춘다)
4. **평소 상태와 비교한다** (실제로는 50초 동안 요청 절반이 실패했다)
5. **가설이 틀렸으면 고치고 다시 한다**

본선에서 이게 중요한 이유: "노드가 죽어도 괜찮습니다" 는 아무나 말한다. "죽여 봤더니 50초 동안 절반이 실패해서, X 를 넣어 Y 초로 줄였습니다" 는 직접 해 본 사람만 말한다. 심사 기준의 "대안과 버린 이유 + 측정 숫자" 가 바로 이것이다.

### 1.2 시간을 재는 말

| 말 | 뜻 | 이 단계에서 |
|---|---|---|
| t0 | 고장을 넣은 순간 | 스크립트가 기록 |
| 감지 시간 (MTTD) | t0 → 시스템(또는 사람)이 "고장났다" 를 안 순간 | 노드 NotReady 된 시각, 알림이 firing 된 시각, 카나리 분석이 Failed 된 시각 |
| 복구 시간 (MTTR) | t0 → 다시 평소 상태가 된 순간 | 파드가 원래 개수로 찬 시각, 마지막 에러 시각 |
| 사용자가 본 장애 | 첫 에러 → 마지막 에러 | 합성 프로브 로그에서 계산 |

M 은 Mean(평균) 이라서 3회 이상 재서 평균을 낸다.

**합성 프로브**: 진짜 사용자 대신 0.1초마다 함수를 부르는 작은 파드(`scripts/probe.sh`). 이 로그가 "사용자가 실제로 본 것" 이다. 쿠버네티스가 "다 괜찮아" 라고 해도 프로브에 에러가 찍히면 사용자는 아팠던 것이다. 감지는 세 겹으로 본다.
1. 프로브 = 사용자 시점 (가장 정직)
2. 지표 알림 = Prometheus 가 숫자를 보고 울림 (사람을 깨움)
3. 쿠버네티스 상태 = 노드 condition, 이벤트, Rollout phase (자동 복구가 보는 것)

### 1.3 시나리오 1: 노드가 죽으면 쿠버네티스는 어떻게 아나

노드의 kubelet 은 약 10초마다 API 서버에 "나 살아 있어" 를 남긴다 (`kube-node-lease` 네임스페이스의 Lease). 그다음은 이렇다.

```
t0      노드 정지. 그 노드 파드로 간 요청은 응답이 없다 (Service 는 아직 그 파드를 목록에 갖고 있다)
+50s    컨트롤러가 "하트비트가 50초째 없다" → 노드 Ready=Unknown (NotReady)
        → 그 노드 파드들을 Ready=False 로 표시 → Service 목록에서 빠짐 → 이제야 요청이 성공
        → 노드에 taint 두 개(node.kubernetes.io/unreachable, not-ready)를 붙인다
+350s   파드는 그 taint 를 기본 300초 참는다(tolerationSeconds) → 300초 뒤 쫓아냄(evict) → ReplicaSet 이 다른 노드에 새로 만든다
```

- 50초 = kube-controller-manager 의 `--node-monitor-grace-period` 기본값. 【사실】대역 클러스터 실측 50.1s (k8s v1.37). 문서: https://kubernetes.io/docs/reference/command-line-tools-reference/kube-controller-manager/
- 300초 = `DefaultTolerationSeconds` 어드미션 플러그인이 모든 파드에 몰래 넣는 기본값. 【사실】 https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/#taint-based-evictions
- 그래서 **파드 2개 중 1개가 죽은 노드에 있으면: 50초 동안 요청 절반이 실패하고, 그 뒤 5분 동안은 파드 1개로 버틴다.** 이 숫자를 직접 보는 게 1절의 핵심이다.
- EKS 같은 관리형 클러스터에선 50초(컨트롤 플레인 설정)를 못 바꾼다. 바꿀 수 있는 건 파드 쪽 300초(tolerationSeconds)와 "파드를 노드마다 흩어 두기"(topologySpreadConstraints)다.

**스팟 회수**: AWS 스팟 인스턴스는 싸지만 AWS 가 필요하면 회수한다. 회수 **2분 전** 에 예고(인스턴스 메타데이터와 EventBridge 이벤트)가 온다. 【사실】 https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/spot-instance-termination-notices.html
- 예고를 받아 노드를 미리 비우는 프로그램 = AWS Node Termination Handler, 또는 Karpenter 의 interruption 처리. 이게 하는 일이 `kubectl cordon`(새 파드 받지 마) + `kubectl drain`(있는 파드 내보내) 이다.
- drain 은 **PodDisruptionBudget(PDB)** 을 지킨다. PDB = "자발적으로 파드를 뺄 때 최소 N개는 살려 둬라" 는 약속. 예고 없이 죽는 건(hard) 자발적이 아니라서 PDB 와 상관없다.
- 그래서 `s1-node-down.sh` 는 모드가 둘이다. `hard` = 예고 없음, `spot` = 2분 예고를 받고 drain 한 뒤 정지.

### 1.4 시나리오 2: 노이지 네이버 (함수 폭주)

같은 노드를 쓰는 다른 테넌트가 CPU·메모리·노드 자리를 다 가져가서 내 함수가 느려지거나 못 뜨는 것.
- **requests** = "이만큼은 꼭 필요해" 예약. 스케줄러는 노드의 남은 예약 자리로 파드를 놓는다. 자리가 없으면 **Pending**.
- **limits** = "이 이상은 못 쓰게" 상한. CPU 는 넘으면 멈칫(throttling), 메모리는 넘으면 죽음(OOMKilled).
- **ResourceQuota** = 네임스페이스(=테넌트) 전체 합의 상한. 넘는 파드는 아예 안 만들어진다 (ReplicaSet 이벤트 `FailedCreate ... exceeded quota`).
- **LimitRange** = requests/limits 를 안 적은 파드에 기본값을 넣고, 컨테이너 하나의 최대치를 막는다.
- 3단계에서 이걸 넣었다. 이 시나리오는 그게 **실제로 막아 주는지** 를 잰다. 그리고 쿼터를 지웠을 때(= 3단계가 없었다면) 숫자가 어떻게 되는지도 잰다.

### 1.5 시나리오 3: 나쁜 버전 배포와 자동 롤백

2단계 Argo Rollouts 카나리: 새 버전을 25%만 내보내고 → AnalysisTemplate 이 "에러율 괜찮나?" 를 재고 → 실패면 **abort** (새 버전 파드를 0으로, 트래픽 전부 안정 버전으로). 이게 자동 롤백이다.
- 감지 = AnalysisRun 이 Failed 가 된 순간. 복구 = 나쁜 파드가 다 사라진 순간.
- 사용자가 본 에러 = 카나리 비율(25%) × 분석이 실패를 확정할 때까지의 시간. 그래서 **분석 간격·실패 허용 횟수** 가 곧 "사용자가 몇 개의 에러를 보는가" 다.
- **GitOps 와의 관계 (중요)**: Rollouts 가 롤백해도 Git 에는 여전히 나쁜 버전이 적혀 있다. Argo CD 화면에선 Application 이 Degraded 로 보인다. 진짜 복구 = `git revert` + push. 런북 RB-03 에 이 순서가 있다.

### 1.6 시나리오 4: 테넌트 침범

tenant-b 의 함수 코드가 악의적이라고 가정하고, 그 파드 안에서 옆 테넌트를 건드려 본다. 막는 벽이 네 겹이다.

| 벽 | 막는 것 | 3단계 리소스 |
|---|---|---|
| NetworkPolicy | 다른 테넌트 파드·API 서버·클라우드 메타데이터로 가는 연결 | default-deny + 같은 ns 허용 |
| RBAC | 함수 계정으로 쿠버네티스 API 호출 (남의 Secret 읽기, 파드 만들기) | Role/RoleBinding |
| Pod Security (PSA) | 특권 컨테이너, 노드 디스크(hostPath) 마운트 = 노드 탈출 | ns 라벨 `pod-security.kubernetes.io/enforce: restricted` |
| Quota/LimitRange | 노드 자원 독점 | 1.4 와 같음 |

`169.254.169.254` = EC2 인스턴스 메타데이터 주소. 여기 닿으면 노드의 IAM 자격 증명을 꺼낼 수 있다. kind 에선 아무것도 없지만 7단계(EC2) 에선 진짜 위험이라 지금부터 시험 항목에 넣었다.

### 1.7 도구 선택: 왜 스크립트(kubectl + docker)인가

| 도구 | 장점 | 버린 이유 (이 PoC 기준) |
|---|---|---|
| **kubectl + docker 스크립트 (선택)** | 설치 0, 무엇을 하는지 한 줄씩 보인다. kind 노드 = 도커 컨테이너라 `docker pause` 가 "노드 전원 차단" 에 가장 가깝다. 측정까지 한 스크립트에 | 장애 종류를 늘릴 때마다 직접 짜야 한다. 일정 실행·실험 이력 UI 없음 |
| Chaos Mesh (v2.8.5) | CRD 로 PodChaos·NetworkChaos(지연·유실)·StressChaos·IOChaos·HTTPChaos, 일정 실행, 대시보드. Argo CD 로 실험까지 GitOps 가능 | 노드 하나 단위로 일부러 죽이는 건 기본 기능이 아니다. 특권 DaemonSet(chaos-daemon) 이 모든 노드에 깔린다 = 4단계 gVisor 격리 이야기와 충돌. 맥 메모리 추가 사용 |
| LitmusChaos | 실험 허브(미리 만든 실험 다수), 결과 리포트 | ChaosCenter 가 MongoDB 까지 달고 와서 무겁다 |
| AWS FIS | 진짜 스팟 회수 예고를 보내는 액션(`aws:ec2:send-spot-instance-interruptions`)이 있다 【사실】 https://docs.aws.amazon.com/fis/latest/userguide/fis-actions-reference.html | AWS 에서만. 7단계(EC2)에서 같은 시나리오를 진짜로 돌릴 후보 |

결론: 오늘은 원리를 숫자로 보는 날이라 스크립트. 본선에서 "네트워크 지연 200ms 넣으면?" 같은 질문이 예상되면 Chaos Mesh 의 NetworkChaos 하나만 추가하는 게 다음 수 (셀프 연습 참고).

---

## 2. 파일 지도

```
poc/06-fault-injection/
  scripts/                       ← Claude, 완성본. 주석을 위에서 아래로 읽기만
    env.sh                         대상 이름 기본값 (네임스페이스·함수·Rollout·노드 라벨). 다르면 실행할 때 앞에 붙여 덮어씀
    lib.sh                         시각 재기, Prometheus 질의, 알림 firing 확인
    probe.sh                       합성 프로브 (0.1초마다 curl, 로그 회수)
    analyze.py                     프로브 로그 → 평소 p95 / 에러 수 / 장애 구간 → CSV 한 줄
    s1-node-down.sh                시나리오 1  hard | spot
    s2-noisy-neighbor.sh           시나리오 2
    s3-bad-deploy.sh               시나리오 3  kubectl | git
    s4-tenant-breach.sh            시나리오 4  (8개 시도 PASS/FAIL 표)
  defenses/                      ← Jeong 작성 (빈칸)
    fn-resilience-patch.yaml       빈칸 6  tolerationSeconds 2개, 흩어 놓기 4개
    pdb.yaml                       빈칸 4  PodDisruptionBudget
    prometheus-alerts-values.yaml  빈칸 8  2단계 Prometheus 에 덧붙일 Helm values (지표 부품 2개 켜기 + 알림 규칙 5개)
  gitops/fault-defenses.yaml     ← Jeong 작성, 빈칸 4 (진짜 클러스터에서 pdb.yaml 을 Argo CD 로)
  runbooks/                      ← Claude 초안. RB-01 ~ RB-04. 측정 후 Jeong 숫자로 칸 채우기
  standin/                       ← Claude, 완성본. 3·4단계 대신 쓰는 대역 클러스터와 대상
    kind-config.yaml               워커 system/build/exec×2
    targets.yaml                   tenant-a(hello, api Rollout) / tenant-b, 격리 장치 전부
    monitoring.yaml                Prometheus + kube-state-metrics (Helm 없이. Service 이름은 2단계와 같은 prometheus-server:80)
    load-rules.sh                  defenses/prometheus-alerts-values.yaml 의 알림 규칙만 → 대역 Prometheus 에 넣기
  results/                       ← 측정 CSV (커밋한다), *.probe.log (커밋 안 함)
  solution/                      ← 정답본. defenses/·gitops/ 와 같은 구조
```

---

## 3. 준비: 어느 클러스터를 칠까

**장애 주입은 클러스터를 실제로 망가뜨린다.** 그래서 먼저 고른다.

| | A. 진짜 클러스터 (3·4단계 결과) | B. 대역 클러스터 (`standin/`) |
|---|---|---|
| 언제 | 3·4단계를 다 끝냈고, 본선 데모에 쓸 숫자를 원할 때 | 3·4단계가 아직이거나, 진짜 클러스터를 망가뜨리기 싫을 때 |
| 대상 | 4단계 함수, 2단계 Rollout | tenant-a 의 hello(Deployment), api(Rollout) |
| 이름 | `env.sh` 기본값과 다르면 덮어써야 함 (아래) | 기본값 그대로 |
| 주의 | exec 노드가 1대면 시나리오 1 은 "전면 장애" 가 정답 | 메모리 약 3GB 더 씀. A 클러스터는 잠깐 꺼 둬도 된다 |

처음엔 **B 로 한 바퀴** 돌고, A 에서 숫자만 다시 재는 걸 추천한다. 대역은 일부러 3·4단계와 같은 모양으로 만들었다.

### B. 대역 클러스터 세우기

```bash
cd /Users/ijeong/softbank_study_1/Softbank_Study_1
git switch main && git pull origin main
cd poc/06-fault-injection                 # 이 단계의 모든 명령은 이 폴더에서 친다

kind create cluster --config standin/kind-config.yaml
#   노드 컨테이너 5개(컨트롤 플레인 + system, build, exec, exec)를 띄운다. kubectl 대상이 kind-chaos 로 바뀐다
kubectl get nodes -L pool
#   -L pool = pool 라벨을 열로 보여 줌. exec 가 두 줄이어야 한다

kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts --server-side -f https://github.com/argoproj/argo-rollouts/releases/download/v1.10.1/install.yaml
#   Argo Rollouts 컨트롤러 설치 (2단계에서 한 것과 같은 것). --server-side = CRD 가 커서 일반 apply 로는 크기 제한에 걸린다
kubectl -n argo-rollouts rollout status deploy/argo-rollouts
#   컨트롤러 파드가 뜰 때까지 기다림

kubectl apply -f standin/targets.yaml
#   tenant-a/tenant-b 네임스페이스, 쿼터·LimitRange·NetworkPolicy·RBAC, hello 함수, api Rollout 을 한 번에 만든다
kubectl apply -f standin/monitoring.yaml
#   Prometheus 와 kube-state-metrics(쿠버네티스 상태를 숫자로 바꾸는 것)
kubectl get pods -A -o wide | grep -E 'tenant|monitoring|rollouts'
#   전부 Running 이어야 한다. hello·api 파드는 NODE 열이 exec 노드(chaos-worker3, chaos-worker4)여야 한다
```

### A. 진짜 클러스터에서 할 때 이름 맞추기

`scripts/env.sh` 를 열어 보면 기본값이 있다. 다르면 **파일을 고치지 말고** 실행할 때 앞에 붙인다.

```bash
# 3단계 결과 그대로라면: tenant-a 의 함수는 Application 이름을 딴 tenant-a-hello (라벨 app=tenant-a-hello)
FN_NS=tenant-a FN_NAME=tenant-a-hello FN_SELECTOR=app=tenant-a-hello ./scripts/s1-node-down.sh hard
# 2단계 Rollout 은 fn-canary 의 podinfo (Service 포트 80 이라 URL 은 기본값 그대로)
ROLLOUT_NS=fn-canary ROLLOUT=podinfo APP=podinfo ./scripts/s3-bad-deploy.sh git
```
네임스페이스 tenant-a/tenant-b, 노드 라벨 pool=exec 는 3단계와 대역이 같아서 따로 안 적어도 된다.

3단계 정답본과 대역이 다른 점 【사실】 `poc/03-tenant-isolation/solution` (main 7d48f36) 기준. 숫자가 조금 달라지는 이유가 이것이다.
- Pod Security 가 `enforce: baseline` (+ `warn: restricted`) 이다. 대역은 restricted. 시나리오 4 의 P1(특권 + hostPath)은 baseline 에서도 막혀서 결과는 같고, 찍히는 문구만 `violates PodSecurity "baseline:latest"` 로 바뀐다.
- 쿼터: tenant-a limits.cpu 2·pods 10, tenant-b limits.cpu **1**·pods **5**. LimitRange 기본 cpu limit 200m / max 1. 그래서 시나리오 2 에서 폭주 파드(limits 1코어)는 대역의 2개가 아니라 **1개만** 뜬다.

- 4단계 함수가 **Knative Service** 면: Knative 가 만든 Deployment 이름(`<서비스>-00001-deployment`)을 `FN_NAME` 으로, 라벨 `serving.knative.dev/service=<서비스>` 를 `FN_SELECTOR` 로. 단 scale-to-zero 라 파드가 0개면 시나리오 1 이 칠 대상이 없다 → `autoscaling.knative.dev/min-scale: "2"` 를 잠깐 걸고 한다. 【미검증】 이 컨테이너에선 Knative 로 돌려 보지 못했다.
- 프로브는 피해자와 **같은 네임스페이스** 에 뜬다 (NetworkPolicy 가 같은 ns 끼리만 열어 주므로). Knative 는 요청이 kourier(앞단 게이트웨이)를 거쳐서, tenant 네임스페이스 ingress 정책에 kourier-system(과 knative-serving activator) 이 들어오도록 열려 있어야 (03 tenant-a.yaml 의 network.allowFromNamespaces) 프로브가 닿는다. 그리고 프로브는 테넌트 안에서 kourier-system 으로 **나가야** 하므로 egress 도 열어야 한다 (tenant-a.yaml 의 network.allowToNamespaces: [kourier-system]) 【미검증】.
- Cilium 을 쓰면 `hubble` CLI 를 깔아 두면 시나리오 4 가 막힌 연결 목록도 보여 준다: `cilium hubble port-forward &` 를 먼저.

### 알림 규칙 먼저 쓰기 (빈칸 8개) — `defenses/prometheus-alerts-values.yaml`

시나리오마다 "알림이 몇 초 만에 울렸나" 를 재려면 규칙이 먼저 있어야 한다.
2단계 Prometheus 는 Helm 차트(`prometheus-community/prometheus`)로 깔았고, 알림 규칙도 그 차트의 values(`serverFiles.alerting_rules.yml`)로 넣는다. 그래서 이 파일은 **2단계 values 위에 덧붙이는 values** 다.

1. 파일 주석을 위에서 아래로 읽는다. 위쪽 = 2단계가 꺼 둔 부품 2개(kube-state-metrics, configmapReload)를 켜는 칸, 아래쪽 = 규칙 5개. 규칙 하나 = `expr`(조건) + `for`(얼마나 계속되면) + 라벨·설명.
2. 빈칸을 채우기 전에 Prometheus 화면에서 지표를 직접 쳐 본다.
   ```bash
   kubectl -n monitoring port-forward svc/prometheus-server 9090:80
   #   맥의 localhost:9090 → 클러스터 안 Prometheus(서비스 포트 80). 브라우저로 http://localhost:9090 → Query 탭
   ```
   - `kube_node_status_condition{condition="Ready",status="true"}` → 노드 수만큼 값 1 이 나오나 (A 클러스터는 1번 칸을 켜고 helm upgrade 한 뒤에야 나온다)
   - `kube_resourcequota{namespace="tenant-b"}` → type 이 used/hard 두 종류로 나오나
3. 빈칸을 채운다. `rollout_info` 의 phase 칸은 힌트의 네 개 중 하나를 고르고, 시나리오 3 에서 맞았는지 확인한다.
4. 넣는다.
   ```bash
   ./standin/load-rules.sh defenses/prometheus-alerts-values.yaml
   #   B(대역): 규칙 부분만 잘라 ConfigMap 으로 넣고, Prometheus 가 다시 읽을 때까지 기다린다. "규칙 5개 올라감" 이 나오면 성공

   helm upgrade prometheus prometheus-community/prometheus --version 29.37.0 -n monitoring \
     -f ../02-rollouts/platform/prometheus/values.yaml -f defenses/prometheus-alerts-values.yaml
   #   A(진짜): 2단계 release 를 다시 설치하되 values 파일을 두 개 준다. 뒤 파일이 앞 파일의 같은 칸을 덮는다
   #   (2단계 values 를 빼먹으면 2단계에서 정한 값이 차트 기본값으로 돌아간다)
   kubectl get --raw /api/v1/namespaces/monitoring/services/prometheus-server:80/proxy/api/v1/rules | grep -o '"name":"[A-Za-z]*"'
   #   A: 규칙 이름 5개가 보이면 성공 (configmapReload 가 다시 읽게 하는 데 1분쯤 걸릴 수 있다)
   ```
   - 빈칸(`___`)이 남아 있으면 load-rules.sh 가 거부한다. 문법이 틀리면 Prometheus 가 파일 전체를 거부한다 → `kubectl -n monitoring logs deploy/prometheus | tail` (A 는 `deploy/prometheus-server -c prometheus-server`)로 몇 번째 줄인지 본다.
   - A 에서 `RolloutAborted` 가 시나리오 3 때 안 울리면 `extraScrapeConfigs` 의 Argo Rollouts 대상이 up 인지 Prometheus 화면 Status → Targets 에서 본다. 【미검증】 이 컨테이너에선 2단계 차트를 받을 수 없어서(저장소 접근 차단) helm upgrade 경로는 못 돌려 봤다. 규칙 내용 자체는 대역 Prometheus 로 검증했다.

확인 질문: `for: 0s` 와 `for: 1m` 의 차이는 "알림이 늦게 오는 것" 말고 무엇을 얻고 잃나?

붙여 줄 것: `load-rules.sh` 출력 한 줄

---

## 4. 시나리오 1: 실행 노드 다운

읽을 파일: `scripts/s1-node-down.sh` (맨 위 주석 "한 회에 하는 일" 5줄이 전부다), `scripts/probe.sh` (프로브 파드 YAML)

### 4.1 방어 없이 재기

```bash
./scripts/s1-node-down.sh hard 1
#   hard = 예고 없이 노드를 얼린다(docker pause). 1 = 한 번. 한 번에 약 7분 (기본 300초를 기다리니까)
#   화면에 "노드 NotReady +__s", "알림 firing +__s", "다른 노드에서 파드 2개 Ready +__s" 가 차례로 찍힌다
./scripts/s1-node-down.sh spot 1
#   spot = 2분 예고 → cordon + drain → 정지. 약 2분
cat results/s1-node-down.csv
#   한 회 = 한 줄. 열 뜻: t_notready_s(감지), t_replaced_s(복구), errors(사용자가 본 실패 수), outage_s(첫~마지막 에러)
```

- 주입 중에 다른 터미널에서 `kubectl get nodes -w` 와 `kubectl -n tenant-a get pods -o wide -w` 를 켜 두면 1.3 의 타임라인이 눈앞에서 지나간다. `-w` = 바뀔 때마다 한 줄씩 출력.
- 끝나면 스크립트가 노드를 되살린다(unpause, uncordon). 중간에 Ctrl+C 로 끊었으면 직접: `docker unpause chaos-worker4 && kubectl uncordon chaos-worker4` (노드 이름은 화면에 찍힌 것).

확인 질문: hard 에서 "노드 NotReady" 가 찍히기 전 50초 동안 프로브 에러가 나는데, NotReady 가 찍히자마자 에러가 멈춘다. 왜 NotReady 가 Service 를 고치나? (1.3 타임라인의 둘째 줄)

### 4.2 방어 넣기 (빈칸 10개)

`defenses/fn-resilience-patch.yaml` (빈칸 6) — 주석을 위에서 아래로 읽고 채운다.
- tolerationSeconds 두 칸: 4.1 에서 잰 `t_notready_s` 를 보고 정한다. 짧게 하면 빨리 옮기지만, 노드와 잠깐 연결이 끊긴 것만으로 파드를 버린다.
- whenUnsatisfiable 과 nodeTaintsPolicy 는 짝으로 정한다. 두 가지 상황을 다 통과해야 한다.
  - 평소: 파드 2개가 반드시 다른 노드에 있어야 한다 (같은 노드에 몰리면 노드 하나에 전부 죽는다)
  - 노드 하나가 죽은 순간: 새 파드가 살아 있는 exec 노드에 떠야 한다 (죽은 노드에 0개, 산 노드에 1개 = 차이 1, 새 파드를 산 노드에 놓으면 차이 2)
  - 대역에서 세 조합을 재 봤다 (8절 표): ScheduleAnyway 는 평소에 몰리는 경우가 생겼고, DoNotSchedule + Ignore 는 노드가 죽으면 새 파드가 안 떴다.
- matchLabelKeys 는 채워 뒀다. 배포(rollout) 중에 옛 파드와 새 파드를 같이 세서 생기는 쏠림을 막는 줄이다. 주석만 읽고 넘어간다.

`defenses/pdb.yaml` (빈칸 4) — 문서 예시를 보고 채운다.

넣기 (대역):
```bash
kubectl -n tenant-a patch deploy hello --patch-file defenses/fn-resilience-patch.yaml
#   Deployment 에 이 조각을 덧붙인다. 파드 template 이 바뀌어서 파드가 새로 만들어진다
kubectl -n tenant-a get deploy hello -o yaml | grep -A12 tolerations
#   실제로 들어갔는지 눈으로 확인
kubectl apply -f defenses/pdb.yaml
kubectl -n tenant-a get pdb
#   ALLOWED DISRUPTIONS 열 = 지금 몇 개까지 빼도 되나. replicas 2, minAvailable 1 이면 1
```
진짜 클러스터(A)에선 patch 대신 같은 필드를 4단계 함수 차트 template 에 넣고 push 한다 (Argo CD selfHeal 이 kubectl patch 를 되돌리므로). PDB·알림 규칙은 `gitops/fault-defenses.yaml`(빈칸 4)을 채워 `kubectl apply -f gitops/fault-defenses.yaml`.

### 4.3 다시 재기 (3회씩)

```bash
./scripts/s1-node-down.sh hard 3
./scripts/s1-node-down.sh spot 3
```

확인 질문: tolerationSeconds 를 줄였는데 **사용자가 본 장애(outage_s)** 는 거의 그대로다. 줄어든 건 어느 열인가? 그리고 outage_s 를 줄이려면 무엇이 필요할까? (힌트: 그 50초 동안 요청은 Service 가 아직 죽은 파드로 보낸다. 요청을 보내는 쪽이 할 수 있는 일)

붙여 줄 것: `cat results/s1-node-down.csv`

### 4.4 깨뜨렸다 고치기: PDB 를 너무 세게

```bash
kubectl -n tenant-a patch pdb hello --type merge -p '{"spec":{"minAvailable":2}}'
#   "2개 중 2개는 항상 살아 있어야 한다" = 하나도 못 뺀다
./scripts/s1-node-down.sh spot 1
#   drain 이 110초 동안 못 끝나고 "drain 이 110초 안에 안 끝났다" 가 찍힌다 → 예고 시간이 끝나 결국 hard 와 같은 장애
kubectl apply -f defenses/pdb.yaml                     # 고치기: minAvailable 1 로 되돌림
```

배울 점: PDB 를 replicas 와 같게 두면 "안전" 해 보이지만 스팟 회수·노드 업그레이드 때 drain 이 영원히 막혀서, 오히려 예고 없는 장애로 바뀐다. 실제 운영에서 클러스터 업그레이드가 멈추는 흔한 원인이다.

---

## 5. 시나리오 2: 함수 폭주 (노이지 네이버)

읽을 파일: `scripts/s2-noisy-neighbor.sh` (폭주 Deployment YAML 이 스크립트 안에 있다: CPU 0.5코어 예약, 1코어까지 태움, 30개)

```bash
./scripts/s2-noisy-neighbor.sh 30 1
#   tenant-b 에 폭주 파드 30개를 시도하고 60초 유지. 그동안 tenant-a 함수의 p95 와 "파드 2개 더 늘리기" 시간을 잰다
#   화면: "쿼터가 막음 +__s", "알림 firing +__s", "폭주 파드: Running _ / Pending _ / 시도 30", "피해자 2 → 4 개 늘리기: __s"
```

방어 = 3단계의 ResourceQuota·LimitRange. 이 시나리오는 Jeong 빈칸이 없다. 대신 **방어를 빼고** 숫자를 비교한다 (= 깨뜨렸다 고치기).
진짜 클러스터(A)에선 쿼터를 지워도 Argo CD selfHeal 이 몇 초 만에 되살린다. 그래서 이 비교는 대역(B)에서 한다. A 에서 지워 보고 몇 초 만에 돌아오는지 재 두면 그게 "격리 벽 복구 시간" 이다.

```bash
kubectl -n tenant-b delete resourcequota tenant-quota
#   tenant-b 의 한도를 없앤다 = 3단계가 없었던 세상
./scripts/s2-noisy-neighbor.sh 30 1
kubectl apply -f standin/targets.yaml
#   고치기: 대역 대상 파일을 다시 적용하면 지운 쿼터만 다시 생긴다 (나머지는 이미 같아서 그대로)
cat results/s2-noisy-neighbor.csv
#   quota_objects 열 1 vs 0 줄을 비교: burners_running, victim_scaleup_s, p95_window_ms
```

확인 질문: 쿼터가 없을 때 피해자의 "파드 늘리기" 가 실패(timeout)했다면, 그건 CPU 를 뺏겨서인가, 노드 **자리(requests)** 를 뺏겨서인가? `kubectl -n tenant-a describe pod <Pending 파드>` 의 Events 맨 아래 줄로 확인한다.

붙여 줄 것: `cat results/s2-noisy-neighbor.csv`

---

## 6. 시나리오 3: 나쁜 버전 배포 → 자동 롤백

읽을 파일: `scripts/s3-bad-deploy.sh`, 그리고 2단계에서 쓴 Rollout·AnalysisTemplate (대역이면 `standin/targets.yaml` 의 아래쪽 절반)

```bash
./scripts/s3-bad-deploy.sh kubectl 3
#   대역: 스크립트가 Rollout 을 직접 고쳐 "항상 500 을 돌려주는 버전" 을 넣는다. 3번 반복
#   화면: 나쁜 파드 생성 +__s → 분석 실패(감지) +__s → abort(롤백 시작) +__s → 나쁜 파드 0개 +__s → 알림 +__s
kubectl argo rollouts get rollout api -n tenant-a
#   (kubectl-argo-rollouts 플러그인이 있으면) 리비전별 상태와 AnalysisRun 결과를 나무 모양으로 보여 준다
```

진짜 클러스터(A, Argo CD 가 Rollout 을 관리): 스크립트가 kubectl 모드를 거부한다. selfHeal 이 고친 걸 되돌리기 때문.
```bash
APP=<Rollout 을 관리하는 Application 이름> ROLLOUT_NS=<ns> ROLLOUT=<이름> ./scripts/s3-bad-deploy.sh git
#   1) 스크립트가 "push 하고 엔터" 를 기다린다
#   2) 다른 터미널에서 2단계 values 의 함수 버전을 나쁜 값으로 바꿔 커밋·push → 엔터
#   3) 끝나면 RB-03 대로 git revert + push
```
이 경로는 t0 가 push 시각이라 "Argo CD 가 알아채는 시간(1단계에서 잰 poll/refresh 초)" 이 앞에 더해진다.

### 깨뜨렸다 고치기: 분석이 엉뚱한 곳을 보게

분석 Job 이 카나리가 아니라 **안정 버전 Service** 에 curl 하도록 주소 한 군데를 바꾼다. 실제로 흔한 실수다 (복사해 온 템플릿의 주소를 안 바꿈).
```bash
sed 's/api-canary.tenant-a.svc/api-stable.tenant-a.svc/' standin/targets.yaml | kubectl apply -f -
#   대역 파일에서 분석 주소만 바꾼 내용을 그대로 적용한다 (sed = 글자 바꾸기, 파일 자체는 안 바뀐다)
#   주의: kubectl get -o yaml | sed | kubectl apply 로 하면 resourceVersion 이 딸려 들어가서 다음 apply 가 실패한다 (Claude 가 밟음)
./scripts/s3-bad-deploy.sh kubectl 1
#   분석은 계속 성공(안정 버전은 멀쩡하니까) → "나쁜 버전이 100% 승격됐다" 가 찍히고 CSV 에 promoted-bad
#   이어서 스크립트가 좋은 버전으로 되돌리는데... 이번엔 그 "좋은 버전" 이 abort 된다. 왜일까? (확인 질문 2)
kubectl apply -f standin/targets.yaml                  # 고치기 1: 분석 주소 원래대로
kubectl argo rollouts retry rollout api -n tenant-a    # 고치기 2: abort 된 좋은 버전 배포를 다시 시도
```
- 배울 점: 자동 롤백은 "분석이 맞는 걸 본다" 는 전제 위에 있다. 분석을 만들면 **일부러 나쁜 버전을 한 번 넣어서 실제로 abort 되는지** 를 꼭 확인한다 (이 시나리오가 그 확인이다).
- 덤으로 확인한 것: `failureLimit` 를 `count` 이상으로 올리면(예: count 3, failureLimit 5) Rollouts 가 "분석 설정이 틀렸다" 며 AnalysisRun 을 Error 로 끝내고 **안전하게 abort** 한다. 【사실】 대역 실측, 메시지 `count (3) must be >= failureLimit + consecutiveSuccessLimit (5 + 0)`.

확인 질문 2: 나쁜 버전이 승격된 뒤 좋은 버전을 다시 내면, 분석은 이번엔 어디(안정 버전 = 지금은 나쁜 버전)를 보고 있나? 그래서 무슨 일이 생기나?

확인 질문: 카나리 25% 에서 분석이 실패까지 약 N초 걸렸다면, 그동안 사용자 요청 중 대략 몇 %가 실패했어야 하나? CSV 의 `err_pct_window` 와 비교해 본다.

붙여 줄 것: `cat results/s3-bad-deploy.csv`

---

## 7. 시나리오 4: 테넌트 침범 시도

읽을 파일: `scripts/s4-tenant-breach.sh` 맨 위 주석의 8줄 표

```bash
./scripts/s4-tenant-breach.sh
#   tenant-b 에 공격자 파드를 띄우고 8가지 시도. 줄마다 PASS(막힘)/FAIL(뚫림)과 걸린 초
#   마지막에 Prometheus 의 403·PSA 거부 수, (Cilium 이면) hubble 의 DROPPED 흐름
```

### 깨뜨렸다 고치기: 공격자 쪽 NetworkPolicy 빼기

```bash
kubectl -n tenant-b delete networkpolicy default-deny
#   tenant-b 의 정책(나가는 쪽 egress 제한 포함)을 지운다. A 클러스터면 3단계 정책 이름으로 (kubectl -n tenant-b get networkpolicy)
./scripts/s4-tenant-breach.sh           # 어느 줄이 FAIL 로 바뀌나?
kubectl apply -f standin/targets.yaml   # 고치기 (A 클러스터면 selfHeal 이 이미 되살렸을 것)
```

확인 질문: tenant-b 의 정책을 지웠는데 N1·N2(tenant-a 로 가는 연결)는 여전히 PASS 다. 누구의 정책이 막고 있나? 그리고 FAIL 로 바뀐 N3 은 왜 "http 403" 같은 숫자가 찍히나 (연결은 됐는데 무엇이 막았나)?

붙여 줄 것: 표 8줄

---

## 8. 측정 결과 (대역 클러스터, Claude 실측)

【사실】 2026-10-20 이 레포의 `standin/` 그대로, 클라우드 컨테이너의 kind v0.33 + k8s v1.37.0 (4코어, 15GB). 맥 Docker Desktop 과 숫자가 다를 수 있어서 Jeong 이 다시 잰 값을 기준으로 삼는다. 원본 CSV 는 `results/`.

### 8.1 시나리오 1: 노드 다운 (`results/s1-node-down.csv`, 19회)

피해자 = hello 2개 (exec 노드 2대에 1개씩), 프로브 0.1초 간격. 평소 p95 3.2~4.8ms, 에러 0%.

**hard (예고 없음)**

| 설정 | 회수 | NotReady (감지) | 알림 firing | 파드 2개 복구 | 사용자 에러 | 사용자가 본 장애 |
|---|---|---|---|---|---|---|
| 방어 전 (기본값) | 3 | 평균 46.3s | 53.3s | **347.3s** | 38개 | 45.5s |
| tolerationSeconds 20 + ScheduleAnyway + PDB 1 | 3 | 평균 45.7s | 60.9s | 66.5s | 37개 | 44.7s |
| tolerationSeconds 20 + DoNotSchedule (Ignore) | 1 | 44.8s | 60.4s | **180초 넘게 Pending** | 37개 | 42.7s |
| tolerationSeconds 20 + DoNotSchedule + Honor | 2 | 52.4s | 65.8s | 73.5s | 43개 | 51.2s |
| **최종 (+ matchLabelKeys)** | 3 | 평균 49.9s (48.5~50.6) | 60.0s | **70.6s** (69.2~71.4) | 41개 | 48.7s |

**spot (2분 예고 → drain → 정지)**

| 설정 | 회수 | 그 노드 파드 | drain | 사용자 에러 |
|---|---|---|---|---|
| 방어 전 | 1 | 1/2 | 1.1s | 0 |
| tolerationSeconds 20 + ScheduleAnyway + PDB 1 | 2 | 1/2, **2/2** | 2.3s, 7.7s | 3, 0 |
| PDB minAvailable 2 (4.4 깨뜨리기) | 1 | 2/2 | **110초 timeout** | **87개** (장애 70.5s, 파드 복구 182.6s) |
| DoNotSchedule + Honor | 1 | **2/2** | 6.7s | 0 |
| 최종 | 2 | 1/2 | 2.3s, 1.2s | 3, 0 |

읽는 법
- **tolerationSeconds 는 "파드 수 복구" 만 줄인다 (347s → 71s, 약 5배).** 사용자가 본 장애(약 45~50초)는 그대로다. 그 시간은 NotReady 판정까지 걸리는 시간이라 파드 설정으로는 못 줄인다 → 앞단 재시도(RB-01 재발 방지 2) 아니면 spot 처럼 미리 비우기.
- **spot(미리 비우기)이 제일 큰 효과다.** 에러 40개 안팎 → 0~3개. 7단계 EC2 에서 스팟 회수 처리기를 까는 근거.
- **흩어 놓기는 세 번 바꿨다.** ScheduleAnyway 는 배포 뒤 한 노드에 2개가 몰린 때가 있었고(spot 표의 2/2), DoNotSchedule 만 쓰면 죽은 노드를 자리로 세서 새 파드가 안 떴다. Honor 를 붙여도 matchLabelKeys 없이는 배포 중 옛 파드를 같이 세서 다시 2/2 가 나왔다. 최종 설정은 배포 4번 + 측정 5번 동안 한 번도 안 몰렸다.
- 알림은 NotReady 뒤 약 10초(긁기 15초 + 평가 15초 주기). 2단계 Prometheus 는 평가 주기가 30초라 A 클러스터에선 조금 더 늦을 것 【추정】.
- PDB 를 replicas 와 같게 두면 drain 이 110초 내내 막혀서, 예고가 있었는데도 예고 없는 장애보다 나빠졌다 (에러 87개 > 41개).

### 8.2 시나리오 2: 함수 폭주 (`results/s2-noisy-neighbor.csv`, 4회)

tenant-b 가 폭주 파드 30개(각 CPU 0.5코어 예약, 1코어까지)를 시도. 60초 유지하는 동안 tenant-a hello 를 잰다.

| 설정 | 회수 | 폭주 파드 실제로 뜬 수 | 쿼터가 막은 시각 | 알림 firing | 피해자 p95 평소 → 폭주 중 | 피해자 2→4개 늘리기 |
|---|---|---|---|---|---|---|
| 쿼터 있음 (requests.cpu 1) | 3 | 2 / 30 | 0.3s | 4.7~15.3s (평균 10.4s) | 3.3ms → **7.4ms** (약 2배) | 1.5~2.4s |
| 쿼터 없음 (깨뜨리기) | 1 | 14 / 30 (16개 Pending) | 없음 | 안 울림 (쿼터가 없으니 지표도 없다) | 3.9ms → **93.9ms** (약 24배) | 7.9s |

읽는 법
- 쿼터가 있으면 폭주 파드는 2개에서 멈추고 피해자 p95 는 2배 정도 오른다. 쿼터가 없으면 14개가 떠서 p95 가 24배가 된다.
- 쿼터가 있어도 2배 오른 이유: 폭주 파드 2개가 1코어씩 = 2코어를 태운다. **kind 노드는 전부 같은 맥(여기선 4코어 VM)의 CPU 를 나눠 쓴다.** 노드가 달라도 CPU 는 진짜로 분리되지 않는다. EC2 에선 노드가 다른 기계라 다른 노드의 폭주는 안 번지고, 같은 노드 안에서만 limits 가 지킨다 【추정】 7단계에서 확인.
- 쿼터가 없을 때 피해자 늘리기가 Pending 으로 실패하진 않았다 (7.9s). 피해자 파드는 예약이 50m 로 작아서 남은 자리에 들어갔다. 예약이 큰 함수라면 Pending 이 됐을 것이다 【추정】.
- 쿼터 알림은 감지가 빠르지만(평균 10초) **사용량이 아니라 "예약량" 을 본다.** 폭주 파드가 예약은 작게 하고 실제로만 많이 쓰면 이 알림은 안 울린다. 그 경우는 limits(LimitRange) 가 막고, 감지는 CPU throttling 지표(`container_cpu_cfs_throttled_periods_total`)로 해야 한다 → 셀프 연습 후보.
- 에러 0~3개는 폭주 중이 아니라 끝에 피해자를 4개 → 2개로 줄일 때 났다(61~63초). 파드를 지울 때 Service 목록에서 빠지기 전에 요청이 가는 문제로, Lab 04 preStop 과 같은 원인이다.

### 8.3 시나리오 3: 나쁜 버전 배포 (`results/s3-bad-deploy.csv`)

api Rollout 4개, 카나리 첫 단계 25%(=파드 1개), 분석 = 5초 간격 최대 3회 curl Job, 실패 2회면 abort. 나쁜 버전 = 항상 500.

| 설정 | 회수 | 나쁜 파드 생성 | 분석 실패 = abort (감지·롤백 시작) | 나쁜 파드 0개 (복구 끝) | 알림 firing | 사용자 에러 | 사용자가 본 장애 |
|---|---|---|---|---|---|---|---|
| 기본 | 3 | 0.1s | 평균 **17.0s** (16.0~19.0) | 평균 18.1s | 평균 39.4s (31.5~44.6) | 평균 29개 (26~34) | 평균 16.2s |
| 분석이 안정 버전을 봄 (깨뜨리기) | 1 | 0.1s | **못 잡음** (분석 성공) | **나쁜 버전 100% 승격** (59초) | 안 울림 | **195개** (60초 중 29.6%) | 61.6s 넘게 (되돌릴 때까지 계속) |

읽는 법
- 감지 17초 = 분석 Job 파드가 뜨는 시간(몇 초) + 5초 간격으로 2번 실패. 분석 간격·failureLimit 를 줄이면 이 숫자가 준다.
- 에러 29개 ≈ 17초 × 초당 약 8.5개 요청 × 25%(카나리 비율) = 36개 추정과 비슷하다. **카나리 비율 × 감지 시간 = 사용자 피해** 라는 걸 숫자로 확인. 첫 단계를 10% 로 낮추면 같은 감지 시간에 피해가 절반 이하.
- 알림은 abort 뒤 약 20초 늦게 온다 (Rollouts 지표를 15초마다 긁고, 15초마다 평가). 자동 롤백은 알림을 기다리지 않으니 알림은 "사람에게 알리기" 용이다.
- 이 표는 kubectl 모드(t0 = 나쁜 버전을 넣은 순간)다. git 모드는 앞에 Argo CD 가 push 를 알아채는 시간(1단계 측정값)이 더해진다 【미검증】 이 컨테이너엔 Argo CD 가 없다 (이미지 저장소 접근 차단).
- 깨뜨리기 결과: 분석이 안정 버전을 보면 매번 성공하니 나쁜 버전이 59초 만에 100% 가 됐다. 에러는 기본의 약 7배(195개)이고 되돌리기 전까지 계속 난다. **RolloutAborted 알림도 안 울린다** (abort 가 없었으니). 이 장애는 지표 쪽 알림(5xx 비율, 아래 셀프 연습)이 있어야 잡힌다.
- 더 나쁜 덤: 좋은 버전으로 되돌리는 배포를 냈더니 **그 좋은 버전이 abort 됐다.** 분석이 이번엔 "안정 버전 = 지금은 나쁜 버전" 을 봐서 실패했기 때문이다 (`Metric "canary-http-200" assessed Failed due to failed (2) > failureLimit (1)`). 분석 주소를 고친 뒤 `kubectl argo rollouts retry rollout api -n tenant-a` 로 다시 시도해서 Healthy 로 돌아왔다. RB-03 에 이 순서를 넣었다.

### 8.4 시나리오 4: 테넌트 침범 시도 (`results/s4-tenant-breach.csv`, `results/s4-tenant-breach-calico.csv`)

| 시도 | 대역 (kindnet) | 대역 + Calico v3.32 | Calico 에서 tenant-b 정책 지움 (깨뜨리기) |
|---|---|---|---|
| N1 tenant-a Service | FAIL (http 200) | PASS (000, 3.4s 타임아웃) | PASS |
| N2 tenant-a 파드 IP 직접 | FAIL (http 200) | PASS | PASS |
| N3 API 서버 | FAIL | PASS | **FAIL (http 403)** |
| N4 메타데이터 169.254.169.254 | FAIL | PASS | **FAIL (http 403)** |
| R1 Secret 읽기 (RBAC) | PASS (0.1s) | PASS | PASS |
| R2 파드 만들기 (RBAC) | PASS | PASS | PASS |
| P1 privileged + hostPath (PSA) | PASS | PASS | PASS |
| Q1 CPU 4코어 (LimitRange) | PASS | PASS | PASS |
| D1 TenantPolicyDenied 알림 | P1 뒤 **28s** firing | (Prometheus 안 깖) | |

읽는 법
- **N1~N4 가 kindnet 에서 FAIL 인 건 정책이 틀려서가 아니다.** kindnet 은 kind v0.24 부터 NetworkPolicy 를 집행하지만(kube-network-policies), 이 클라우드 컨테이너의 커널이 그 구현(nftables)을 못 돌려서 정책이 그냥 무시됐다. 같은 `standin/targets.yaml` 을 Calico 를 깐 두 번째 kind 클러스터에 넣으니 8/8 PASS. 맥의 kind(kindnet)나 3단계 Cilium 에선 정상 동작할 것이다 【추정】. **CNI 가 NetworkPolicy 를 실제로 집행하는지는 정책 YAML 만 봐선 모른다. 이 스크립트처럼 한 번 뚫어 봐야 안다.**
- 깨뜨리기: tenant-b 정책을 지워도 N1·N2 는 막힌다. **tenant-a 쪽 ingress 정책**이 막기 때문이다 (방어가 양쪽에 있다). 대신 tenant-b 에서 나가는 egress 제한이 사라져서 API 서버와 메타데이터 주소에 닿았다. 403 은 연결은 됐고 그 뒤에서(API 서버 인증, 여기선 컨테이너의 프록시) 거절했다는 뜻이다. EC2 에선 메타데이터 주소가 노드 IAM 자격증명을 준다 → 7단계 전에 IMDSv2 hop limit 1 도 같이 건다 (RB-04).
- RBAC·PSA·LimitRange 는 API 서버 안에서 바로 거절해서 0.1~0.2초. 알림은 지표 긁기·평가 주기 때문에 28초 늦다. 막는 건 즉시, 사람이 아는 건 30초 뒤.

### 8.5 측정 환경 메모

- 이 컨테이너는 cgroup v1 이고 권한이 좁아서 kind 를 띄우려고 몇 가지를 손봤다 (`failCgroupV1: false`, oom_score_adj 를 0으로 바꾸는 runc 래퍼 이미지, quay.io 차단으로 Argo Rollouts 를 소스에서 빌드). **맥 Docker Desktop 에선 다 필요 없다.** `standin/kind-config.yaml` 은 맥 기준 그대로다.
- 노드 다운은 `docker pause` 로 흉내 냈다 (kubelet 이 멈춰서 하트비트가 끊김 = 노드 전원 차단과 같은 신호). EC2 에서 진짜 스팟 회수는 AWS FIS 로 (1.7 표) 【미검증】.

---

## 9. 결정 표 (Jeong 이 채움 → Claude 가 `decisions/2026-10-26.md` 로 옮김)

| 결정 | 선택 | 대안 | 이유 | 측정값 | 심사 항목 |
|---|---|---|---|---|---|
| 죽은 노드 파드를 얼마나 기다릴까 (tolerationSeconds) | ___s | 기본 300s / 5s | | 복구 300s → ___s | 완성도·데모, 클라우드 활용 |
| 흩어 놓기 (whenUnsatisfiable + nodeTaintsPolicy) | ___ + ___ | ScheduleAnyway / DoNotSchedule+Ignore | | 평소 쏠림 ___회, 노드 다운 후 Pending ___ | 클라우드 활용 |
| PDB minAvailable | ___ | replicas 와 같게 / 0 / 비율(50%) | | spot drain ___s | 장애 대응 |
| 알림 for | 노드 ___ / 파드 부족 ___ | 0s / 1m / 5m | | 감지 ___s | 완성도 |
| 장애 주입 도구 | 스크립트 | Chaos Mesh / Litmus / AWS FIS | 1.7 표 | | 팀 개발(대안 문서화) |

---

## 10. 이 단계가 끝난 상태 (7단계 EC2 가 이걸 전제로)

| 항목 | 값 |
|---|---|
| 측정 CSV | `results/s1-node-down.csv`, `s2-noisy-neighbor.csv`, `s3-bad-deploy.csv`, `s4-tenant-breach.csv` |
| 방어 설정 | 함수 template 에 tolerations(not-ready/unreachable) + topologySpreadConstraints, PDB `hello`(tenant-a), 2단계 Prometheus 에 kube-state-metrics·configmapReload 켜짐 + 알림 규칙 그룹 `fault-injection` 5개 |
| 런북 | `runbooks/RB-01` ~ `RB-04`, 알림 규칙의 `runbook` 주석이 각 파일을 가리킨다 |
| 7단계에서 바꿀 것 | `s1-node-down.sh` 의 `docker pause` → EC2 인스턴스 정지 또는 AWS FIS 스팟 회수 예고. exec 노드 그룹 2대 이상(AZ 2개) |

---

## 핵심 결정 3개 (+대안)

| 결정 | 이 PoC 의 선택 | 대안과 버린 이유 |
|---|---|---|
| 1. 장애 주입 도구 | **kubectl + docker 스크립트** | (가) Chaos Mesh: 종류가 많고 GitOps 로 실험을 관리할 수 있지만 노드 단위 장애가 기본 기능이 아니고 특권 DaemonSet 이 깔린다. (나) Litmus: MongoDB 까지 와서 무겁다. (다) AWS FIS: 진짜 스팟 예고를 보낼 수 있어 7단계 후보, 로컬에선 못 씀 |
| 2. 감지 기준 | **합성 프로브(사용자 시점) + Prometheus 알림 + 쿠버네티스 상태, 세 겹을 같은 t0 로** | (가) 알림만: 알림이 늦거나 틀려도 모른다. (나) 쿠버네티스 상태만: "파드 Ready" 인데 사용자는 실패하는 50초를 놓친다(4.1 이 증거) |
| 3. 노드 다운 대응 | **tolerationSeconds 20 + 흩어 놓기(DoNotSchedule + nodeTaintsPolicy Honor + matchLabelKeys) + PDB(minAvailable 1)** | (가) node-monitor-grace-period 를 줄이기: kind 에선 되지만 EKS 같은 관리형에선 못 바꾸고, 너무 줄이면 네트워크 흔들림에 노드를 오판. (나) ScheduleAnyway: 노드가 죽어도 새 파드는 뜨지만 평소에 한 노드에 몰리는 때가 생긴다 (8절 실측 2/2). (다) DoNotSchedule 만: 고르게는 되지만 죽은 노드도 자리로 세서 새 파드가 Pending (8절 실측 timeout). (라) PDB = replicas: drain 이 막혀 스팟 회수가 예고 없는 장애로 바뀜 (4.4) |

## 셀프 연습 1개

"네트워크가 느려지면?" 을 직접 만든다. 공격자 파드 대신 tenant-a 의 hello 파드 하나에 지연 200ms 를 넣고 프로브 p95 가 어떻게 되는지 잰다.
- 힌트 1 (스크립트로): kind 노드 안에서 `tc qdisc add dev <파드 veth> root netem delay 200ms`. 파드의 veth 찾기가 퍼즐이다.
- 힌트 2 (도구로): Chaos Mesh 를 깔고 `NetworkChaos`(action: delay, latency: 200ms, selector: app=hello, mode: one) 하나. https://chaos-mesh.org/docs/simulate-network-chaos-on-kubernetes/
- 둘 중 하나를 골라 1.7 표에 "직접 써 보니" 한 줄을 더하면 통과.

## 검증 명령과 기대 출력

```bash
grep -rn '___' defenses gitops | grep -v '빈칸 ___'
# 기대: 출력 없음 (빈칸 다 채움. 파일 맨 위 "빈칸 ___ N개" 설명 줄은 빼고 본다)

kubectl -n tenant-a get pdb hello
# 기대: MIN AVAILABLE 1, ALLOWED DISRUPTIONS 1

kubectl -n tenant-a get deploy hello -o jsonpath='{.spec.template.spec.tolerations[*].tolerationSeconds}{"\n"}'
# 기대: 고른 초 두 개 (예: 20 20)

kubectl get --raw /api/v1/namespaces/monitoring/services/prometheus-server:80/proxy/api/v1/rules | grep -o '"name":"[A-Za-z]*"' | sort -u
# 기대: FnNodeNotReady, FnReplicasUnavailable, RolloutAborted, TenantPolicyDenied, TenantQuotaNearLimit (+ 그룹 이름 fault-injection)

wc -l results/*.csv
# 기대: s1 ≥ 7줄 (헤더 + 방어 전 hard/spot + 방어 후 hard 3·spot 3), s2 ≥ 3, s3 ≥ 4, s4 ≥ 9

./scripts/s4-tenant-breach.sh | tail -1
# 기대: "결과: 전부 막힘 (8/8 PASS)"
```
