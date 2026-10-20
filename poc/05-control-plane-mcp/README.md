로드맵 위치: 3주차 10/25 (일) / 컨트롤 플레인 API + 운영 에이전트(MCP) / 본선 연결점: "코드 올리면 몇 초 뒤 URL 이 나오는" 플랫폼의 입구(완성도·데모 30)와, AI 가 운영을 돕되 사람이 고삐를 쥐는 장면(AI 10 + 팀 개발의 "대안 문서화" 20)

# PoC 5단계: 함수 배포 API 와 운영 에이전트용 MCP 도구

오늘 끝나면 되는 것 3개
1. `POST /api/v1/tenants/tenant-a/functions` 에 파이썬 코드를 보내면 빌드 Job → Knative Service 가 생기고 URL 이 나온다. 걸린 시간을 빌드 / 반영 / 첫 요청으로 나눈 숫자가 3회 이상 있다
2. Claude Code 에 붙인 MCP 도구 3개(`get_metrics`, `scale`, `rollback`)로 "고장 난 v2 를 찾아서, 사람 승인 받고, v1 으로 되돌리는" 장면을 한 번 끝까지 돌렸다
3. 에이전트 권한을 일부러 하나 빼 봤고, 그때 API 서버가 403 으로 막는 걸 봤다 (가드레일의 진짜 벽이 어디인지 안다)

진행 방식 (1~4단계와 같음)
- 개념(1절) → 파일 지도(2절) → 시작 상태 확인(3절) → 단계마다: 파일 주석을 위에서 아래로 읽기 → 빈칸 채우기 → 명령(한 줄씩 설명) → 확인 질문 → 출력 붙여 주기.
- 빈칸은 `___` 와 `TODO(human)` 로 표시. 공식 문서 링크는 각 파일 맨 위에 있다.
- 한 파일에 30분 넘게 막히면 `solution/` 의 같은 경로 파일을 본다. 그다음 스레드에서 왜 그런지 한 줄씩 설명받는다.
- Spring·파이썬 코드는 대부분 완성본이다. Jeong 이 쓰는 코드는 **배포 엔드포인트 하나(자바)** 와 **scale 도구 하나(파이썬)** 뿐. 나머지 빈칸은 쿠버네티스 매니페스트.

---

## 1. 개념 (0부터)

### 1.1 컨트롤 플레인과 데이터 플레인

플랫폼을 두 층으로 나눠 부른다.
- **데이터 플레인**: 실제 일을 하는 곳. 여기서는 사용자 함수 파드(Knative 가 띄움)와 그 앞의 입구(Kourier).
- **컨트롤 플레인**: "무엇을 어디에 몇 개 띄울지" 를 정하고 지시하는 곳. 사용자는 이것만 만난다.

쿠버네티스 자체도 이렇게 나뉜다(API 서버·스케줄러 = 컨트롤 플레인, 노드의 kubelet·컨테이너 = 데이터 플레인). 오늘 만드는 건 그 위에 한 겹 더 얹는 **우리 플랫폼의 컨트롤 플레인**이다.

### 1.2 왜 API 가 따로 필요한가

지금까지는 Jeong 이 `kubectl apply` 나 `git push` 로 배포했다. 플랫폼 사용자(테넌트)에게 그걸 시킬 수는 없다.
- 사용자는 YAML·이미지 빌드·레지스트리를 몰라야 한다. 작년 본선 주제 이름이 "Run Your Functions Instantly over HTTP" 였다 【사실, 01 문서】. **코드만 HTTP 로 던지면 끝**이어야 한다.
- 사용자에게 kubeconfig 를 줄 수 없다. 권한은 컨트롤 플레인 하나만 갖고, 사용자 요청은 컨트롤 플레인이 검사한 뒤 대신 실행한다.
- 그래서 컨트롤 플레인 = "검사 + 번역기". 사람 말(함수 이름, 코드) → 쿠버네티스 말(Job, ConfigMap, Knative Service).

### 1.3 배포 한 번에 일어나는 일

```
사용자            컨트롤 플레인(Spring)                 쿠버네티스
  │ POST {name, code}  │                                    │
  │──────────────────▶│ 1) 이름·크기·테넌트 검사             │
  │                    │ 2) 빌드 ID = 이름 + 코드 해시        │
  │                    │ 3) Job build-<id> 생성 ─────────────▶│ faas-build ns, 빌드 노드
  │                    │ 4) ConfigMap src-<id> (코드) ───────▶│   initContainer: 코드 복사
  │◀── 202 + Location ─│    (여기까지 1초 안)                 │   kaniko: 빌드 → 레지스트리 push
  │                    │                                    │   종료 메시지 = sha256:digest
  │ GET (반복)         │ 5) Job 이 끝날 때까지 watch ◀────────│
  │                    │ 6) 파드 상태에서 digest 읽기          │
  │                    │ 7) Knative Service apply ──────────▶│ tenant-a ns: 새 Revision, 트래픽 100%
  │◀── READY + URL ────│                                    │
```

- **202 Accepted**: "받았고 처리 중, 결과는 Location 헤더 주소에서" 라는 HTTP 표준 응답. 빌드는 수십 초라 요청을 붙잡고 있으면 사용자 쪽이 타임아웃 난다.
- **빌드 ID 에 코드 해시를 넣는 이유**: 같은 코드를 두 번 보내면 같은 Job 이름이 나와서 빌드를 다시 안 한다. 이걸 **멱등성**(같은 요청을 여러 번 해도 결과가 같음)이라 한다. 사용자가 버튼을 두 번 눌러도 안전.
- **kaniko**: Docker 데몬 없이, 평범한 컨테이너 안에서 Dockerfile 을 빌드하는 도구. 노드의 Docker 소켓을 빌려 쓰면 그 파드가 노드 root 권한을 갖게 되는데, 그걸 피하려고 쓴다.
- **Knative Service**: 4단계에서 깐 서버리스 레이어. Service 한 장을 주면 Deployment·오토스케일러·0↔N 스케일·주소를 알아서 만든다. `template` 이 바뀔 때마다 **Revision**(바뀌지 않는 스냅샷)이 하나씩 쌓이고, `traffic` 으로 어느 Revision 에 몇 % 보낼지 정한다. 롤백 = 트래픽을 예전 Revision 으로.

