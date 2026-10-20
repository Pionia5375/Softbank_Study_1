로드맵 위치: 3주차 10/21~ / FaaS PoC 01~06 한 번에 올리기 / 본선 연결점: 주제 공개 뒤 "이미 돌아가는 레퍼런스 플랫폼"에서 30%만 고치는 출발점이자, 11/1 셋업 드릴 30분 게이트의 실제 스크립트

# PoC 전체 실행 안내 (정답본 기준)

10/20 방향 전환: 단계마다 빈칸(`TODO(human)`)을 채우는 대신, **완성본을 먼저 끝까지 돌리고 그다음 분석**한다. 분석은 [ANALYSIS.md](ANALYSIS.md).

## 0. 무엇이 바뀌었나 (10/20, Claude)

- `poc/02~07` 의 원래 자리 파일을 `solution/` 정답본으로 덮었다. 그래서 Argo CD 가 Git 에서 읽어 가는 파일(원래 자리)이 이제 완성본이다. `solution/` 폴더는 비교용으로 그대로 둔다.
  - 빈칸 버전은 Git 태그 `poc-skeleton-2026-10-20` 에 남아 있다. 보고 싶으면 `git show poc-skeleton-2026-10-20:poc/02-rollouts/app/rollout.yaml`.
  - `01-argocd` 는 Jeong 이 직접 채운 것을 그대로 둔다(bye-fn 포함).
- 단계 간 이음새에서 고친 것 두 개.
  1. `03/gitops/tenants-appset.yaml` 이 `solution/` 경로를 보던 것을 원래 자리(`tenants/`, `charts/tenant`)로 바꿈. 07 의 root-app, placement-check 도 같은 이유로 바꿈. 이제 분석할 때 원래 자리 파일을 고치면 바로 클러스터에 반영된다.
  2. `03/tenants/tenant-a.yaml` 에 `network.allowFromNamespaces: [knative-serving, kourier-system]` 추가. 5단계 함수(`tenant-a/hello`)로 가는 요청은 Kourier(입구)나 activator(knative-serving)를 거쳐 들어오는데, 3단계 default-deny 가 이걸 막아서 **함수는 READY 인데 curl 이 응답을 못 받는** 상태가 됐을 것이다. 5단계 README 3절에 【미확인】으로 적혀 있던 칸이다.
- 그 밖의 이음새는 확인해 보니 맞물렸다 (아래 표).

| 이음새 | 확인 결과 |
|---|---|
| 클러스터 이름·컨텍스트 | 01~05 전부 kind `faas` / `kind-faas`. 06 대역만 `chaos` |
| 3·4단계 재생성이 02를 지움 | 맞다. 그래서 이 스크립트는 최종 모양 클러스터를 한 번 만들고 02를 그 위에 다시 깐다 |
| 노드 풀 | 04 kind-config: system(taint 없음) / build·exec(`pool=<값>:NoSchedule`). 05 빌드 Job·ksvc 템플릿의 nodeSelector·toleration 과 일치 |
| 레지스트리 | 04 setup.sh 가 노드에 `kind-registry:5000` 과 `localhost:5001` 둘 다 등록. 05 는 push `kind-registry:5000`, pull `localhost:5001@sha256` 로 씀 → 일치 |
| 테넌트 라벨 | 03 차트가 `tenant=<이름>` 을 붙이고, 05 가 `faas.tenant-label: tenant` 로 확인 → 일치 |
| Knative 기능 플래그 | 04 patch 가 nodeselector·tolerations·runtimeclassname 을 켬. 05 ksvc 가 앞의 둘을 씀 → 일치 |
| 포트 | 맥 8080 = Argo CD UI, 8081 = Kourier, **8090 = 컨트롤 플레인** (05 README 는 8080 으로 port-forward 해서 Argo CD UI 와 겹친다. 스크립트는 8090) |
| 06 PDB | `app=hello` 를 고르는데, 진짜 클러스터의 tenant-a 에는 그 라벨 파드가 없다(Knative 파드 라벨은 다르다). 그래서 06은 대역 클러스터에서 돌린다 |

