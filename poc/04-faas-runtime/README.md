로드맵 위치: 3주차 10/24 (토) / FaaS 본체: 노드 풀 + 클러스터 안 빌드 + Knative 0↔N + gVisor / 본선 연결점: 작년 본선 주제가 FaaS 였고(【사실】 career/03 §6), 2위 Green 이 Knative + gVisor 였다. "콜드 스타트 몇 ms, gVisor 로 바꾸면 몇 ms 더, 빌드 중에도 함수 p95 는 몇 ms" 를 숫자로 말할 수 있게 되는 날

# PoC 4단계: 함수 런타임과 빌드

오늘 끝나면 되는 것 4개
1. 노드 3대가 역할별 풀(system / build / exec)로 나뉘어 있고, 빌드는 build 풀에서만, 함수는 exec 풀에서만 도는 걸 `-o wide` 로 봤다
2. 소스 → 클러스터 안 Kaniko 빌드 → 레지스트리 → Knative 함수까지 한 줄(`scripts/build.sh`)로 돌고, 빌드 시간이 캐시 있음/없음으로 숫자가 있다
3. 함수가 요청이 없으면 0개로 줄고, 요청이 오면 다시 뜬다. 그 콜드 스타트가 runc / gVisor 각각 p50·p95 숫자로 있다
4. "웜 1개 유지" 와 "빌드가 옆에서 도는 중" 이 함수 응답 시간을 얼마나 바꾸는지 숫자가 있다

진행 방식 (1~3단계와 같다)
- 개념(1절) → 파일 지도(2절) → 단계마다: 파일 주석을 위에서 아래로 읽기 → 빈칸 채우기 → 명령(한 줄씩 설명) → 확인 질문 → 출력 붙여 주기.
- 빈칸은 `___` 와 `TODO(human)` 주석. 공식 문서 링크는 각 파일 맨 위에 있다.
- 한 파일에 30분 넘게 막히면 `solution/` 의 같은 경로 파일을 본다 (`solution/README.md`).
- 분담: 매니페스트 8개(빈칸 45개)는 Jeong. 설치·빌드·측정 스크립트 7개는 Claude 완성본 → 읽고 실행만.

---

## 1. 개념 (0부터)

### 1.1 FaaS 가 하는 일

FaaS(Function as a Service) 사용자는 "코드" 만 올린다. 플랫폼이 나머지를 한다.

1. **빌드**: 코드 → 컨테이너 이미지. 사용자는 Dockerfile 도 몰라도 된다(오늘은 Dockerfile 을 우리가 준다)
2. **배포**: 이미지를 클러스터에 띄울 준비. 주소(URL)를 하나 준다
3. **스케일**: 요청이 없으면 **0개**. 요청이 몰리면 N개. 0개일 때 첫 요청이 오면 그때 띄운다 → 이 첫 요청이 느린 게 **콜드 스타트**
4. **격리**: 남의 코드(사용자 코드)를 내 서버에서 돌린다 → 그 코드가 서버를 뚫지 못하게

오늘 이 4개를 하나씩 붙인다: 빌드 = Kaniko, 배포·스케일 = Knative Serving, 격리 = gVisor, 그리고 이걸 어디서 돌릴지 = 노드 풀.

### 1.2 노드 풀: 라벨 + taint + toleration + nodeSelector

Lab 05 에서 한 것의 확장. 네 단어만 정확히.

| 단어 | 어디에 붙나 | 뜻 |
|---|---|---|
| 라벨 `pool=build` | 노드 | 이름표. 그 자체로는 아무것도 막지 않는다 |
| taint `pool=build:NoSchedule` | 노드 | 출입 금지. 허가증 없는 Pod 는 **새로** 못 온다(이미 있는 건 그대로) |
| toleration | Pod | 허가증. "pool=build taint 는 괜찮다". 허가증이 있다고 거기로 **가는** 건 아니다 |
| nodeSelector `pool: build` | Pod | "이 이름표 노드에만 가겠다". 이게 있어야 거기로 **간다** |

그래서 "build 노드에는 빌드만, 빌드는 build 노드에서만" = taint(남을 막음) + toleration(나는 통과) + nodeSelector(나는 거기로만) **세 개를 다** 써야 한다. 하나라도 빠지면 어떻게 되는지가 오늘 확인 질문이다.

system 풀에는 일부러 taint 를 안 건다. Argo CD·Knative 설치 파일은 toleration 이 없다 → taint 가 걸린 build·exec 에는 못 가고 → 자동으로 system 으로 온다. 설치 파일을 하나도 안 고치고 플랫폼 부품을 모으는 방법이다.

클라우드에선 풀마다 기계 종류가 다르다 (예: build = CPU 큰 스팟, exec = 메모리 중간 온디맨드+스팟, system = 작은 온디맨드 2대). kind 에선 노드가 전부 같은 맥 위 컨테이너라 **스케줄링 분리만** 연습되고 **CPU 분리는 안 된다**. 이게 측정 결과를 읽을 때 중요하다 (8.3절).

### 1.3 클러스터 안에서 이미지 빌드: Kaniko

- 이미지 빌드 = Dockerfile 의 줄(FROM, COPY, RUN …)을 차례로 실행하고, 줄마다 바뀐 파일을 "레이어" 로 묶는 일. 맥에선 Docker Desktop 이 한다.
- 클러스터 안 Pod 에는 Docker 가 없다. Docker 를 넣으면(Docker-in-Docker) privileged 권한이 필요해서 노드를 통째로 내주는 셈이다.
- **Kaniko** 는 Docker 없이, 자기 컨테이너 안의 파일 시스템에서 직접 RUN 을 실행하고 레이어를 만든다. 일반 Pod 로 돈다 → Job 하나로 빌드.
- 만든 이미지는 **레지스트리**(이미지 저장소)에 올린다. 오늘은 맥에 `kind-registry` 컨테이너를 하나 띄운다. Kaniko 가 여기 올리고, 노드가 여기서 받는다.
- **캐시**: `RUN go build` 같은 줄의 결과를 레지스트리에 저장해 두고, 다음 빌드에서 입력이 같으면 다시 안 돌린다. 캐시 있음/없음 시간 차이가 오늘 숫자 하나.
- 【사실】 Kaniko 원본 저장소(GoogleContainerTools/kaniko)는 2025-06 에 보관(archived)됐다. 이미지는 아직 받아진다(오늘 `v1.23.2` 로 검증). Chainguard 가 포크를 이어 가고 있다(`chainguard-dev/kaniko`, v1.25.x). 대안은 핵심 결정 2.