### 1.4 이미지 주소가 두 개인 이유 (kind 로컬 레지스트리)

같은 레지스트리를 두 이름으로 부른다.
- **push 주소 `kind-registry:5000`**: 클러스터 *안의 파드*(kaniko)가 본 이름. kind 노드들과 레지스트리 컨테이너가 같은 Docker 네트워크에 있어서 컨테이너 이름으로 찾는다.
- **pull 주소 `localhost:5001`**: *노드의 kubelet/containerd* 가 이미지를 받을 때 쓰는 이름. 노드 설정(`/etc/containerd/certs.d/localhost:5001`)이 이걸 `kind-registry:5000` 으로 돌려준다.
- 공식 설명: https://kind.sigs.k8s.io/docs/user/local-registry/ . 4단계 값과 다르면 `application.yml` 의 `faas.registry-push/pull` 만 바꾼다.

그리고 Knative Service 에는 태그(`:v1`)가 아니라 **digest(`@sha256:...`)** 를 넣는다. 태그는 나중에 다른 이미지를 가리킬 수 있지만 digest 는 내용의 지문이라 절대 안 바뀐다. 그래서 "Revision 3 = 이 이미지" 가 영원히 맞고, 롤백이 믿을 만해진다.

### 1.5 server-side apply 와 필드 주인

컨트롤 플레인과 운영 에이전트가 **같은 Knative Service 를 둘 다 고친다**. 서로 덮어쓰면 안 된다.
- **server-side apply(SSA)**: "내가 적은 필드는 이 값이어야 한다" 를 API 서버에 보내면, API 서버가 필드마다 **주인(field manager)** 을 기록한다.
- 컨트롤 플레인(`faas-control-plane`)은 이미지·라벨·max-scale·traffic 의 주인. 에이전트(`ops-agent`)는 min-scale 의 주인.
- 그래서 `ksvc.yaml` 에 min-scale 을 **일부러 안 적는다**. 적으면 다음 배포 때 컨트롤 플레인이 에이전트 값을 덮어쓴다.
- 반대로 traffic 은 컨트롤 플레인이 `force` 로 가져간다: 에이전트가 롤백으로 고정해 둔 트래픽도, 사람이 새 코드를 배포하면 새 Revision 으로 돌아온다(새 배포가 이긴다).
- 확인: `kubectl -n tenant-a get ksvc hello -o yaml --show-managed-fields`

### 1.6 MCP 와 운영 에이전트, 5층 가드레일

- **MCP(Model Context Protocol)**: LLM 앱(Claude Code 등)이 바깥 도구를 부르는 표준 규약. 서버가 "이런 도구가 있다(이름·설명·인자)" 를 알려 주면, LLM 이 상황을 보고 도구를 고르고 인자를 채워 부른다. 문서: https://modelcontextprotocol.io/docs/concepts/tools
- 오늘의 MCP 서버는 파이썬 파일 몇 개이고, Claude Code 가 자식 프로세스로 띄워 표준 입출력(stdio)으로 대화한다. 네트워크 포트를 안 연다.
- **운영 에이전트**: Claude Code + 이 MCP 서버. "hello 가 이상해, 보고 조치해" 라고 하면 지표를 읽고, 필요하면 스케일·롤백을 제안·실행한다.
- 위험: LLM 은 틀릴 수 있고, 로그·코드에 숨은 문장에 속을 수도 있다(프롬프트 주입). 그래서 **LLM 이 무엇을 하든 넘을 수 없는 선**을 여러 겹으로 친다.

| 층 | 무엇 | 어디에 | 뚫리면 |
|---|---|---|---|
| 1. 범위 고정 | 테넌트는 서버 시작 때 환경 변수로 정한다. 도구 인자에 `tenant` 가 없다 | `config.py`, `knative.py` | 2층이 막는다 |
| 2. 최소 권한 | `ops-agent` ServiceAccount 는 tenant-a 에서 읽기 + Knative Service patch 만. 삭제·생성·Secret·exec 없음 | `k8s/platform/ops-agent/rbac.yaml` | **여기가 진짜 벽.** API 서버가 403 |
| 3. 사람 승인 | rollback 은 승인 요청만 만들고, 사람이 터미널에서 `approve` 해야 실행. 승인은 "이 함수를 이 Revision 으로" 에 묶이고 1회용, 15분 만료 | `guardrails.py`, `approve.py` | 롤백만 위험 → 영향은 트래픽 전환 하나 |
| 4. 한도·드라이런 | scale 은 한 번에 ±2, min-scale 0~5. 모든 변경 도구에 `dry_run`(API 서버가 검사만 하고 저장 안 함) | `tools.py` | 2층 + ResourceQuota(3단계)가 총량을 막는다 |
| 5. 감사·되돌리기 | 모든 호출을 허용/거부/대기/실행과 함께 JSONL 한 줄. 롤백 자체도 새 배포로 되돌릴 수 있다 | `~/.ops-mcp/audit.jsonl` | 사후 추적 |

핵심 문장 (발표용): **"AI 의 판단은 틀릴 수 있다고 가정하고, AI 가 쥔 열쇠 자체를 작게 만들었다. 막는 건 프롬프트가 아니라 RBAC 다."**

---

## 2. 파일 지도