클라우드 쪽에서 돌려 본 것: `05` 컨트롤 플레인 테스트 8개 통과, MCP 서버 pytest 19개 통과, 02~06 매니페스트 30개 kubeconform 통과, `run-all.sh` 문법 검사. **클러스터 위 실행은 아직 아무도 안 해 봤다** (클라우드 컨테이너에선 kind 파드가 안 뜬다). 맥에서 처음 돌리는 게 첫 검증이다.

## 1. 개념: 이 스크립트가 하는 일

단계별 README 는 01 → 02 → 03(클러스터 재생성) → 04(또 재생성) → 05 순서다. 03·04 가 클러스터를 지울 때마다 앞 단계에서 손으로 깐 것(02 의 Rollouts·Prometheus)이 사라진다.

그래서 `run-all.sh` 는 순서를 바꾼다.

```
platform   = 04 rebuild-cluster.sh   최종 모양 클러스터 + Cilium + Argo CD(01) + 레지스트리·Knative·gVisor + 빌드 v1 + 함수 3개
rollouts   = 02                      Argo Rollouts + Prometheus(Helm) → podinfo Application
tenants    = 03                      테넌트 공장(ApplicationSet) → tenant-a/b 울타리 → 각 테넌트의 hello
control-plane = 05                   컨트롤 플레인 이미지 → kind 노드에 싣기 → Argo CD 로 배포 → 함수 하나 배포
check      =                         전체 상태, 함수 2개 호출, 격리 실험(네트워크)
chaos      = 06 (따로)               대역 클러스터 kind-chaos. faas 와 별개
```

단계마다 `[N s]` 를 찍고 끝에 단계별 시간 표가 나온다. 이게 셋업 드릴 기록이다.

## 2. 준비 (맥, 처음 한 번)

```bash
cd ~/softbank_study_1/Softbank_Study_1
git switch main && git pull origin main
#   완성본과 run-all.sh 받기
brew install kind kubectl helm cilium-cli
#   이미 있으면 "already installed". cilium-cli = Cilium 설치·상태 확인 명령(cilium)
brew install argoproj/tap/kubectl-argo-rollouts
#   (선택) kubectl argo rollouts get rollout ... 로 카나리 진행을 나무 모양으로 본다
```

- Docker Desktop → Settings → Resources 에서 메모리 **10GB 이상**, CPU 6 이상 권장. 노드 4개 + Argo CD + Knative + Prometheus + 자바 컨트롤 플레인이 다 system 노드 하나에 몰린다.
- 지금 떠 있는 1단계 클러스터 `faas` 는 스크립트가 지우고 다시 만든다. Argo CD 상태도 같이 사라지지만 Git 에 다 있어서 괜찮다. **1단계 측정 CSV(`poc/01-argocd/results/sync-times.csv`)가 맥에만 있다면 먼저 커밋·push 해 둔다.**

## 3. 실행

```bash
time poc/run-all.sh 2>&1 | tee /tmp/run-all.log
#   time  = 전체 걸린 시간을 끝에 찍는다
#   2>&1  = 에러 출력도 같은 화면으로
#   tee   = 화면에도 보여 주고 파일(/tmp/run-all.log)에도 저장. 막히면 이 파일을 붙여 주면 된다
```

처음엔 30~45분 걸릴 것 【추정】 (이미지 다운로드, 자바 빌드). 두 번째부터는 캐시 덕에 짧아진다.

한 단계만 다시 하고 싶으면 이름을 준다. 예: `poc/run-all.sh tenants check`.

### 단계별 기대 출력

**preflight**
```
  ok  docker ... ok  git
  Docker: 8 CPU, 1xxxxxxxxxx bytes
  빈칸 없음
```