### 1.4 Knative Serving: 0↔N 의 구조

`kind: Service` (ksvc) 한 장을 넣으면 Knative 가 이걸 만든다.

```
ksvc hello-runc
 ├─ Configuration ─ Revision hello-runc-00001   (spec 이 바뀔 때마다 00002, 00003 … 새 버전)
 │                    └─ Deployment → Pod [ user-container(우리 함수) + queue-proxy(Knative 가 끼워 넣는 옆 컨테이너) ]
 └─ Route            (주소 hello-runc.fn-runtime.faas.local → 어느 Revision 으로 몇 %)
```

요청 길: 맥 `localhost:8081` → 노드 31080 → **Kourier**(입구, Envoy) → Pod 가 있으면 바로 Pod / **없으면 activator**

부품 셋 (전부 system 풀에 뜬다)
- **queue-proxy**: Pod 마다 붙어서 "지금 동시 요청 몇 개" 를 센다.
- **autoscaler**: queue-proxy 숫자를 모아 "Pod 몇 개 필요" 를 계산한다. 목표는 Pod 하나당 동시 요청 `target` 개.
- **activator**: Pod 가 0개일 때 요청을 **붙잡아 두고**, autoscaler 에게 "하나 띄워" 하고, 뜨면 넘겨준다. 그래서 0개여도 요청이 실패하지 않고 느려질 뿐이다.

0 으로 가는 시간 = `window`(요청이 끊긴 걸 판단하는 구간, 기본 60s, 오늘은 6s) + `scale-to-zero-grace-period`(기본 30s) + Pod 종료. 그래서 측정 1회에 40초쯤 기다린다.

### 1.5 컨테이너 런타임과 gVisor