```
poc/05-control-plane-mcp/
  control-plane/                         ← Spring Boot 4.1 + fabric8 쿠버네티스 클라이언트 (Maven, Lab 01 과 같은 구조)
    src/main/java/com/example/controlplane/
      api/FunctionController.java          3단계 (Jeong: 배포 엔드포인트 하나. GET 상태 조회는 완성)
      api/DeployRequest.java ...           완성 (요청·응답 레코드, 에러 변환)
      deploy/FunctionDeployer.java         완성. 1.3 그림의 1~7을 하는 곳. 꼭 한 번 위에서 아래로 읽기
      deploy/ManifestRenderer.java         완성. 템플릿의 ${KEY} 를 채우고 자바 객체로
      deploy/BuildIds.java, audit/AuditLog.java   완성
    src/main/resources/
      templates/build-job.yaml             1단계 (Jeong, 빈칸 12개)
      templates/ksvc.yaml                  2단계 (Jeong, 빈칸 8개)
      runtime/python/{server.py,Dockerfile}  완성. 사용자 handler.py 를 HTTP 로 감싸는 런타임
      application.yml                      완성. 클러스터마다 다른 값
    src/test/.../FunctionApiTest.java      완성. 가짜 API 서버로 8개 검사 → Jeong 이 쓴 3개 파일의 채점기
  k8s/platform/                          ← Argo CD 가 관리할 플랫폼 매니페스트 (5단계, Jeong)
    control-plane/namespaces.yaml          빈칸 2
    control-plane/rbac.yaml                빈칸 8
    control-plane/tenant-a.yaml            빈칸 2
    control-plane/deployment.yaml          빈칸 4
    ops-agent/rbac.yaml                    빈칸 7  (6단계)
  k8s/argocd/platform-05.yaml            ← 5단계 (Jeong, 빈칸 5). 다 채우면 poc/01-argocd/gitops/apps/ 로 복사
  mcp-server/                            ← 파이썬 MCP 서버
    ops_mcp/tools.py                       7단계 (Jeong: scale 도구 하나. get_metrics·rollback 은 완성)
    ops_mcp/{server,guardrails,knative,config,approve}.py   완성
    tests/                                 완성. 19개 검사
  scripts/
    deploy-fn.sh                           완성. 배포 1회 + 단계별 시간 → results/deploy-times.csv
    measure-deploy.sh                      완성. N 회 + 재사용 1회 + 요약
    make-agent-kubeconfig.sh               완성. ops-agent 토큰만 든 kubeconfig
    check-solution.sh                      완성. 정답본/내 답을 임시 폴더에서 전부 검사
  samples/hello-v1.py, hello-v2-broken.py  데모용 함수
  solution/                              ← 정답본. 위와 같은 경로 (막혔을 때만)
```

---

## 3. 시작 상태 (앞 단계와 맞출 값)

이 단계는 1~4단계가 끝난 클러스터에서 시작한다고 가정한다. 표의 값이 다르면 **오른쪽 열의 파일만** 고친다.

| 항목 | 이 단계가 가정한 값 | 출처 | 다르면 고칠 곳 |
|---|---|---|---|
| 클러스터 | kind `faas` (컨텍스트 `kind-faas`), Argo CD + root App of Apps | 1단계 9절 【사실】 | |
| 테넌트 | namespace `tenant-a`, 라벨 `tenant: tenant-a`, Pod Security enforce baseline / warn restricted, default-deny NetworkPolicy | 3단계 tenant 차트 【사실】 | `application.yml` `faas.tenant-label` |
| Knative Serving + Kourier | 설치됨, 입구 `localhost:8081` + Host 헤더 (kourier NodePort 31080), 도메인 `<이름>.<ns>.faas.local`. config-features 의 podspec-nodeselector·tolerations·runtimeclassname enabled | 4단계 README 2절 【사실, main 040773a】 | `OPS_MCP_GATEWAY`, `GW` |
| Knative → 테넌트 트래픽 | tenant-a NetworkPolicy 가 `knative-serving`·`kourier-system` 에서 들어오는 걸 허용 (3단계 values `network.allowFromNamespaces`) | 4단계 【미확인】 | 3단계 `tenants/tenant-a.yaml` |
| 노드 풀 | 빌드 `pool=build` + taint `pool=build:NoSchedule`, 함수 실행 `pool=exec` + taint `pool=exec:NoSchedule` | 4단계 【사실】 | `templates/build-job.yaml`, `templates/ksvc.yaml` |
| 레지스트리 | push `kind-registry:5000`, pull `localhost:5001` (노드는 두 이름 다 됨, Knative 태그 해석 건너뛰기에도 둘 다 등록) | 4단계 setup.sh 【사실】 | `application.yml`, `deployment.yaml` env |
| kaniko 이미지 | `gcr.io/kaniko-project/executor:v1.23.2`. 4단계는 ns `fn-build` 에 tar.gz 컨텍스트로 쓴다. 5단계는 따로 `faas-build` ns 에서 initContainer `cp -L` 로 ConfigMap 심볼릭 링크 문제를 피한다 (같은 문제, 다른 해법) | 4단계 【사실】 | `templates/build-job.yaml` |
| gVisor | RuntimeClass `gvisor` (handler runsc, exec 풀에 고정). 5단계 기본은 꺼 둠 (선택) | 4단계 【사실】 | `templates/ksvc.yaml` 주석 |
| metrics-server | 있으면 get_metrics 에 CPU/메모리가 나온다. 없어도 동작 | Lab 04 | |

- 4단계 함수 규약은 Go 샘플뿐이라, 파이썬 `handler.py` 의 `handle(body: bytes)` 규약은 이 단계가 정했다 (`runtime/python/server.py`).
- 3단계 tenant 차트의 `deployer` ServiceAccount 는 쓰지 않는다. 에이전트용으로 더 좁은 `ops-agent` 를 따로 만든다 (이유는 `k8s/platform/ops-agent/rbac.yaml` 맨 위).

---

## 4. 단계

### 0단계: 준비

```bash
cd /Users/ijeong/softbank_study_1/Softbank_Study_1
git switch main && git pull origin main      # main 에서 오늘 뼈대 받기
java -version                                # 21 이상이어야 한다 (Lab 01 에서 씀)
python3 --version                            # 3.11 이상
kubectl config current-context               # kind-faas 여야 한다
kubectl get ns tenant-a --show-labels        # 3단계 테넌트. tenant=tenant-a 라벨이 보여야 한다
kubectl get crd services.serving.knative.dev # 4단계 Knative. 없으면 4단계부터
kubectl get nodes -L pool                    # POOL 열에 build 가 붙은 노드가 있나
```