**platform** (가장 길다. 04 rebuild-cluster.sh 의 1/6~6/6 이 그대로 나온다)
```
[..s] 2/6 새 클러스터 (노드 풀 라벨 + taint)
NAME                 STATUS     ROLES           ...  POOL
faas-control-plane   NotReady   control-plane
faas-worker          NotReady   <none>               system
faas-worker2         NotReady   <none>               build
faas-worker3         NotReady   <none>               exec
...
결과: ok, NN.Ns, 노드 faas-worker2          ← 빌드 Job 이 build 노드에서 끝남
  root: Synced/Healthy
  hello-fn: Synced/Healthy
  faas-functions: Synced/Healthy
```
- NotReady 는 Cilium 깔기 전이라 정상. 3/6 이 끝나면 Ready 가 된다.

**rollouts**
```
Release "argo-rollouts" does not exist. Installing it now.
...
  podinfo: Synced/Healthy
```

**tenants**
```
applicationset.argoproj.io/tenants created
  tenant-a: Synced/Healthy
  tenant-b: Synced/Healthy
  tenant-a-hello: Synced/Healthy
  tenant-b-hello: Synced/Healthy
```

**control-plane**
```
접수: buildId=hello-xxxxxxxxxx
  0.0s  BUILDING
  ..s  DEPLOYING
  ..s  READY
빌드 ..s + 반영 ..s = 총 ..s, 첫 요청 ..ms (HTTP 200)
```
- 이 숫자는 `poc/05-control-plane-mcp/results/deploy-times.csv` 에도 한 줄 쌓인다.

**check**
```
NAME ... POOL                      ← 노드 4줄
NAME             SYNC STATUS   HEALTH STATUS
faas-functions   Synced        Healthy
hello-fn         Synced        Healthy
platform-05      Synced        Healthy
podinfo          Synced        Healthy
root             Synced        Healthy
tenant-a ... tenant-b-hello        ← 전부 Synced/Healthy (bye-fn 도)
-- 04 함수 (runc) 호출
{... "cold": ...}                  ← JSON 한 줄
-- 05 함수 (tenant-a/hello) 호출
{"hello": "jeong", "version": 1}   ← samples/hello-v1.py 의 응답
-- 03 격리 실험 (네트워크만)
  PASS  net: a -> a (같은 테넌트)  기대=OK
  PASS  net: a -> b (다른 테넌트)  기대=BLOCKED
  ...                              ← 5줄 전부 PASS
==== 단계별 시간
  platform ...s / rollouts ...s / tenants ...s / control-plane ...s
```

붙여 줄 것: `==== 단계별 시간` 아래 전부, 그리고 check 단계 출력. 실패하면 `/tmp/run-all.log` 의 마지막 40줄.

## 4. 막히면 (흔한 순서)

1. **platform 3/6 Cilium 에서 오래 멈춤**: `cilium status` 로 어떤 파드가 안 떴는지. Docker 메모리 부족이 흔하다.
2. **hello-gvisor 만 안 뜸 (faas-functions Degraded)**: gVisor 가 Docker Desktop 에서 안 도는 경우. 04 README "9절 보충" 순서대로. 30분 넘으면 범위를 줄인다: gVisor 측정은 7단계(EC2)로 넘기고 runc 로만 간다. 나머지 단계는 계속 진행해도 된다.
3. **빌드 Job 실패 (`429 Too Many Requests`)**: Docker Hub 다운로드 한도. 04 README "9절 보충"의 미러 방법(golang 이미지를 kind-registry 에 미리 넣기). 05 단계는 `python:3.12-slim` 도 같은 방법.
4. **tenant-a 가 Healthy 가 안 됨**: `kubectl -n argocd describe application tenant-a | tail -20`. ApplicationSet 이 Git 을 읽는 데 3분 걸릴 수 있다(폴링). 급하면 `kubectl -n argocd annotate applicationset tenants argocd.argoproj.io/refresh=true`.
5. **control-plane 의 deploy-fn 이 BUILDING 에서 안 넘어감**: `kubectl -n faas-build get pods` → Pending 이면 build 노드 taint/라벨, ImagePullBackOff 면 kaniko 이미지. READY 인데 HTTP 000/타임아웃이면 이번에 고친 NetworkPolicy 가 반영됐는지: `kubectl -n tenant-a get networkpolicy allow-from-namespaces`.
6. **포트 8081 이 이미 사용 중**: `lsof -i :8081` 로 무엇이 쓰는지 보고 끈다.