- 컨테이너는 VM 이 아니다. 컨테이너 안 프로그램의 시스템 콜(파일 열기, 네트워크 등 커널에 하는 부탁)은 **호스트(노드) 커널이 직접** 받는다. 커널에 버그가 있으면 컨테이너 하나가 노드 전체를 뚫을 수 있다.
- **runc**: 지금까지 쓴 기본 런타임. 커널 기능(namespace, cgroup)으로 칸막이만 친다.
- **gVisor(runsc)**: 컨테이너와 호스트 커널 사이에 **Sentry** 라는 "가짜 커널" 프로그램을 끼운다. 시스템 콜을 Sentry 가 먼저 받아서 처리하고, 호스트 커널에는 훨씬 적은 종류의 시스템 콜만 간다. → 남의 코드를 돌리는 FaaS 에 맞다.
- 대가: (1) 시스템 콜이 많은 함수(파일·네트워크 많이)는 느려진다. 계산만 하는 함수는 거의 같다. (2) Sentry 가 Pod 마다 메모리를 더 먹는다. (3) 시작이 조금 느리다.
- 함수 응답의 `kernel` 칸을 보면 바로 구분된다: runc 면 노드 커널 버전(예: `6.x`), gVisor 면 gVisor 가 흉내 내는 버전(【추정】 `4.4.0`).
- 쿠버네티스에서 고르는 법: 노드 containerd 에 `runsc` 라는 런타임을 등록(Claude 스크립트) → **RuntimeClass** 오브젝트로 이름 `gvisor` 를 붙임(Jeong) → Pod(ksvc)에서 `runtimeClassName: gvisor`(Jeong).
- 【사실】 2026-07 부터 gVisor 배포는 `runsc` 하나가 아니라 `runsc` + `containerd-shim-runsc-v1` + `gvisor-bin/` 폴더 묶음이다 (https://github.com/google/gvisor/blob/master/g3doc/user_guide/install.md). 옛 블로그처럼 runsc 하나만 복사하면 안 돈다.

### 1.6 콜드 스타트를 쪼개면

```
요청 도착 → activator 가 잡음 → autoscaler 가 0→1 결정 → 스케줄러가 노드 고름
 → (이미지 없으면 받기) → 런타임이 컨테이너 생성 (gVisor 면 Sentry 시작) → 함수 프로세스 시작
 → queue-proxy 준비 확인 통과 → activator 가 요청 넘김 → 응답
```

줄이는 수단과 대가

| 수단 | 줄이는 구간 | 대가 |
|---|---|---|
| 작은 이미지 (scratch, 정적 바이너리) | 이미지 받기, 프로세스 시작 | 디버깅 도구 없음 |
| 이미지 미리 받아 두기 (같은 노드 재사용) | 이미지 받기 | 노드 디스크 |
| `min-scale: 1` (웜 1개) | 전부 (콜드 스타트가 안 생김) | 요청 0일 때도 Pod 1개 몫 메모리·돈 |
| 웜 풀 (미리 띄운 빈 샌드박스를 함수에 배정) | 컨테이너 생성까지 | 구현 복잡. 오늘은 설계 문서 대안으로만 (예: Kubernetes SIG Agent Sandbox 의 `SandboxWarmPool` 개념 【미확인: API 이름은 확인 필요】) |
| JVM 대신 Go·네이티브 이미지 | 프로세스 시작 | 언어 제약. Spring 이면 수 초 → GraalVM native 로 ms 대 【추정】 |

### 확인 질문 (답을 스레드에 한 줄씩)

1. build 노드에 taint 만 걸고, 빌드 Job 에 toleration 만 주고 nodeSelector 를 안 주면, 빌드 Pod 는 어디로 갈 수 있나?
2. 함수가 0개일 때 첫 요청이 실패하지 않는 건 어느 부품 덕분인가?
3. gVisor 로 바꾸면 `?work=cpu` 와 `?work=io` 중 어느 쪽이 더 느려질 거라고 예상하나? 이유 한 줄.

---

## 2. 파일 지도

```
poc/04-faas-runtime/
  cluster/kind-config.yaml                 ← 1단계 (Jeong, 빈칸 8) 3단계 설정 + taint + 포트
  scripts/rebuild-cluster.sh               ← 1단계 (Claude) 셋업 드릴: 클러스터 → Cilium → Argo CD → setup.sh → 빌드 → 함수
  scripts/setup.sh                         ← 2단계 (Claude) 레지스트리·Knative·Kourier·gVisor 설치
  scripts/install-gvisor.sh                ← 2단계 (Claude) exec 노드에 runsc 설치 (setup.sh 가 부름)
  platform/knative/config-features-patch.yaml ← 3단계 (Jeong, 빈칸 4) Knative 기능 플래그
  platform/runtimeclass-gvisor.yaml        ← 4단계 (Jeong, 빈칸 5)
  functions/hello-src/                     ← 5단계 (Claude) 함수 소스: main.go, go.mod, Dockerfile
  build/kaniko-job.yaml                    ← 5단계 (Jeong, 빈칸 14) 빌드 Job
  scripts/build.sh                         ← 5단계 (Claude) 소스 → ConfigMap → Job → 시간 기록
  functions/ksvc/hello-runc.yaml           ← 6단계 (Jeong, 빈칸 6)
  functions/ksvc/hello-gvisor.yaml         ← 6단계 (Jeong, 빈칸 2)
  functions/ksvc/hello-gvisor-warm.yaml    ← 6단계 (Jeong, 빈칸 3)
  gitops/faas-functions.yaml               ← 6단계 (Jeong, 빈칸 4) 위 ksvc 3개를 Argo CD 가 깔게
  scripts/coldstart.sh                     ← 8단계 (Claude) 콜드 스타트 p50/p95
  scripts/latency.sh                       ← 8단계 (Claude) 웜 함수 p50/p95
  scripts/build-noise.sh                   ← 8단계 (Claude) 빌드 중 함수 p95
  scripts/lib.sh                           ← (Claude) 위 스크립트 공통 값 (namespace, 도메인, 8081)
  results/                                 ← 측정 CSV (git 에 올라감)
  solution/                                ← 정답본. 같은 구조 (막혔을 때만)
```

정해 둔 값 (다른 단계와 맞춘 값. 바꾸면 5단계도 바꿔야 한다)

| 항목 | 값 |
|---|---|
| 노드 풀 | 라벨 `pool=system/build/exec`, taint `pool=build:NoSchedule`, `pool=exec:NoSchedule` (system 은 taint 없음) |
| 레지스트리 | 맥에서 `localhost:5001`, 클러스터 안에서 `kind-registry:5000`. 노드는 둘 다 같은 저장소로 받는다 |
| 함수 이미지 | `kind-registry:5000/fn/hello:<태그>`, 빌드 캐시 `kind-registry:5000/fn/cache` |
| Kaniko | `gcr.io/kaniko-project/executor:v1.23.2` |
| Knative / Kourier | v1.23.0, 입구 `kourier-system/kourier` NodePort 31080 → 맥 8081 |
| 함수 주소 | `<함수>.fn-runtime.faas.local` (DNS 없음. `curl -H "Host: ..." localhost:8081`) |
| namespace | 함수 `fn-runtime`, 빌드 `fn-build` |
| gVisor | RuntimeClass `gvisor`, handler `runsc`, release `20261012.0` |

---

## 3. 단계

### 0단계: 준비

```bash
cd ~/softbank_study_1/Softbank_Study_1
git switch main && git pull origin main   # 오늘 뼈대 받기
kind version; kubectl version --client; helm version --short; cilium version --client
docker info --format '{{.NCPU}} CPU, {{.MemTotal}} bytes'
#   Docker Desktop 에 준 CPU·메모리. 노드 4개 + Knative + 빌드라 8GB 이상 권장 (Settings → Resources)
```

붙여 줄 것: 위 출력

### 1단계: 노드 풀 클러스터 (Jeong: `cluster/kind-config.yaml`)

파일을 열고 주석을 위에서 아래로 읽는다. 3단계 파일과 무엇이 다른지 먼저 본다.

```bash
diff poc/03-tenant-isolation/cluster/kind-config.yaml poc/04-faas-runtime/solution/cluster/kind-config.yaml
#   - 로 시작 = 3단계에만, + 로 시작 = 4단계에만 있는 줄. 오늘 쓸 것 = + 줄들
```

빈칸 8개 채우는 법
- `pool: ___` (system): 3단계 파일에서 그대로.
- build 의 `key / value / effect`: 1.2절 표. effect 는 문서 https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/#concepts 의 세 가지 중 "새로 오는 것만 막는" 것.
- exec 의 `___`: build 의 `kubeadmConfigPatches:` 블록 6줄을 복사해서 build → exec. **들여쓰기**가 `labels:` 와 같은 칸이어야 한다.
- `containerPort / hostPort`: setup.sh 의 `nodePort` 값과, 맥에서 비어 있는 포트(8080 은 Argo CD).

```bash
grep -n ___ poc/04-faas-runtime/cluster/kind-config.yaml
#   남은 빈칸. 출력이 없어야 한다
time poc/04-faas-runtime/scripts/rebuild-cluster.sh 2>&1 | tee /tmp/rebuild.log
#   지금은 1~5번까지만 성공하고 6번(내가 아직 안 쓴 파일)에서 멈추는 게 정상. 5번까지의 [N s] 를 본다
#   하는 일: 옛 faas 삭제 → 이 kind-config 로 생성 → Cilium·Hubble → Argo CD + root → setup.sh(2단계 내용)
kubectl get nodes -L pool
#   -L pool = pool 라벨을 열로. system/build/exec 가 하나씩
kubectl describe nodes | grep -E "^Name:|^Taints:"
#   build·exec 에만 pool=...:NoSchedule
kubectl get pods -A -o wide --field-selector spec.nodeName=faas-worker
#   system 노드(faas-worker)에 Argo CD, Knative, Kourier 가 모여 있는지. 노드 이름은 get nodes 에서 확인
```

- 3단계를 아직 안 했으면: kind-config 의 `disableDefaultCNI: false` 로 바꾸고 `NO_CILIUM=1 poc/04-faas-runtime/scripts/rebuild-cluster.sh`.

확인 질문: CoreDNS 는 어느 노드에 떠 있나? 왜 거기인가? (`kubectl -n kube-system get pods -o wide | grep coredns`)

붙여 줄 것: `get nodes -L pool`, Taints 4줄, rebuild 로그의 `[N s]` 줄들

### 2단계: 플랫폼 설치 읽기 (Claude: `scripts/setup.sh`, `install-gvisor.sh`)

1단계 rebuild 가 이미 돌렸다. 파일을 열고 단계별 주석을 읽기만 한다. 핵심 줄:

| 줄 | 하는 일 |
|---|---|
| `docker run ... --name kind-registry registry:2` | 맥에 레지스트리 컨테이너. `docker network connect kind` 로 노드들과 같은 네트워크 |
| `.../certs.d/kind-registry:5000/hosts.toml` | 노드의 containerd 에게 "이 레지스트리는 http 로" |
| `kubectl apply -f .../serving-crds.yaml` → `serving-core.yaml` | Knative 의 새 리소스 종류(CRD) 먼저, 그다음 컨트롤러 |
| `kourier.yaml` + `config-network ingress-class` | 입구를 Kourier 로 |
| `patch service kourier ... nodePort 31080` | kind 엔 LoadBalancer 가 없다 → NodePort. kind-config 의 포트 연결과 짝 |
| `config-domain faas.local` | 함수 주소 도메인 |
| `registries-skipping-tag-resolving` | Knative 는 `:v1` 을 `@sha256:...` 로 고정하려고 레지스트리에 https 로 묻는데 kind-registry 는 http → 건너뛰게. 대가: 같은 태그를 덮어쓰면 다른 이미지가 뜰 수 있다 → **빌드마다 새 태그** |
| `install-gvisor.sh` | exec 노드에만: 받기 → sha512 확인 → `docker cp` → containerd 에 `runsc` 등록 → 재시작 |

```bash
kubectl -n knative-serving get pods -o wide     # activator, autoscaler, controller, webhook, net-kourier-controller 가 Running, 전부 system 노드
curl -s localhost:5001/v2/_catalog              # 레지스트리가 맥에서 보이나. 아직 비어 있다: {"repositories":[]}
docker exec faas-worker3 runsc --version        # exec 노드(이름은 get nodes 로 확인)에 gVisor
docker exec faas-worker2 which runsc || echo "build 노드엔 없음 (정상)"
```

확인 질문: gVisor 를 exec 노드에만 깔았다. 그러면 gvisor Pod 가 실수로 build 노드에 스케줄되면 무슨 일이 생기나? 그걸 막는 장치는 4단계 어느 칸인가?

### 3단계: Knative 기능 플래그 (Jeong: `platform/knative/config-features-patch.yaml`)

Knative 는 ksvc 안의 Pod 스펙 중 일부 칸만 허용한다. nodeSelector·tolerations·runtimeClassName 은 기본이 꺼져 있다. 문서 https://knative.dev/docs/serving/configuration/feature-flags/ 에서 "Kubernetes node selector", "Kubernetes toleration", "Kubernetes runtime class" 세 항목의 **Flag name** 을 찾아 넣는다.

```bash
kubectl -n knative-serving patch configmap config-features --type merge \
  --patch-file poc/04-faas-runtime/platform/knative/config-features-patch.yaml
#   patch --type merge = 기존 ConfigMap 에 이 키들만 덧씌운다 (apply 로 통째로 바꾸면 Knative 기본 키가 날아갈 수 있다)
kubectl -n knative-serving get configmap config-features -o yaml | grep podspec-
#   세 줄이 enabled
```

### 4단계: RuntimeClass (Jeong: `platform/runtimeclass-gvisor.yaml`)

- `handler`: install-gvisor.sh 안의 `runtimes.___]` 이름.
- `scheduling`: 1.2절. 이 RuntimeClass 를 고른 Pod 에 nodeSelector·toleration 을 **자동으로** 붙여 준다 (https://kubernetes.io/docs/concepts/containers/runtime-class/#scheduling).
- `overhead`: 일단 cpu 50m / memory 64Mi 근처 추정치. 8단계 후 `kubectl top pod` 로 runc 대비 차이를 보고 고친다.

```bash
kubectl apply -f poc/04-faas-runtime/platform/runtimeclass-gvisor.yaml
kubectl run gv --rm -it --restart=Never --image=busybox:1.36 \
  --overrides='{"spec":{"runtimeClassName":"gvisor"}}' -- sh -c 'uname -r; dmesg | head -3'
#   일회용 Pod 를 gvisor 로 띄워 커널 번호와 dmesg 를 본다. nodeSelector·toleration 을 안 줬는데 exec 노드로 가면 scheduling 이 일한 것
#   기대: uname 이 노드 커널(docker exec faas-worker3 uname -r)과 다르고, dmesg 에 gVisor 의 농담 같은 시작 메시지
```

- 여기서 Pod 가 안 뜨면(`FailedCreatePodSandBox`) 9절 "gVisor 가 kind 에서 안 될 때" 로.

붙여 줄 것: 위 `kubectl run` 출력

### 5단계: 클러스터 안 빌드 (Jeong: `build/kaniko-job.yaml`, Claude: `scripts/build.sh`)

먼저 `functions/hello-src/` 세 파일을 읽는다 (main.go 맨 위 주석에 함수가 하는 일 3가지, Dockerfile 은 2단계 빌드).

빈칸 14개
- `backoffLimit / activeDeadlineSeconds / ttlSecondsAfterFinished`: 문서 https://kubernetes.io/docs/concepts/workloads/controllers/job/#handling-pod-and-container-failures 와 `#ttl-mechanism-for-finished-jobs`. 빌드 실패를 재시도할 가치가 있나? 빌드가 몇 분 넘으면 이상한가? 끝난 Job 을 언제 지울까?
- `nodeSelector / tolerations`: 1.2절 세 개 중 두 개. build.sh 가 `tolerations[0].value` 를 바꾸므로 **toleration 은 한 개만**, `nodeSelector.pool` 모양 유지.
- `--destination`: 2절 표의 함수 이미지. 태그 자리는 `$(IMAGE_TAG)`.
- `--cache-repo`: 2절 표의 캐시 저장소.
- `requests / limits`: 빌드는 짧고 굵다. requests 는 자리 계산용(작게 → 스케줄이 잘 됨), limits 는 상한(크게 → 빨리 끝남). build 노드에 빌드가 동시에 몇 개 돌 수 있어야 하나?

```bash
grep -n ___ poc/04-faas-runtime/build/kaniko-job.yaml          # 남은 빈칸 없음
poc/04-faas-runtime/scripts/build.sh v1
#   1) functions/hello-src 를 tar.gz 로 묶어 ConfigMap hello-src 로 → 2) Job 생성 → 3) 끝날 때까지 기다려 초를 잰다
#   기대 끝 줄: 결과: ok, NN.Ns, 노드 faas-worker2   ← build 노드
curl -s localhost:5001/v2/fn/hello/tags/list                  # {"name":"fn/hello","tags":["v1"]}
poc/04-faas-runtime/scripts/build.sh v1b                       # 같은 소스 다시 = 캐시가 먹는 경우
poc/04-faas-runtime/scripts/build.sh v1c
NOCACHE=1 poc/04-faas-runtime/scripts/build.sh v1d            # 캐시 끄고 = 처음 빌드와 같은 조건
cat poc/04-faas-runtime/results/build.csv
```

- `kubectl -n fn-build logs -l app=fn-build --tail=20` 으로 Kaniko 로그. `Using caching version of cmd` 줄이 캐시가 먹은 줄이다.
- Docker Hub 가 `429 Too Many Requests` 를 주면(익명 다운로드 한도) 잠깐 기다리거나, 9절의 미러 방법.

확인 질문: 첫 빌드가 두 번째보다 훨씬 느린 이유 두 가지(캐시 말고 하나 더 있다. 힌트: `FROM golang`).

붙여 줄 것: `results/build.csv`

### 6단계: 함수 3개 + Argo CD (Jeong: `functions/ksvc/*.yaml`, `gitops/faas-functions.yaml`)

- `hello-runc.yaml` 부터. 문서 https://knative.dev/docs/serving/autoscaling/scale-bounds/ 에서 하한 키 이름, `max-scale`·`target` 은 결정(아래 결정 표). nodeSelector + toleration 은 Job 에서 쓴 모양 그대로. 이미지는 5단계 v1.
- `hello-gvisor.yaml`: runtimeClassName 한 줄이 핵심.
- `hello-gvisor-warm.yaml`: min-scale 한 줄.
- `gitops/faas-functions.yaml`: 1단계 hello-fn Application 과 같은 모양. prune·selfHeal 은 "측정 중에 kubectl 로 ksvc 를 고치면 Argo CD 가 되돌린다" 를 생각하고 고른다.

```bash
kubectl apply --dry-run=server -f poc/04-faas-runtime/functions/ksvc/
#   API 서버(+ Knative webhook)에 검사만 받는다. 3단계 플래그가 빠졌으면 여기서 "must not set the field(s)" 가 나온다
#   namespace fn-runtime 이 없으면 "namespaces not found" 가 나올 수 있다. 그 줄만이면 통과
git add poc/04-faas-runtime && git commit -m "poc/04: ksvc + Application" && git push origin main
#   Argo CD 는 GitHub main 을 읽으니 push 가 먼저
kubectl apply -f poc/04-faas-runtime/gitops/faas-functions.yaml
kubectl -n argocd get application faas-functions          # Synced / Healthy
kubectl -n fn-runtime get ksvc                            # READY True 3개
kubectl -n fn-runtime get pods -o wide                    # 전부 exec 노드. 처음 만들 때 잠깐 뜨고, 6s+30s 뒤 runc·gvisor 는 0개, warm 은 1개
for f in hello-runc hello-gvisor; do curl -s -H "Host: $f.fn-runtime.faas.local" localhost:8081/; echo; done
#   kernel 칸이 서로 다르면 gVisor 가 실제로 일하는 것. cold:true = 그 Pod 의 첫 요청
```

확인 질문: 요청 직후 `kubectl -n fn-runtime get pods` 에 컨테이너가 2/2 로 보인다. 하나는 우리 함수, 다른 하나는 뭔가?

붙여 줄 것: `get ksvc`, `get pods -o wide`, curl 두 줄

### 7단계: 깨뜨렸다 고치기

Knative 기능 플래그를 하나 끄고, Argo CD 가 어디서 어떻게 실패를 보여 주는지 본다.

```bash
kubectl -n knative-serving patch configmap config-features --type merge \
  -p '{"data":{"kubernetes.podspec-tolerations":"disabled"}}'
#   toleration 칸 사용 금지 (누가 실수로 Knative 설정을 초기화한 상황)
# hello-runc.yaml 의 max-scale 을 "5" → "4" 로 바꾸고
git commit -am "poc/04: break demo" && git push origin main
#   함수 하나를 "새로 배포" 한다. Argo CD 가 이걸 클러스터에 적용하려는 순간 Knative webhook 이 검사한다
kubectl -n argocd annotate application faas-functions argocd.argoproj.io/refresh=normal --overwrite
#   polling 주기를 기다리지 말고 지금 Git 을 다시 읽어라
kubectl -n argocd get application faas-functions -o jsonpath='{.status.operationState.phase}{"  "}{.status.operationState.message}{"\n"}'
#   기대: Failed  ... must not set the field(s): spec.template.spec.tolerations
#   UI 로 보면: kubectl -n argocd port-forward svc/argocd-server 8080:80 → faas-functions → SYNC FAILED
curl -s -H "Host: hello-runc.fn-runtime.faas.local" localhost:8081/ ; echo
#   그래도 함수는 응답한다 (이전 Revision 이 그대로)
```

- 고치기: 3단계 patch 명령을 다시 실행 → 실패한 동기화를 다시 시킨다:
  `kubectl -n argocd patch application faas-functions --type merge -p '{"operation":{"initiatedBy":{"username":"jeong"},"sync":{"revision":"main"}}}'`
  (operation 칸을 쓰면 Argo CD 가 "지금 동기화" 버튼을 누른 것처럼 동작한다. 같은 커밋에서 한 번 실패한 자동 동기화는 저절로 다시 안 할 수 있어서)
- 생각할 것: 이 실패는 **함수 배포 시점**에 났고, 이미 떠 있던 함수는 멀쩡하다. 왜? 그리고 이게 본선 데모 중에 나면 어디를 먼저 볼까?

붙여 줄 것: 위 message 한 줄, 고친 뒤 `get application` 한 줄

### 8단계: 측정 (Claude 스크립트, 결과는 `results/`)

> 측정 중에는 다른 무거운 작업(빌드, 브라우저 탭 많이)을 하지 않는다. 같은 맥 CPU 를 나눠 쓴다.

#### 8.1 콜드 스타트: runc vs gVisor (각 10~20회, 함수 하나에 7~15분)

```bash
poc/04-faas-runtime/scripts/coldstart.sh hello-runc 20
poc/04-faas-runtime/scripts/coldstart.sh hello-gvisor 20
#   1회 = Pod 0개 될 때까지 기다림 → 요청 1번 → 응답 시간. 끝 줄이 요약 (p50 / p95)
#   cold=true 가 아닌 줄이 있으면 진짜 콜드 스타트가 아니었다 (그 줄은 빼고 본다)
```

#### 8.2 웜 1개 유지 + 웜 상태 응답 시간

```bash
IDLE=30 poc/04-faas-runtime/scripts/coldstart.sh hello-gvisor-warm 10
#   min-scale 1 이라 0 이 안 된다 → 30초 쉬고 요청. "오래 쉰 뒤 첫 요청" 이 콜드 스타트 대비 얼마나 빠른가
QUERY='work=cpu&ms=10' poc/04-faas-runtime/scripts/latency.sh hello-gvisor-warm
QUERY='work=io&n=200'  poc/04-faas-runtime/scripts/latency.sh hello-gvisor-warm
#   웜 Pod 에 동시 4줄 × 200회. cpu 와 io 각각 p50/p95. C=1 로도 한 번씩 (C=1 QUERY=... scripts/latency.sh ...)
#   C=4 에서 갑자기 느려지면 아래 "Claude 가 잰 값" 의 CPU limit 설명을 본다
kubectl -n fn-runtime top pod 2>/dev/null || echo "metrics-server 없음: 메모리는 스킵"
#   웜 1개가 쉬는 동안 먹는 메모리 (= min-scale 1 의 비용)
```

- runc 와 비교하려면 `hello-gvisor-warm.yaml` 을 복사해 `hello-runc-warm.yaml` (runtimeClassName 줄 삭제) 를 만들어 push 하고 같은 명령. **셀프 연습**이다.

#### 8.3 빌드 중 함수 p95

```bash
poc/04-faas-runtime/scripts/build-noise.sh hello-gvisor-warm
#   baseline(빌드 없음) → 캐시 없는 빌드를 build 풀에서 돌리는 동안 → 같은 빌드를 exec 풀에서 돌리는 동안
#   요청은 빈 요청(QUERY 없음) 동시 2줄. 함수 자체의 CPU limit 효과를 빼고 "옆에서 빌드가 도는 영향" 만 보려고
#   세 줄의 p95 를 비교. results/build-noise.csv
```

읽는 법: kind 에선 build 노드와 exec 노드가 같은 맥 CPU 를 나눠 쓴다. 그래서 `build` 줄과 `exec` 줄의 차이는 "같은 노드(=같은 컨테이너 cgroup)에서 경쟁하느냐" 만큼만 나온다. 차이가 작게 나오면 그게 정답이다 → "kind 에선 노드 풀이 스케줄링만 나눈다. CPU 까지 나누려면 기계가 달라야 한다 → 7단계(EC2)에서 다시 잰다" 를 설계 문서에 쓴다.

#### 측정표 (Jeong 이 채움)

| 항목 | 값 | 비고 |
|---|---|---|
| 셋업 드릴 (rebuild-cluster.sh 총 시간) | ___ s | Cilium·Argo CD 포함 |
| 빌드: 캐시 없음 / 있음 (각 3회 평균) | ___ s / ___ s | |
| 콜드 스타트 runc p50 / p95 (n=__) | ___ / ___ ms | |
| 콜드 스타트 gVisor p50 / p95 (n=__) | ___ / ___ ms | |
| 웜 1개, 30초 쉰 뒤 첫 요청 p50 | ___ ms | |
| 웜 gVisor `cpu 10ms` p50 / p95 | ___ / ___ ms | |
| 웜 gVisor `io n=200` p50 / p95 | ___ / ___ ms | runc 와 비교는 셀프 연습 |
| 빌드 중 p95: 없음 / build 풀 / exec 풀 | ___ / ___ / ___ ms | |

#### Claude 가 컨테이너에서 실제로 잰 값 (참고, runc 만)

환경이 다르다(리눅스 VM, CPU 4, cgroup v1, kindnet, Cilium 없음). 맥 숫자와 직접 비교하지 말고 "어느 정도 크기인지" 만 본다.

| 항목 | 값 | 메모 |
|---|---|---|
| kind 클러스터 생성 (노드 4) | 22 s | 이미지가 이미 있을 때 |
| setup.sh (레지스트리·Knative·Kourier·gVisor 설치) | 29 s | Knative 이미지를 미리 넣어 둔 상태라 맥보다 빠를 것 |
| 빌드 캐시 있음 (같은 소스 3회) | 33.2 / 14.2 / 19.7 s | 첫 회 33s 는 Kaniko·golang 이미지 받기 포함 |
| 빌드 캐시 없음 (4회) | 40.6 / 34.3 / 42.5 / 40.3 s | 뒤 3회는 build-noise 중 |
| 콜드 스타트 runc (n=10) | p50 763 ms / p95 863 ms (min 702, max 863) | 10회 전부 cold=true, exec 노드 |
| 웜 1개, 20초 쉰 뒤 첫 요청 (n=5) | p50 4.0 ms / p95 5.3 ms | 콜드 대비 약 190배 빠름 |
| 웜 runc 빈 요청 C=2 (n=600) | p50 1.3 ms / p95 2.2 ms | 플랫폼 경로만의 비용 |
| 웜 runc `cpu 10ms` C=1 / C=4 | p50 12.1 / 82.3 ms, p95 51.5 / 96.8 ms | ↓ CPU limit 500m 때문 (아래) |
| 웜 runc `io n=200` C=1 / C=4 | p50 7.7 / 101.3 ms, p95 50.4 / 695.8 ms | ↓ 같은 이유 |
| 빌드 중 p95 (빈 요청 C=2): 없음 / build 풀 / exec 풀 | 2.2 / 4.3 / 4.8 ms | p50 1.3 / 1.9 / 1.8. 풀을 나눠도 거의 같다 = 같은 호스트 CPU (8.3 읽는 법) |
| 콜드 스타트 gVisor | 【미검증】 | 9절 보충 |

숫자에서 배운 것 하나: `cpu 10ms` 를 동시 4개로 보내면 p50 이 12ms → 82ms 로 뛴다. 함수 limits 가 `cpu: 500m` 라서다. 쿠버네티스는 CPU limit 을 "100ms 마다 50ms 까지만" 으로 지킨다(CFS quota). 4개가 동시에 10ms 씩 쓰면 50ms 를 금방 다 쓰고 남은 시간은 **멈춰서 기다린다**(throttling). p95 가 50ms 근처에 몰리는 것도 같은 이유다. → 함수 limits 는 "메모리는 꼭, CPU limit 은 신중히" 가 결정 표에 들어갈 내용이다.

### 9단계: 오늘의 결정 표 (Jeong 이 채움 → Claude 가 `decisions/2026-10-24.md` 로 옮김)

| 결정 | 선택 | 대안 | 이유 | 측정값 | 심사 항목 |
|---|---|---|---|---|---|
| 노드 풀 나누기 | system(taint 없음) / build / exec(taint) | 풀 없이 한 덩어리 / 테넌트별 풀 | | 빌드 중 p95 3줄 | 클라우드 활용 (스팟·기계 종류) |
| 빌드 Job requests·limits | ___ / ___ | requests=limits (Guaranteed) | | 빌드 시간 | 클라우드 활용 (비용) |
| 함수 실행 런타임 | ___ (runc / gVisor / 테넌트별 선택) | Kata(VM), Firecracker, WASM | | 콜드 p95 차이, io p95 차이 | 독창성·완성도 (보안) |
| min-scale | ___ | 0 (콜드 허용) / 1 (웜) / 시간대별 | | 콜드 p95 vs 웜 메모리 | 완성도·데모 |
| max-scale, target | ___ / ___ | 무제한 / containerConcurrency 고정 | | | 장애 대응 (노이지 네이버) |
| RuntimeClass overhead | ___ / ___ | 안 적음 (스케줄러가 과소 계산) | | top pod 차이 | 클라우드 활용 |

---

## 9절 보충: gVisor 가 kind 에서 안 될 때

【미검증】 이 단계의 gVisor 부분은 Claude 컨테이너에서 Pod 실행까지 확인하지 못했다. 맥(Docker Desktop)에서 처음 돌려 보는 게 첫 검증이다.

Claude 컨테이너에서 확인한 것 / 안 된 것
- 됨: exec 노드에 runsc·shim·gvisor-bin 설치, containerd 에 `runsc` 등록, RuntimeClass 적용, gvisor Pod 가 RuntimeClass scheduling 으로 exec 노드에 배치.
- 안 됨: 샌드박스 시작. 원인은 그 컨테이너 환경 (CAP_SYS_RESOURCE 없음 → shim 이 `oom_score_adj` 를 못 씀, 호스트가 cgroup v1). Docker Desktop 은 cgroup v2 + 권한 있는 VM 이라 이 두 문제는 없을 것 【추정】.

맥에서 실패하면 볼 순서
1. `kubectl -n fn-runtime describe pod -l serving.knative.dev/service=hello-gvisor | tail -5` 의 `FailedCreatePodSandBox` 메시지를 스레드에 붙인다.
2. `docker exec faas-worker3 journalctl -u containerd --no-pager | grep -i runsc | tail -20`
3. 흔한 원인 【추정】: (가) Apple Silicon 에서 arch 가 aarch64 로 받아졌는지 (`docker exec faas-worker3 file /usr/local/bin/runsc`), (나) gvisor-bin/ 이 빠짐, (다) systrap 플랫폼이 VM 커널에서 막힘 → runsc 설정 파일로 `platform = "ptrace"` 시도.
4. 30분 넘게 안 되면 **범위를 줄인다**: gVisor 측정은 7단계(EC2, 진짜 리눅스 커널)로 넘기고, 오늘은 runc 로만 콜드 스타트·웜·빌드 중 p95 를 잰다. hello-gvisor 두 파일은 `runtimeClassName` 만 주석 처리. 설계 문서에는 "격리 런타임은 RuntimeClass 한 줄로 갈아 끼우는 구조, 측정은 EC2 에서" 로 쓴다.

Docker Hub 429 (다운로드 한도)
- Kaniko 가 `FROM golang` 을 받다가 429 가 나면: 맥에서 `docker pull mirror.gcr.io/library/golang:1.25-alpine && docker tag mirror.gcr.io/library/golang:1.25-alpine localhost:5001/library/golang:1.25-alpine && docker push localhost:5001/library/golang:1.25-alpine` 후 kaniko-job.yaml args 에 `--registry-mirror=kind-registry:5000` 한 줄. Kaniko 가 Docker Hub 대신 우리 레지스트리에서 먼저 찾는다. (Claude 검증도 이 방법으로 했다)

---

## 10. 이 단계가 끝난 상태 (5~7단계가 이걸 전제로 시작)

| 항목 | 값 |
|---|---|
| 클러스터 | kind `faas`, `poc/04-faas-runtime/cluster/kind-config.yaml` (3단계 + taint + 8081). 재생성 = `poc/04-faas-runtime/scripts/rebuild-cluster.sh` |
| 노드 풀 | `pool=system`(taint 없음) / `pool=build` / `pool=exec` (둘 다 `pool=<값>:NoSchedule`) |
| 레지스트리 | 맥 `localhost:5001` = 클러스터 안 `kind-registry:5000` (노드는 두 이름 다 받음) |
| Knative | Serving + Kourier v1.23.0, 도메인 `faas.local`, 입구 `localhost:8081` + Host 헤더. 기능 플래그 nodeselector·tolerations·runtimeclassname enabled |
| gVisor | exec 풀에만, RuntimeClass `gvisor` (scheduling 으로 exec 고정) |
| 빌드 | `scripts/build.sh <태그>` → `kind-registry:5000/fn/hello:<태그>`, Job 은 `fn-build` namespace, build 풀 |
| 함수 | Argo CD Application `faas-functions` → `fn-runtime` 의 hello-runc / hello-gvisor / hello-gvisor-warm |

## 핵심 결정 3개 (+대안)

| 결정 | 이 PoC 의 선택 | 대안과 버린 이유 |
|---|---|---|
| 1. 0↔N 스케일 | **Knative Serving + Kourier** | (가) KEDA HTTP add-on: Deployment 를 그대로 쓰는 장점, 하지만 Revision(버전별 트래픽 분할)·activator 가 없어 콜드 스타트 중 요청 보관을 따로 만들어야 한다. (나) 직접 만든 컨트롤러: 본선 시간 안에 못 한다. (다) Istio 입구: 기능은 많지만 system 풀 메모리를 Kourier 보다 훨씬 먹는다 【추정】 |
| 2. 클러스터 안 빌드 | **Kaniko Job (build 풀 고정, 레지스트리 캐시)** | (가) BuildKit rootless: 더 빠르고 활발히 유지되지만 seccomp·AppArmor 를 풀어 줘야 하고 설정이 길다. 본선에서 바꿀 1순위 후보. (나) Kaniko 원본은 2025-06 보관됨 → Chainguard 포크로 이미지만 바꾸면 된다. (다) 맥/CI 에서 빌드 후 push: 사용자 코드가 우리 CI 에서 돈다 = 격리 문제가 CI 로 옮겨 갈 뿐 |
| 3. 함수 격리 | **gVisor RuntimeClass (exec 풀만 설치)** | (가) runc + seccomp·Pod Security: 가볍지만 커널 공유 그대로. (나) Kata Containers / Firecracker: 진짜 VM 이라 격리가 더 강하지만 kind(컨테이너 안 노드)에선 중첩 가상화가 필요해 못 돈다. EC2 에서도 bare-metal 이 필요. (다) WASM(작년 우승팀 Blue): 시작이 ms 대지만 언어·라이브러리 제약, 사용자 코드를 WASM 으로 다시 빌드해야 한다 |

## 셀프 연습 1개

`hello-runc-warm.yaml` 을 만들어(= hello-gvisor-warm 에서 runtimeClassName 삭제) push 하고, 8.2 의 `latency.sh` 를 runc-warm / gvisor-warm 양쪽에 `cpu` 와 `io` 로 돌려 4칸 표를 만든다. 1.5절 예상(io 쪽만 크게 느려진다)이 맞았는지 한 줄. 그리고 그 차이를 보고 RuntimeClass `overhead` 값을 고친다.

## 검증 명령과 기대 출력

```bash
grep -rn ___ poc/04-faas-runtime --include=*.yaml --exclude-dir=solution
# 기대: 출력 없음 (빈칸 45개 다 채움)

kubectl describe nodes | grep -E "^Taints:" | sort | uniq -c
# 기대: control-plane 1줄, <none> 1줄 (system), pool=build:NoSchedule 1줄, pool=exec:NoSchedule 1줄

kubectl -n fn-build get pods -l app=fn-build -o custom-columns=NODE:.spec.nodeName --no-headers | sort -u
# 기대: build 노드 이름 하나만 (build-noise.sh 의 exec 시나리오를 돌린 직후 10분 안이면 exec 노드도 보인다)

kubectl -n fn-runtime get ksvc
# 기대: hello-runc, hello-gvisor, hello-gvisor-warm 모두 READY True

kubectl -n fn-runtime get pods -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,RUNTIME:.spec.runtimeClassName
# 기대 (요청 없이 1분 뒤): hello-gvisor-warm 1개만, 노드 = exec, RUNTIME = gvisor

curl -s -H "Host: hello-gvisor.fn-runtime.faas.local" localhost:8081/ ; echo
# 기대: {"cold":true,...,"kernel":"<노드 커널과 다른 값>",...}

tail -n +2 poc/04-faas-runtime/results/coldstart.csv | cut -d, -f2 | sort | uniq -c
# 기대: hello-runc 20, hello-gvisor 20, hello-gvisor-warm 10 (8단계 회수만큼)

wc -l poc/04-faas-runtime/results/build-noise.csv
# 기대: 4 (헤더 1 + baseline·build·exec 3)
```