붙여 줄 것: 위 출력 전부. 다른 값이 보이면 3절 표대로 맞춘다.

### 1단계: 빌드 Job 템플릿 (`templates/build-job.yaml`, 빈칸 12개)

1. `control-plane/src/main/java/com/example/controlplane/deploy/FunctionDeployer.java` 를 위에서 아래로 읽는다. 특히 `startDeploy` 의 `vars`(템플릿에 넣어 주는 값)와 `readDigest`(어떤 컨테이너 이름에서 digest 를 찾는지).
2. `control-plane/src/main/resources/templates/build-job.yaml` 주석을 읽고 빈칸을 채운다.
   - Job: https://kubernetes.io/docs/concepts/workloads/controllers/job/
   - taint/toleration: https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/
   - kaniko 옵션: https://github.com/GoogleContainerTools/kaniko#additional-flags
3. 결정 1(backoffLimit)은 고른 이유를 5절 표에 한 줄.

확인 질문: kaniko 가 이미지를 다 만들면 digest 를 어디에 쓰고, 컨트롤 플레인은 그걸 어디서 읽나?

### 2단계: Knative Service 템플릿 (`templates/ksvc.yaml`, 빈칸 8개)

1. 주석을 읽고 채운다. 문서: https://knative.dev/docs/serving/reference/serving-api/#serving.knative.dev/v1.Service
2. 결정 2(max-scale): 3단계 quota 가 `limits.memory: 2Gi`·`limits.cpu: 2`, 이 템플릿의 컨테이너 limits 가 128Mi(cpu 는 안 적어도 LimitRange 가 200m 을 붙인다). Knative 가 붙이는 queue-proxy 사이드카도 같은 LimitRange 기본값을 받는다. 메모리와 CPU 둘 다 계산해서 어느 쪽이 먼저 닿는지 5절 표에.
3. 왜 min-scale 을 안 적는지(1.5) 한 줄로 말할 수 있으면 통과.

확인 질문: 이 템플릿으로 두 번 배포하면 Revision 은 몇 개가 되고, 트래픽은 어디로 가나?

### 3단계: 배포 엔드포인트 (`api/FunctionController.java`)

1. 같은 파일 아래의 완성된 `status()` 를 먼저 읽는다. 어노테이션 모양이 그대로 힌트다.
2. `TODO(human)` 주석의 1)~4)를 따라 `deploy` 메서드를 쓴다.
3. 테스트로 채점:

```bash
cd poc/05-control-plane-mcp/control-plane
./mvnw test
#   ./mvnw = 이 폴더에 들어 있는 Maven 실행기. Maven 을 따로 안 깔아도 맞는 버전을 받아서 돈다
#   test  = 컴파일 → src/test 의 FunctionApiTest 실행. 진짜 클러스터 대신 메모리 속 가짜 API 서버를 띄운다
#   첫 실행은 의존성 다운로드로 1~3분
```

기대: `Tests run: 8, Failures: 0, Errors: 0`. 실패하면 맨 위 실패 이름이 무엇을 보는지 알려 준다 (예: `빌드가_끝나면_KnativeService가_생기고_READY까지_간다` 가 실패 = ksvc.yaml 쪽).

확인 질문: 테넌트 검사(2)를 3)보다 뒤에 두면 무슨 일이 생기나? (힌트: `kube-system` 으로 POST)

붙여 줄 것: `./mvnw test` 마지막 20줄

### 4단계: 맥에서 컨트롤 플레인을 띄워 진짜 배포

처음에는 컨트롤 플레인을 클러스터 밖(맥)에서 띄운다. 이때는 Jeong 의 `~/.kube/config`(관리자 권한)를 쓰니 RBAC 문제 없이 흐름만 본다.

```bash
# 터미널 1: 컨트롤 플레인
cd poc/05-control-plane-mcp/control-plane
kubectl create namespace faas-build --dry-run=client -o yaml | kubectl apply -f -
#   빌드 namespace. 5단계에서 Argo CD 가 관리하게 바꾸기 전 임시. --dry-run=client -o yaml | apply = "있으면 그대로, 없으면 생성"
./mvnw spring-boot:run
#   jar 를 만들지 않고 바로 실행. 8080 포트. 로그의 AUDIT 줄이 감사 로그

# 터미널 2: 필요 없음. 4단계에서 Kourier 가 localhost:8081 로 열려 있다 (안 열리면 kubectl -n kourier-system port-forward svc/kourier 8081:80)

# 터미널 3: 배포
cd poc/05-control-plane-mcp
GW=http://localhost:8081 scripts/deploy-fn.sh tenant-a hello samples/hello-v1.py
#   POST → 0.5초마다 상태 조회 → READY 가 되면 첫 요청까지 보내고 시간 출력, CSV 에 한 줄
```

기대 출력 (숫자는 다름)
```
접수: buildId=hello-xxxxxxxxxx
  0.0s  BUILDING
  ...s  DEPLOYING
  ...s  READY
빌드 ...s + 반영 ...s = 총 ...s, 첫 요청 ...ms (HTTP 200)
```

손으로도 한 번:
```bash
curl -s localhost:8080/api/v1/tenants/tenant-a/functions/hello | python3 -m json.tool   # 상태 JSON
kubectl -n faas-build get jobs,pods                     # 빌드 Job 과 파드 (Completed)
kubectl -n tenant-a get ksvc,revisions                  # Knative Service 1, Revision 1
curl -s -H "Host: hello.tenant-a.faas.local" localhost:8081 -d jeong
#   Host 는 위 상태 JSON 의 url 에서 http:// 를 뺀 값 (4단계 도메인 faas.local)
```