## 5. 6단계 대역 클러스터 (선택, 메모리 여유가 있을 때)

```bash
poc/run-all.sh chaos
#   kind-chaos 클러스터를 따로 만들고 Rollouts, 대상(tenant-a/b), Prometheus, 알림 규칙 5개를 넣는다
#   kubectl 대상이 kind-chaos 로 바뀐다. faas 로 돌아가려면: kubectl config use-context kind-faas
cd poc/06-fault-injection
LABEL=방어전 ./scripts/s1-node-down.sh hard 1
#   exec 노드 하나를 docker pause 로 얼려서 "노드가 죽었다" 를 만들고, 사용자 쪽 에러가 끝날 때까지 잰다
./scripts/s3-bad-deploy.sh kubectl 1
#   항상 500 을 내는 버전을 카나리로 넣고, 자동 롤백까지 걸린 시간을 잰다
./scripts/s4-tenant-breach.sh
#   tenant-b 가 tenant-a 를 공격하는 8가지 시도 → PASS/FAIL 표
```
- 메모리가 모자라면 `kind delete cluster --name faas` 로 faas 를 지우고 해도 된다. faas 는 `poc/run-all.sh` 로 다시 세우면 된다.
- 06 숫자는 Claude 가 이미 대역에서 재 둔 것이 `results/*.csv` 에 있다. 맥 숫자와 비교하면 된다.

## 핵심 결정 3개 (+대안)

| 결정 | 선택 | 대안과 버린 이유 |
|---|---|---|
| 1. 학습 순서 | 완성본을 먼저 끝까지 돌리고, 분석하면서 설정 하나씩 깨뜨려 보기 | (가) 단계별 빈칸 채우기: 이해는 깊지만 10/27 전에 06까지 못 갈 위험. (나) 돌리기만: 본선(개인 평가)에서 설명·수정을 못 한다 |
| 2. 클러스터 순서 | 최종 모양 클러스터 한 번 + 층 쌓기 | (가) README 순서대로 재생성 2번: 02를 두 번 깔아야 하고 드릴 시간이 늘어난다 |
| 3. 05 배포 붙이는 법 | `kubectl apply` 로 platform-05 Application 을 직접 | (가) 01 apps/ 폴더에 복사 + push (README 방식, App of Apps): 재생성 때 자동으로 돌아오는 장점. 드릴이 안정되면 이쪽으로 바꾸고 숫자를 비교 |

## 셀프 연습 1개

`run-all.sh` 를 한 번 더 돌려서 두 번째 단계별 시간을 첫 번째와 나란히 적는다. 어느 단계가 가장 많이 줄었고, 왜 그런지(무엇이 캐시됐나) 한 줄로.

## 검증 명령과 기대 출력

```bash
kubectl -n argocd get applications --no-headers | awk '{print $2, $3}' | sort | uniq -c
#   기대: "10 Synced Healthy" 처럼 한 줄 (Application 개수는 bye-fn 포함 10개)
curl -s -H "Host: hello.tenant-a.faas.local" localhost:8081 -d jeong
#   기대: {"hello": "jeong", "version": 1}
poc/03-tenant-isolation/scripts/test-isolation.sh
#   기대: 마지막 줄 FAIL 0
```