막히면 볼 곳: `BUILDING` 에서 안 넘어감 → `kubectl -n faas-build describe pod` (Pending 이면 빌드 노드 라벨, ImagePull 이면 kaniko 이미지). `BUILD_FAILED` → 상태 JSON 의 message 에 나온 `kubectl logs` 명령. `DEPLOYING` 에서 멈춤 → `kubectl -n tenant-a describe ksvc hello`.

확인 질문: 같은 명령을 한 번 더 치면 빌드 시간이 어떻게 되나? 왜?

붙여 줄 것: deploy-fn.sh 출력, `kubectl -n tenant-a get ksvc,revisions`

### 5단계: 컨트롤 플레인을 클러스터 안으로 (RBAC + Argo CD)

이제 관리자 권한을 떼고 ServiceAccount 권한으로 돌린다. 플랫폼 자체는 GitOps 로 관리한다 (결정 1).

1. `k8s/platform/control-plane/` 의 4개 파일을 순서대로 읽고 채운다: namespaces → rbac → tenant-a → deployment. rbac.yaml 은 `FunctionDeployer.java` 에서 `k8s.` 로 시작하는 호출을 하나씩 찾아 verb 에 대응시키면 답이 나온다.
   - RBAC: https://kubernetes.io/docs/reference/access-authn-authz/rbac/
   - Pod Security: https://kubernetes.io/docs/concepts/security/pod-security-standards/
2. `k8s/argocd/platform-05.yaml` 을 채운다. 문서: https://argo-cd.readthedocs.io/en/stable/user-guide/directory/
3. 6단계의 `ops-agent/rbac.yaml` 도 같은 폴더(platform)라 같이 동기화된다. **6단계 빈칸까지 채운 다음** push 한다 (빈칸이 남으면 sync 에러).

```bash
cd poc/05-control-plane-mcp
scripts/check-solution.sh --mine
#   내가 채운 원래 자리를 임시 폴더에 복사해서: 빈칸 남았나 → mvnw test → pytest → kubectl server dry-run
#   (pytest 는 7단계 전이라 scale 테스트가 실패한다. 4) 매니페스트만 통과하면 지금은 OK)

docker build -t faas-control-plane:0.1 control-plane
#   control-plane/Dockerfile 로 이미지. Lab 01 과 같은 멀티스테이지 (Maven 빌드 → JRE 만 남김)
kind load docker-image faas-control-plane:0.1 --name faas
#   레지스트리를 거치지 않고 kind 노드들에 이미지를 직접 복사

git add poc/05-control-plane-mcp && git commit -m "poc05: control plane manifests" && git push origin main
cp k8s/argocd/platform-05.yaml ../01-argocd/gitops/apps/
git add ../01-argocd/gitops/apps/platform-05.yaml && git commit -m "poc05: add platform-05 app" && git push origin main
#   root(App of Apps)가 apps 폴더에서 새 파일을 보고 platform-05 Application 을 만든다

kubectl -n argocd get application platform-05 -w        # Synced / Healthy 까지 (Ctrl+C)
kubectl -n faas-system get pods                         # control-plane Running 1/1
kubectl auth can-i create jobs -n faas-build --as=system:serviceaccount:faas-system:control-plane   # yes
kubectl auth can-i create jobs -n tenant-a   --as=system:serviceaccount:faas-system:control-plane   # no
kubectl auth can-i patch services.serving.knative.dev -n kube-system --as=system:serviceaccount:faas-system:control-plane  # no
#   --as = 그 계정인 척 물어보기. 실제 행동은 안 한다
```

맥 터미널 1 의 `spring-boot:run` 을 끄고, 클러스터 안 컨트롤 플레인으로 바꿔 다시 배포:
```bash
kubectl -n faas-system port-forward svc/control-plane 8090:80
#   맥 8090 → 컨트롤 플레인 Service 80. 8080 은 Argo CD UI port-forward 와 겹쳐서 피한다 (run-all.sh 와 같은 값)
CP=http://localhost:8090 GW=http://localhost:8081 scripts/deploy-fn.sh tenant-a hello samples/hello-v1.py
```

확인 질문: tenant-a.yaml 의 RoleBinding 을 지우면 배포의 어느 단계에서, 어떤 에러가 나나? (힌트: 빌드 Job 은 faas-build 권한이라 끝까지 돈다. 그다음 ksvc 를 만들 때 막히고, 상태 조회도 ksvc 를 먼저 읽어서 502 가 된다. 컨트롤 플레인 로그의 `deploy.apply` AUDIT 줄을 본다)

붙여 줄 것: `kubectl -n argocd get applications`, can-i 3줄 결과, 두 번째 deploy-fn.sh 출력

### 6단계: 운영 에이전트 계정 (`k8s/platform/ops-agent/rbac.yaml`, 빈칸 7개)

1. `mcp-server/ops_mcp/knative.py` 를 읽는다. 메서드 하나 = API 호출 하나. 그 목록이 곧 권한 목록이다.
2. rbac.yaml 을 채운다 (5단계 push 에 같이 들어간다).
3. 에이전트 전용 kubeconfig 를 만들고 권한을 눈으로 확인:

```bash
scripts/make-agent-kubeconfig.sh tenant-a 8h
#   kubectl create token 으로 ops-agent 의 8시간짜리 토큰을 받아 ~/.ops-mcp/kubeconfig-tenant-a 에 넣는다
kubectl --kubeconfig ~/.ops-mcp/kubeconfig-tenant-a auth can-i --list -n tenant-a
#   이 계정이 할 수 있는 일 전체 목록. 표의 줄 수를 측정값으로 남긴다
kubectl --kubeconfig ~/.ops-mcp/kubeconfig-tenant-a get pods -n tenant-b        # Forbidden 이어야 한다
kubectl --kubeconfig ~/.ops-mcp/kubeconfig-tenant-a delete ksvc hello -n tenant-a  # Forbidden 이어야 한다
kubectl --kubeconfig ~/.ops-mcp/kubeconfig-tenant-a get secrets -n tenant-a      # Forbidden 이어야 한다
```

확인 질문: 3단계의 `deployer` 계정과 비교해 `ops-agent` 가 못 하는 것 두 개와, `deployer` 가 못 하는데 `ops-agent` 는 하는 것 하나는?

붙여 줄 것: `can-i --list` 출력, Forbidden 3줄

### 7단계: MCP 서버 (`mcp-server/ops_mcp/tools.py` 의 scale)

1. `ops_mcp/server.py` → `tools.py` 의 `get_metrics` → `rollback` 순서로 읽는다. 도구 설명(description)은 그대로 LLM 에게 가는 "설명서" 라는 점을 기억.
2. `scale` 의 `TODO(human)` 을 채운다.

```bash
cd poc/05-control-plane-mcp/mcp-server
python3 -m venv .venv
#   이 폴더 전용 파이썬 환경(.venv). 맥 전체에 패키지를 깔지 않는다
.venv/bin/pip install -e '.[test]'
#   pyproject.toml 의 의존성(mcp, kubernetes, httpx, pytest) 설치. -e = 코드를 고치면 바로 반영
.venv/bin/pytest -q
#   tests/ 19개. 가짜 Knative(tests/fakes.py)로 돌아서 클러스터가 없어도 된다
```

기대: `19 passed`

3. Claude Code 에 등록 (레포 루트에서):

```bash
claude mcp add faas-ops \
  -e OPS_MCP_TENANT=tenant-a \
  -e OPS_MCP_KUBECONFIG=$HOME/.ops-mcp/kubeconfig-tenant-a \
  -e OPS_MCP_GATEWAY=http://localhost:8081 \
  -- $PWD/poc/05-control-plane-mcp/mcp-server/.venv/bin/python -m ops_mcp.server
#   faas-ops 라는 이름으로, 이 명령을 stdio MCP 서버로 등록. -e 는 서버에 줄 환경 변수
#   문서: https://docs.claude.com/en/docs/claude-code/mcp
claude mcp list        # faas-ops 가 보이고 연결됨(✓)이면 OK
```

4. 에이전트가 승인 CLI 를 스스로 치는 걸 막는 설정을 레포의 `.claude/settings.json` 에 넣는다 (Jeong 맥에서만, 커밋은 선택):

```json
{ "permissions": { "deny": ["Bash(*ops_mcp.approve*)"] } }
```
【사실】 `Bash(*ops_mcp.approve*)` 형식은 공식 문서(https://code.claude.com/docs/en/permissions)의 패턴 규칙에 맞다: `*` 는 어디든, deny 가 allow 보다 먼저 적용, 복합 명령은 각 부분에 적용된다. 단 보안 경계는 아니다. 넣은 뒤 Claude 에게 "approve 명령을 실행해 봐" 를 시켜서 거부되는지 확인한다. 이게 안 돼도 `approve.py` 는 터미널(TTY)이 아니면 거부한다.

확인 질문: 왜 `scale` 은 승인 없이, `rollback` 은 승인이 필요하게 나눴나? 반대로 했다면 무엇이 불편/위험한가?

붙여 줄 것: `pytest -q` 결과, `claude mcp list`

### 8단계: 데모 시나리오 (2분 데모의 AI 파트)

```bash
GW=http://localhost:8081 scripts/deploy-fn.sh tenant-a hello samples/hello-v1.py          # v1 (정상)
GW=http://localhost:8081 scripts/deploy-fn.sh tenant-a hello samples/hello-v2-broken.py   # v2 (요청마다 500). READY 까지는 간다!
```

- v2 는 import 는 되니 Revision 이 Ready → 쿠버네티스 눈에는 정상이다. 2단계 Rollouts 는 Prometheus 에러율로 이걸 잡았고, 여기서는 에이전트가 `get_metrics` 의 probe 로 잡는다.
- Claude Code 에서: `tenant-a 의 hello 가 이상하다는 제보가 있어. 확인하고 필요하면 조치해. 위험한 건 나한테 승인 받아.`
- 기대 흐름: `get_metrics` → probe error_rate 1.0 → `rollback(dry_run)` → `rollback` → approval_id 받음 → Claude 가 Jeong 에게 승인 요청
- Jeong 의 **다른 터미널**에서:

```bash
cd poc/05-control-plane-mcp/mcp-server
.venv/bin/python -m ops_mcp.approve            # 대기 목록
.venv/bin/python -m ops_mcp.approve <id>       # 내용 확인 후 yes
```

- Claude 에게 "승인했어" → `rollback(approval_id)` → `get_metrics` 로 error_rate 0 확인.
- 기록: v2 배포 완료 시각, 에이전트 첫 도구 호출, 승인 요청, 승인, 롤백 완료, 복구 확인 시각 → 5절 표의 "탐지 / 승인 대기 / 실행" 초.
- 감사 로그: `tail -n 20 ~/.ops-mcp/audit.jsonl` 에 get_metrics → rollback(pending_approval) → rollback(executed) 순서가 보여야 한다.

붙여 줄 것: Claude 와의 대화 요약(도구 호출 순서), audit.jsonl 마지막 10줄, `kubectl -n tenant-a get ksvc hello -o jsonpath='{.spec.traffic}'`

### 9단계: 깨뜨렸다 고치기 1개 — "진짜 벽은 RBAC"

1. `k8s/platform/ops-agent/rbac.yaml` 에서 services 의 verbs 에서 `"patch"` 를 지우고 push (Argo CD 가 Role 을 바꿀 때까지 기다림: `kubectl -n tenant-a get role ops-agent -o yaml`).
2. Claude 에게 `hello 를 미리 데워 줘 (min-scale +1)` → `scale` 이 부른 patch 가 API 서버에서 403.
3. 관찰: 파이썬 쪽 가드레일(±2 한도)은 통과했는데 RBAC 에서 막혔다. 도구 응답은 `{"forbidden": ...}`, 감사 로그 마지막 줄은 `"decision": "error"` 에 403. Claude 가 이걸 보고 "권한 밖이라 사람에게 넘긴다" 고 말하는지 본다.
4. `"patch"` 를 되돌리고 push → 다시 `scale` 성공 확인.

확인 질문: 반대로 파이썬 가드레일을 지우고(±2 → ±100) RBAC 만 남기면 무엇이 막히고 무엇이 안 막히나?

### 10단계: 측정

```bash
cd poc/05-control-plane-mcp
GW=http://localhost:8081 scripts/measure-deploy.sh 3
#   코드를 조금씩 바꿔 3번 새 빌드 + 같은 코드 1번(재사용) → results/deploy-times.csv 에 4줄, 끝에 p50/max 요약
```

- 첫 요청 시간(first_request_ms)은 READY 직후라 대부분 웜이다. 콜드 스타트는 4단계 측정이 기준.
- 가능하면 클러스터 안 컨트롤 플레인 기준으로 잰다 (맥 bootRun 과 차이가 있으면 그것도 한 줄).

---

## 5. 오늘의 결정 표 (Jeong 이 채움 → Claude 가 `decisions/2026-10-25.md` 로 옮김)

| 결정 | 선택 | 대안 | 이유 | 측정값 | 심사 항목 |
|---|---|---|---|---|---|
| 빌드 재시도 (backoffLimit) | ___ | 0 / 1~2 | | 실패 알림까지 ___s | 완성도·데모 |
| 함수 max-scale | 5 (실제론 4에서 멈춤) | 3 / 5 / 10 | 메모리: 2Gi ÷ (128Mi + queue-proxy 128Mi) = 8. CPU: limits.cpu 2 − hello-fn 2개(400m) = 1.6 ÷ 파드 400m(함수 200m 기본 limit + queue-proxy 200m) = 4 → CPU 가 먼저 닿는다 | | 클라우드 활용 |
| 배포 경로 | API 직접 (기본값, 아래 결정 1) | GitOps 커밋 | | 새 빌드 p50 ___s / 재사용 ___s | 완성도·데모, 팀 개발 |
| 에이전트 권한 | ops-agent Role ___줄 (can-i --list) | deployer 재사용 / 관리자 | | Forbidden 3/3 | AI, 클라우드 활용 |
| 롤백 승인 | 터미널 승인 (TTY) | Slack 버튼 / GitHub PR 리뷰 | | 탐지 ___s / 승인 대기 ___s / 실행 ___s | AI |

---

## 6. 이 단계가 끝난 상태 (6단계 장애 주입이 이걸 전제로 시작)

| 항목 | 값 |
|---|---|
| 컨트롤 플레인 | `faas-system/control-plane` (Deployment 1, Service 80→8080), SA `control-plane`. Argo CD Application `platform-05` 가 `poc/05-control-plane-mcp/k8s/platform` 을 관리 |
| API | `POST /api/v1/tenants/{t}/functions` {name, code} → 202, `GET .../functions/{name}` → phase / url / image |
| 빌드 | `faas-build` ns (PSA baseline), Job `build-<name>-<hash>`, 1시간 뒤 자동 삭제 |
| 함수 | `tenant-a/hello` Knative Service, Revision 여러 개, 라벨 `faas.poc/function=hello` |
| 에이전트 | SA `tenant-a/ops-agent`, MCP 서버 `faas-ops` (Claude Code 에 등록), 상태 파일 `~/.ops-mcp/` (audit.jsonl, approvals/) |
| 6단계가 쓸 장면 | 컨트롤 플레인 파드를 지우면? 빌드 중에 지우면? (아래 "알려진 한계" 1번) |

알려진 한계 (발표 Q&A 대비)
1. 빌드를 기다리는 백그라운드 작업이 컨트롤 플레인 메모리에만 있다. 빌드 중에 컨트롤 플레인 파드가 죽으면 그 빌드는 Job 은 끝나도 Knative Service 가 안 생긴다. 고치는 방법: 시작할 때 "끝났는데 반영 안 된 Job" 을 찾아 이어 하기, 또는 이 로직을 **오퍼레이터(컨트롤러)** 로 바꿔 쿠버네티스 reconcile 루프에 맡기기. 6단계에서 일부러 재현해 보면 좋은 장애다.
2. 컨트롤 플레인 API 에 인증이 없다. 본선이면 테넌트별 API 키(헤더) → 테넌트 이름과 대조, 또는 앞단 게이트웨이에서 OIDC.
3. 함수 이력이 Git 이 아니라 Knative Revision 과 감사 로그에만 있다. 클러스터를 통째로 다시 만들면 함수는 다시 배포해야 한다 (결정 1의 대가).
4. 감사 로그가 로컬 파일/표준 출력이다. 운영이면 Loki 같은 곳으로 보내고 변경 불가 보관.

---

## 핵심 결정 3개 (+대안)

| 결정 | 이 PoC 의 선택 | 대안과 버린 이유 |
|---|---|---|
| 1. 함수 배포 경로 | **컨트롤 플레인이 쿠버네티스 API 로 직접** (빌드 Job 생성 + Knative Service server-side apply). 플랫폼 자체(컨트롤 플레인·RBAC)는 Argo CD GitOps | (가) **함수도 GitOps**: API 가 매니페스트를 Git 에 커밋 → Argo CD 반영. 이력·롤백이 git 으로 공짜지만, ① 배포마다 커밋 → push → Argo 감지(1단계 폴링 설정 또는 refresh) → sync 가 더해져 "Instantly" 와 멀어지고 【추정, 셀프 연습으로 측정】 ② 컨트롤 플레인에 Git 쓰기 토큰이 들어가고 ③ 사용자 함수(런타임 데이터)가 플랫폼 설정 레포를 커밋으로 채우고 ④ selfHeal 이 에이전트의 scale 을 드리프트로 보고 되돌린다. (나) 컨트롤 플레인이 kubectl 을 셸로 호출: 에러 처리·테스트가 어렵다 |
| 2. 빌드 위치와 이미지 고정 | **클러스터 안 kaniko Job**, 테넌트가 아닌 `faas-build` ns + 빌드 노드 풀, 결과는 **digest** 로 고정 (`--digest-file=/dev/termination-log`) | (가) 노드 Docker 소켓으로 빌드: 그 파드가 사실상 노드 root. (나) GitHub Actions 같은 외부 CI: 코드가 레포에 있어야 하고 왕복이 길다. (다) BuildKit rootless: kaniko 보다 빠르다는 평이 많지만 seccomp/AppArmor 설정이 더 필요. 참고로 kaniko 원 레포는 2025-06-03 에 보관(archived, 읽기 전용) 처리됐다 【사실: https://github.com/GoogleContainerTools/kaniko 】. 본선 전에 대체 이미지(포크) 여부를 확인. (라) 태그로 배포: 같은 태그가 다른 이미지를 가리키면 롤백이 거짓말이 된다 |
| 3. 에이전트 구조 | **별도 파이썬 MCP 서버 + 테넌트 하나에 묶인 `ops-agent` SA + 도구 3개 + 5층 가드레일** | (가) Spring 컨트롤 플레인 안에 MCP 내장(Spring AI): 서버는 하나로 줄지만, 에이전트가 컨트롤 플레인의 넓은 권한(모든 테넌트에 배포)을 같이 쥔다. (나) 에이전트에게 kubectl + 관리자 kubeconfig: 도구 설계가 필요 없지만 프롬프트 한 줄에 클러스터 전체가 걸린다. (다) 도구를 잘게 10개 이상: LLM 이 고르기 어려워지고 검사할 표면이 커진다. 승인 방식 대안: Slack 버튼 / GitHub PR 리뷰(가장 "회사스럽다", 본선이면 이쪽) — 이번엔 외부 연동 없이 끝내려고 터미널 승인 |

## 셀프 연습 1개

**결정 1의 대안을 숫자로 재 보기.** 같은 hello-v1 을 GitOps 경로로 배포하는 시간을 잰다: `ksvc.yaml` 을 직접 채운 YAML(이미지는 4단계 결과 digest)을 `poc/05-control-plane-mcp/gitops-trial/hello.yaml` 로 커밋 → 그 폴더를 보는 Application 하나 추가 → `git push` 시각부터 `kubectl -n tenant-a get ksvc hello` 가 Ready 가 될 때까지 3회 (폴링 그대로 / `argocd.argoproj.io/refresh=normal` 주석으로 강제 새로고침). API 직접 경로의 "반영(apply_s)" 과 나란히 5절 표에 놓고, "그래도 GitOps 가 나은 경우" 를 한 문장 쓴다. (힌트: 1단계 `scripts/measure-sync.sh` 를 그대로 쓸 수 있다)

## 검증 명령과 기대 출력

```bash
cd poc/05-control-plane-mcp
scripts/check-solution.sh --mine
# 기대: 1) 없음  2) 통과  3) 19 passed  4) 통과 (server dry-run)

# 아래 8080 은 4단계(맥에서 mvn spring-boot:run) 기준. 5단계 port-forward 로 돌렸으면 8090
curl -s localhost:8080/api/v1/tenants/tenant-a/functions/hello | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["phase"], d["image"].split("@")[1][:19])'
# 기대: READY sha256:xxxxxxxxxxxx   (태그가 아니라 digest)

curl -s -o /dev/null -w '%{http_code}\n' -X POST localhost:8080/api/v1/tenants/kube-system/functions \
  -H 'Content-Type: application/json' -d '{"name":"x","code":"def handle(b): return 1"}'
# 기대: 404 (테넌트 아님)

kubectl --kubeconfig ~/.ops-mcp/kubeconfig-tenant-a auth can-i delete services.serving.knative.dev -n tenant-a
# 기대: no

grep -c '"decision": "executed"' ~/.ops-mcp/audit.jsonl
# 기대: 1 이상 (8단계 롤백)

wc -l results/deploy-times.csv
# 기대: 5 이상 (헤더 1 + 새 빌드 3 + 재사용 1)
```

---

## 검증 기록 (Claude, 10/20 클라우드 컨테이너)

| 검사 | 결과 |
|---|---|
| 컨트롤 플레인 정답본 `./mvnw test` (가짜 API 서버로 Job·ConfigMap·Knative Service 생성, digest 읽기, 404/400/413, 멱등) | 8/8 통과 【사실】 |
| 뼈대 상태 `./mvnw test` | 컴파일 되고 6개 실패 (배포 엔드포인트 없음) → 채우면 통과하는 구조 【사실】 |
| MCP 서버 정답본 `pytest` (scale 한도, 승인 흐름 1회용·대상 고정, dry_run, MCP 프로토콜로 도구 3개·tenant 인자 없음, RBAC 403 → forbidden + 감사 로그) | 19/19 통과 【사실】 |
| MCP 서버를 stdio 로 실제 띄워 도구 목록·거부 응답·감사 로그 확인 | 통과 【사실】 |
| 함수 런타임 server.py (정상 200 JSON, 예외 500) | 로컬 python 으로 통과. Docker 이미지 빌드는 Docker Hub 요청 제한으로 못 함 【사실】 |
| 매니페스트 스키마 (kubeconform: 쿠버네티스 기본 + Knative Service·Argo CD Application CRD 스키마) | 정답본 전부 통과 【사실】 |
| 측정 스크립트 (가짜 컨트롤 플레인 상대로 measure-deploy.sh 2회) | CSV·요약 정상 【사실】 |
| kind 클러스터에서 끝까지 (kaniko 빌드 → Knative Ready → MCP 로 롤백) | **【미검증】** 이 컨테이너 안에서는 kind·k3s 노드가 파드를 못 띄운다 (중첩 컨테이너 제한). Jeong 의 맥에서 4~8단계가 첫 실행 |
