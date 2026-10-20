로드맵 위치: 3주차 10/23 (금) / 테넌트 격리 (Namespace + Quota + LimitRange + NetworkPolicy·Cilium·Hubble + RBAC + AppProject) / 본선 연결점: "여러 사람의 함수를 한 클러스터에서 안전하게 돌린다" 는 FaaS 플랫폼의 핵심 주장. 설계 문서의 보안·비용 절을 실측 숫자(차단 결과표, 옆집 소음 p95, 테넌트 추가 N초)로 채우고, 04 단계 노드 풀·gVisor 가 이 울타리 위에 한 겹 더 얹힌다

# PoC 3단계: 테넌트 격리

오늘 끝나면 되는 것 3개
1. `tenants/` 에 파일 하나 넣고 push 하면 그 테넌트의 울타리 전체(방·한도·차단·권한)가 생긴다 (ApplicationSet)
2. "A 가 B 를 못 부르고, CPU 를 다 못 먹고, B 로그를 못 본다" 가 결과표(PASS/FAIL)로 남아 있다 (`scripts/test-isolation.sh`)
3. 설계 문서에 쓸 숫자 두 개: 옆 테넌트가 CPU 를 폭주시킬 때 내 함수 p95, 새 테넌트 추가에 걸리는 초 (`scripts/measure.sh`)

진행 방식 (01 단계와 같음)
- 개념(1절) → 파일 지도(2절) → 단계마다: 파일 주석을 위에서 아래로 읽기 → 빈칸 채우기 → 명령(한 줄씩 설명) → 확인 질문 → 출력 붙여 주기.
- 빈칸은 밑줄 세 개(`___`)와 `TODO(human)`. 공식 문서 링크는 각 파일 맨 위.
- 한 파일에 30분 넘게 막히면 `solution/` 의 같은 경로 파일을 본다.
- 시간 예산 (12시간 중): 개념 1h / 클러스터 재생성 1h / 차트 작성 3h / Argo CD 연결 1.5h / 실험 2h / 측정 1.5h / 깨뜨렸다 고치기·셀프 연습 2h

---

## 1. 개념 (0부터)

### 1.1 멀티테넌트란

- **테넌트(tenant)** = 플랫폼을 빌려 쓰는 손님 한 팀. 우리 FaaS 로 치면 "함수를 올리는 회사 하나".
- **멀티테넌트** = 여러 손님이 클러스터 하나를 같이 쓴다. 클러스터를 손님마다 따로 주면(싱글테넌트) 안전하지만, 클러스터 하나당 컨트롤 플레인·노드 최소 비용이 들어서 손님이 100이면 100배다.
- 같이 쓰면 싸지만 세 가지가 무섭다.
  - **엿보기·공격**: A 의 함수가 B 의 함수를 네트워크로 부르거나, B 의 로그(비밀번호가 찍혀 있을 수도)를 읽는다.
  - **옆집 소음 (noisy neighbor)**: A 의 함수가 무한 루프를 돌아 CPU 를 다 먹으면 같은 노드에 있는 B 의 함수가 느려진다.
  - **탈출**: A 의 컨테이너가 노드 자체를 장악해서 모든 테넌트를 본다. (오늘은 문 하나만 잠그고, 04 단계 gVisor 에서 제대로 막는다)
- 그래서 테넌트마다 **울타리를 여러 겹** 친다. 한 겹이 뚫려도 다음 겹이 막게.

### 1.2 오늘 치는 울타리 6겹

| 겹 | 쿠버네티스 오브젝트 | 막는 것 | 누가 강제하나 |
|---|---|---|---|
| 1. 방 | **Namespace** | 이름 충돌, "어디까지가 내 것" 의 경계. 나머지 5겹이 전부 namespace 단위로 걸린다 | API 서버 |
| 2. 합계 한도 | **ResourceQuota** | 테넌트 전체가 CPU·메모리·파드 수를 정해진 양 이상 못 쓴다 | API 서버 (파드 만들 때 거절) |
| 3. 개당 기본값·최대값 | **LimitRange** | resources 를 안 적은 컨테이너에 기본 limits 를 자동으로 붙이고, 너무 큰 요청은 거절 | API 서버 |
| 4. 네트워크 차단 | **NetworkPolicy** | 다른 테넌트·인터넷과의 통신 | **CNI (오늘은 Cilium)** |
| 5. 권한 | **Role / RoleBinding / ServiceAccount** | 다른 테넌트의 파드·로그 조회, 울타리 자체를 고치는 것 | API 서버 (RBAC) |
| 6. 배포 경로 | **Argo CD AppProject** | 테넌트가 Argo CD 로 남의 namespace 에 배포하거나 울타리를 덮어쓰는 것 | Argo CD |

덤: Namespace 라벨 하나로 **Pod Security Admission** 을 켠다. privileged 컨테이너·hostPath(노드 디스크 직접 마운트)·hostNetwork 같은 "노드로 나가는 문" 을 잠그는 것 (1.1 의 탈출 대비 첫 번째 자물쇠).

### 1.3 requests 와 limits (2·3겹을 이해하는 열쇠)

- **requests** = "최소 이만큼은 보장해 줘". 스케줄러가 노드에 자리가 있나 계산할 때 쓰는 숫자 (Lab 05 에서 봤다).
- **limits** = "이 이상은 못 쓴다". CPU 는 넘으려 하면 **스로틀링**(잠깐씩 멈춤)되고, 메모리는 넘으면 **OOMKilled**(Lab 03 에서 봤다).
- CPU 단위: `1` = 1코어, `200m` = 0.2코어 (m = 밀리코어, 1/1000).
- ResourceQuota 는 namespace 안 모든 파드의 requests·limits **합계**를 센다. 그래서 Quota 에 `limits.cpu` 를 적는 순간, limits 를 안 적은 파드는 "셀 수가 없어서" 거절된다. → LimitRange 로 기본 limits 를 붙여 주는 게 짝으로 필요하다. 01 단계 hello-fn 은 CPU limits 를 안 적었으니 오늘 이 짝 덕분에 들어온다.

### 1.4 NetworkPolicy 는 "규칙", 막는 건 CNI

- **CNI** = 파드에 IP 를 주고 파드끼리 패킷을 실어 나르는 플러그인. 클러스터를 만들 때 하나 고른다.
- NetworkPolicy 오브젝트는 쿠버네티스 API 에 저장되는 **규칙 문서**일 뿐이다. 실제로 패킷을 버리는 건 CNI 다. CNI 가 NetworkPolicy 를 모르면 규칙을 써도 아무 일이 안 일어난다 (에러도 안 난다. 그래서 위험하다).
- 규칙 읽는 법
  - 파드가 NetworkPolicy 한 장에라도 **선택되면**(podSelector 에 걸리면), 그 방향(Ingress 들어오기 / Egress 나가기)은 **허용 목록에 있는 것만** 통과한다.
  - 여러 장이 걸리면 허용 목록의 **합집합**. "막는 규칙" 은 없다. 그래서 "전부 막는 한 장 + 여는 몇 장" 으로 쓴다.
  - 패킷을 "거절" 하지 않고 "버린다". 그래서 막히면 에러가 아니라 **타임아웃**으로 보인다.

### 1.5 왜 Cilium 인가 (kindnet 이 아니라)

- 【사실】 kind 기본 CNI 인 kindnet 도 지금은 kube-network-policies 로 기본 NetworkPolicy 를 구현한다 (https://kindnet.sigs.k8s.io/docs/user/network-policies/). 01 단계 kind 설정 주석의 "kindnet 은 NetworkPolicy 를 강제하지 않는다" 는 최신 kind 기준으로는 틀린 말이다. 그래도 Cilium 으로 바꾸는 이유는 세 가지다.
  1. **Hubble**: "무엇이 어디로 가다 왜 버려졌나" 를 흐름 단위로 보여 준다. 데모에서 차단을 "타임아웃" 이 아니라 "DROPPED, policy denied" 라는 증거로 보여 줄 수 있다.
  2. **L7 정책** (CiliumNetworkPolicy): "B 의 GET / 만 허용, POST 는 403" 처럼 HTTP 단위로 자른다 (셀프 연습).
  3. **eBPF**: 리눅스 커널 안에 작은 프로그램을 꽂아 패킷을 처리한다. iptables 규칙을 수천 줄 쌓는 방식보다 규칙이 많아져도 덜 느려진다 【추정: Cilium 문서의 주장, 이 PoC 에선 안 잰다】. 본선에서 "왜 이 CNI" 질문에 답할 거리.
- 대가: CNI 는 클러스터를 만들 때만 고를 수 있어서 **클러스터를 지우고 다시 만든다**. Argo CD 도 다시 깔아야 한다. 대신 "Argo CD 만 다시 깔면 나머지는 Git 에서 돌아온다" 를 시간 재는 셋업 드릴이 덤으로 생긴다 (3절).

### 1.6 Hubble

- Cilium 에이전트(노드마다 하나)가 자기 노드를 지나는 흐름을 기록한다.
- **hubble-relay** 가 모든 노드의 기록을 모아 주고, **hubble-ui** 가 그림으로 보여 준다.
- 한 줄 모양: `tenant-a/iso-client → tenant-b/iso-echo-xxx:5678 ... Policy denied DROPPED (TCP Flags: SYN)`

### 1.7 RBAC 와 impersonation

- **Role** = "이 namespace 에서 이 리소스에 이 동작(verbs)" 목록. **RoleBinding** = Role 을 사람·그룹·ServiceAccount 에 붙이는 것.
- 로그는 `pods` 가 아니라 하위 리소스 `pods/log` 에 대한 `get` 권한이다.
- 오늘은 진짜 사용자 계정을 만들지 않는다. 관리자가 `--as=alice --as-group=tenant-a-developers` 로 **그 사람인 척** (impersonation) 해서 권한만 시험한다.

### 1.8 ApplicationSet (01 단계 App of Apps 와 차이)

- App of Apps: Application YAML 을 사람이 하나씩 써서 폴더에 넣는다.
- **ApplicationSet**: Application **틀 하나** + **목록(generator)**. 목록 항목마다 Application 을 찍어 낸다.
- 오늘 목록 = Git 의 `tenants/*.yaml` 파일들 (Git files generator). 파일 안의 `name` 같은 키가 틀의 빈칸 `{{ .name }}` 에 들어간다. 테넌트 100개여도 틀은 하나.
- 같은 파일이 tenant 차트의 **values 파일**도 된다. 파일 한 장 = 테넌트 정의 전부.

### 1.9 구조 한 장

```
                          Git (main)
   tenants/tenant-a.yaml ─┐            charts/tenant/ (Jeong)
   tenants/tenant-b.yaml ─┤                 │
                          ▼                 ▼
          ApplicationSet "tenants"  ──찍어 냄──▶  Application tenant-a (project: default)
                                                   │ helm template + values=tenant-a.yaml
                                                   ▼
       ┌──────────────── namespace tenant-a ────────────────┐    argocd ns
       │ ResourceQuota  LimitRange  NetworkPolicy×3(+1)       │    AppProject tenant-a
       │ Role/RoleBinding  ServiceAccount deployer           │      (목적지 tenant-a 만,
       │                                                      │       울타리 오브젝트 금지)
       │ hello-fn ◀── Application tenant-a-hello (project: tenant-a)
       └──────────────────────────────────────────────────────┘
                 ✕ 네트워크 ✕ 로그 ✕ 배포   ▶ namespace tenant-b (같은 구조)
```

울타리(위 상자 첫 두 줄)는 **플랫폼**이 default Project 로 관리하고, 테넌트 자신은 **자기 Project** 로 함수만 배포한다. 이 둘을 나눈 게 오늘 설계의 핵심 (6절 결정 1).

---

## 2. 파일 지도

```
poc/03-tenant-isolation/
├── README.md                      이 파일
├── cluster/kind-config.yaml       [Claude] kindnet 끄기 + 워커 3대(pool=system/build/exec). 04 단계의 기준
├── charts/tenant/                 [Jeong] 테넌트 울타리 Helm 차트
│   ├── Chart.yaml                   빈칸 2
│   ├── values.yaml                  빈칸 3 (전부 TODO(human) 결정)
│   └── templates/
│       ├── namespace.yaml           빈칸 3   1겹 + Pod Security
│       ├── resourcequota.yaml       빈칸 3   2겹
│       ├── limitrange.yaml          빈칸 5   3겹
│       ├── networkpolicy.yaml       빈칸 6   4겹
│       ├── rbac.yaml                빈칸 5   5겹 (+ secrets 결정)
│       └── appproject.yaml          빈칸 4   6겹
├── tenants/                       [Jeong] 테넌트 정의 = ApplicationSet 입력 = 차트 values
│   ├── tenant-a.yaml                빈칸 1
│   └── tenant-b.yaml                빈칸 5
├── gitops/                        [Jeong] kubectl apply 로 붙이는 Argo CD 리소스 (01 단계 폴더는 안 건드린다)
│   ├── tenants-appset.yaml          빈칸 5   테넌트 공장
│   ├── tenant-a-hello.yaml          빈칸 2   a 의 함수 (자기 Project 로)
│   └── tenant-b-hello.yaml          통째로   a 를 복사해서
├── scripts/                       [Claude] 완성본
│   ├── rebuild-cluster.sh           클러스터 재생성 + Cilium + Hubble + Argo CD 재설치 (단계별 초)
│   ├── test-isolation.sh            격리 실험 4종 → results/isolation-*.csv
│   ├── measure.sh                   neighbor(옆집 소음 p95) / onboard(테넌트 추가 초)
│   └── fixtures/                    실험용 파드 (과녁 iso-echo, 클라이언트 iso-client, CPU 폭주 iso-hog 등)
├── results/                       측정 결과 csv
└── solution/                      정답본 (charts/ tenants/ gitops/ 같은 구조)
```

빈칸 합계 44개. 다 채웠는지 검사: `grep -rn ___ poc/03-tenant-isolation --include=*.yaml --exclude-dir=solution` → 출력 없음.

---

## 3. 클러스터 다시 만들기 (Claude 몫, 명령만 이해하고 실행)

### 3.1 파일 읽기: `cluster/kind-config.yaml`

01 단계 설정과 다른 점 두 개만 보면 된다.
- `networking.disableDefaultCNI: true` → kindnet 을 안 깐다. Cilium 을 깔기 전까지 노드가 `NotReady` 인 게 정상 (파드 네트워크가 없으니).
- 워커 3대에 라벨 `pool: system / build / exec`. 오늘은 이름표만. 04 단계가 taint(출입 금지)를 건다.

### 3.2 파일 읽기: `scripts/rebuild-cluster.sh`

6단계를 차례로 하고, 줄마다 `[N s]` 를 찍는다.

| 줄 | 하는 일 |
|---|---|
| `kind delete cluster --name faas` | 01 단계 클러스터를 지운다. Argo CD 안의 상태도 같이 사라지지만 **Git 에 다 있으니** 괜찮다 |
| `kind create cluster --config ...` | 노드 4개(컨테이너 4개) 생성 |
| `cilium install --version 1.20.3` | cilium CLI 가 "kind 구나" 를 알아보고 맞는 설정으로 Cilium Helm 차트를 깐다 |
| `cilium status --wait` | Cilium 에이전트가 노드마다 다 뜰 때까지 기다린다. 이때 노드가 `Ready` 로 바뀐다 |
| `cilium hubble enable --ui` | hubble-relay 와 hubble-ui 를 켠다 |
| `helm install argocd argo/argo-cd ...` | 01 단계와 같은 차트·values 로 Argo CD 재설치 |
| `kubectl apply -f poc/01-argocd/gitops/root.yaml` | root 하나만 붙이면 hello-fn 등은 Git 에서 자동으로 돌아온다 |

### 3.3 실행

```bash
brew install cilium-cli          # cilium 이라는 명령이 생긴다 (Cilium 설치·상태 확인용 CLI)
brew install hubble              # 선택. 맥에서 직접 hubble observe 를 치고 싶으면
cd ~/softbank_study_1/Softbank_Study_1 && git pull origin main
time poc/03-tenant-isolation/scripts/rebuild-cluster.sh   # 끝 줄 "총 N초" 를 8절 측정표에
kubectl get nodes -L pool        # -L pool = pool 라벨을 열로 보여 줘
cilium status                    # Cilium: OK, Hubble Relay: OK 가 보여야 한다
kubectl -n argocd get applications   # root, hello-fn 이 Synced/Healthy 로 돌아올 때까지
```

확인 질문: Cilium 설치 전 `kubectl get nodes` 가 NotReady 였던 이유를 한 문장으로.

붙여 줄 것: `kubectl get nodes -L pool` 출력, `cilium status` 의 윗부분 10줄, 총 시간.

---

## 4. 차트 작성 (Jeong 몫, 순서대로)

각 파일: 주석을 위에서 아래로 읽기 → 빈칸 채우기 → 아래 "확인" 명령.

### 4.1 `Chart.yaml`, `values.yaml`

- `values.yaml` 의 빈칸 3개는 전부 결정(TODO(human)). 숫자를 고르고 이유를 6절 결정 표에 한 줄씩.
- 확인: `helm lint poc/03-tenant-isolation/charts/tenant -f poc/03-tenant-isolation/tenants/tenant-a.yaml` (lint = 차트 문법 검사. tenants 빈칸 전이면 에러가 나도 정상)

### 4.2 `templates/namespace.yaml` → `resourcequota.yaml` → `limitrange.yaml`

- 문서: https://kubernetes.io/docs/concepts/security/pod-security-admission/ , https://kubernetes.io/docs/concepts/policy/resource-quotas/ , https://kubernetes.io/docs/concepts/policy/limit-range/
- 함정: 템플릿 주석에 중괄호 두 겹을 쓰면 Helm 이 해석한다 (01 단계와 같음).
- 확인 (차트를 YAML 로 펼쳐서 눈으로 보기. 클러스터는 안 건드린다):

```bash
cd poc/03-tenant-isolation
helm template tenant-a charts/tenant -f tenants/tenant-a.yaml | less
# helm template = 차트 + values → 완성된 YAML 출력. Argo CD 도 속으로 이걸 한다
# -f = 이 values 파일로 기본값을 덮어써라
```

### 4.3 `templates/networkpolicy.yaml`

- 문서: https://kubernetes.io/docs/concepts/services-networking/network-policies/ , 레시피 https://github.com/ahmetb/kubernetes-network-policy-recipes
- 주의 1: `to:` 아래 `- namespaceSelector` 와 `podSelector` 를 **같은 항목**에 쓰면 AND, 각각 `- ` 를 붙이면 OR. allow-dns 는 AND 여야 한다.
- 주의 2: 4번(allow-from-namespaces)은 `network.allowFromNamespaces` 가 비어 있으면 아예 안 만들어진다. 확인: `helm template t charts/tenant -f tenants/tenant-a.yaml --set 'network.allowFromNamespaces={gateway}' | grep -A12 allow-from`

### 4.4 `templates/rbac.yaml`

- 문서: https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- `kubectl api-resources | grep -E "^pods|deployments"` 로 리소스 이름과 APIVERSION(= apiGroup/버전)을 확인할 수 있다.

### 4.5 `templates/appproject.yaml`

- 문서: https://argo-cd.readthedocs.io/en/stable/user-guide/projects/
- 이 오브젝트만 namespace 가 **argocd** 다. 테넌트 namespace 에 두면 Argo CD 가 못 본다.

### 4.6 `tenants/tenant-a.yaml`, `tenant-b.yaml`

- tenant-b 는 a 의 절반. 다 쓰면 전체 펼쳐 보기:

```bash
for t in a b; do helm template tenant-$t charts/tenant -f tenants/tenant-$t.yaml > /tmp/tenant-$t.yaml; done
grep '^kind:' /tmp/tenant-a.yaml | sort | uniq -c
# 기대 (8종 10장. tenant-a 처럼 network.allowFromNamespaces 를 쓰면 NetworkPolicy 가 1장 늘어 11장):
#   1 kind: AppProject / 1 LimitRange / 1 Namespace / 3 NetworkPolicy (+1 allow-from) / 1 ResourceQuota / 1 Role / 1 RoleBinding / 1 ServiceAccount
kubectl apply --dry-run=server -f /tmp/tenant-a.yaml
# --dry-run=server = API 서버에 보내서 검사만 받고 저장은 안 한다. 오타·잘못된 필드를 여기서 잡는다
# 첫 실행에선 namespace 가 아직 없어서 "namespaces tenant-a not found" 가 나올 수 있다. 그 줄 말고 다른 에러가 없으면 통과
```

확인 질문: Quota 에 `limits.cpu` 가 있는데 LimitRange 가 없으면 hello-fn 은 어떻게 되나?

붙여 줄 것: `grep '^kind:'` 결과, dry-run 출력.

---

## 5. Argo CD 에 연결 → 실험

### 5.1 `gitops/tenants-appset.yaml`, `tenant-a-hello.yaml`, `tenant-b-hello.yaml` 작성

- 문서: https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Git/#git-generator-files
- `files.path` 는 레포 루트 기준: `poc/03-tenant-isolation/tenants/*.yaml`
- valueFiles 의 `../../tenants/...` = 차트 폴더(`charts/tenant`)에서 두 칸 위로. 레포 안이면 차트 밖 파일도 values 로 쓸 수 있다.

### 5.2 push → 붙이기

```bash
git add poc/03-tenant-isolation && git commit -m "poc03: tenant chart + appset" && git pull --rebase origin main && git push origin main
# Argo CD 는 GitHub 의 main 을 읽으니 push 가 먼저다

kubectl apply -f poc/03-tenant-isolation/gitops/tenants-appset.yaml
# ApplicationSet 은 한 번만 손으로 붙인다. 이후 테넌트 추가·삭제는 tenants/ 파일 push 만으로
kubectl -n argocd get applicationset tenants
kubectl -n argocd get applications            # tenant-a, tenant-b 가 생겨서 Synced/Healthy 로
kubectl get ns -l tenant                      # -l tenant = tenant 라벨이 붙은 namespace 만
kubectl -n tenant-a get resourcequota,limitrange,networkpolicy,role,rolebinding,sa

kubectl apply -f poc/03-tenant-isolation/gitops/tenant-a-hello.yaml -f poc/03-tenant-isolation/gitops/tenant-b-hello.yaml
kubectl -n tenant-a get pods                  # tenant-a-hello 파드 2개
kubectl -n tenant-a get pod -l app=tenant-a-hello -o jsonpath='{.items[0].spec.containers[0].resources}{"\n"}'
# hello-fn 은 CPU limits 를 안 적었는데 LimitRange 가 붙여 준 값이 보인다
```

- Application 이 안 생기면: `kubectl -n argocd describe applicationset tenants` 의 Conditions. 흔한 원인은 files.path 오타, push 안 함.
- 정답본으로 대신 돌리려면: `kubectl apply -f poc/03-tenant-isolation/solution/gitops/tenants-appset.yaml` (내 것과 **동시에 붙이지 말 것**: 둘 다 tenant-a 라는 Application 을 만들려고 싸운다)
- Pod Security `warn: restricted` 때문에 hello-fn 동기화 때 경고 문구가 보이는 건 정상 (거절이 아니라 경고).

### 5.3 격리 실험 (`scripts/test-isolation.sh`, Claude 작성)

파일 읽기: 실험 네 묶음이고, 묶음마다 기대값과 실제값을 비교해 PASS/FAIL 을 찍는다.

| 묶음 | 하는 일 | 기대 |
|---|---|---|
| 1) net | a·b 에 과녁 `iso-echo`, a·fn-demo 에 `iso-client` 를 깔고 curl (3초 넘으면 BLOCKED) | a→a OK / a→b, fn-demo→b, fn-demo→a, a→인터넷 BLOCKED. 이어서 각 노드 Cilium 에이전트에 `hubble observe --verdict DROPPED` |
| 2) cpu | ① 2코어 컨테이너를 dry-run 으로 → LimitRange max 에 거절 ② 30개 Deployment → Quota 만큼만 생성 ③ 무한 루프 파드 → cgroup 에서 실제 사용량을 10초 재서 limits 안에 묶였나 | REJECTED / CAPPED / THROTTLED |
| 3) rbac | `kubectl auth can-i ... --as=alice --as-group=tenant-a-developers` 8가지 + 실제 `kubectl logs` 시도 | a 로그 yes, b 로그·b 파드·Quota 수정·NetworkPolicy 삭제·secrets no, 봇은 a 배포 yes·b 로그 no |
| 4) argocd | tenant-a Project 로 tenant-b 에 배포하는 Application 을 붙여 본다 | Argo CD 가 "not permitted" 로 거절 |

```bash
poc/03-tenant-isolation/scripts/test-isolation.sh          # 전부. 묶음 하나만: ... net / cpu / rbac / argocd
# 끝 줄: 합계: PASS N / FAIL 0  →  results/isolation-<시각>.csv
cilium hubble ui                                           # 브라우저에 Hubble UI. namespace 에 tenant-b 를 고르고
KEEP=1 poc/03-tenant-isolation/scripts/test-isolation.sh net   # 실험 파드를 남겨 두면 UI 에서 빨간 선(드롭)을 볼 수 있다
```

확인 질문: a→b 는 BLOCKED 인데 "연결 거부" 가 아니라 3초 타임아웃으로 나온 이유는?

붙여 줄 것: 스크립트 출력 전체 (특히 Hubble DROPPED 몇 줄).

---

## 6. 핵심 결정 3개 (+대안)

TODO(human) 표시한 칸은 Jeong 이 고른 값과 이유를 직접 쓴다. 정답본의 값은 괄호 안.

| 결정 | 이 PoC 의 선택 | 대안과 버린 이유 |
|---|---|---|
| 1. 테넌트 찍어 내기 구조 | **Helm 차트 하나 + ApplicationSet(Git files generator) + 울타리는 default Project / 테넌트 함수는 테넌트 전용 AppProject** | (가) 테넌트마다 Application 을 손으로: 10개 넘으면 복붙 실수. (나) ApplicationSet list generator: 목록이 ApplicationSet YAML 안에 있어서 테넌트 추가 = 플랫폼 YAML 수정 → 파일 하나 추가보다 충돌이 잦다. (다) Capsule·HNC·vCluster 같은 멀티테넌트 도구: 기능은 많지만 하루 안에 이해하고 설명할 수 없고, 심사에서 "쿠버네티스 기본 오브젝트로 직접 설계" 가 설명하기 쉽다. (라) 울타리와 함수를 한 Project 에: 테넌트가 자기 Quota 를 지울 수 있게 된다 |
| 2. 네트워크 | **Cilium + 표준 NetworkPolicy (default deny + 같은 namespace + DNS)**, L7 은 CiliumNetworkPolicy 로 셀프 연습만 | (가) kindnet 의 NetworkPolicy: 막히긴 하지만 Hubble 같은 관측이 없어서 데모에서 "왜 막혔나" 를 못 보여 준다. (나) Calico: 표준 NetworkPolicy·관측 다 되지만 본선 대비 L7·eBPF 이야기를 하려면 Cilium. (다) 처음부터 CiliumNetworkPolicy 만: Cilium 을 빼면 규칙이 무용지물. 표준을 기본으로 두면 EKS(VPC CNI 의 NetworkPolicy)에도 그대로 간다 |
| 3. 한도 숫자와 Pod Security | TODO(human): limitsCpu (정답본 `"2"`), LimitRange 기본 CPU (정답본 `200m`), enforce 레벨 (정답본 `baseline`) | limitsCpu 크게: 한 테넌트가 맥을 다 먹는다 / 작게: 함수 몇 개도 못 띄운다. 기본 CPU 500m 이면 tenant-b(1코어)는 hello-fn 2개로 꽉 차서 실험 파드가 거절된다. enforce=restricted: 01 단계 hello-fn 이 root 실행·securityContext 없음이라 거절된다. 확인: `kubectl label ns tenant-a pod-security.kubernetes.io/enforce=restricted --overwrite --dry-run=server` 하면 "would violate" 경고에 hello-fn 이 나온다. 함수 이미지를 정리한 뒤(04 단계 빌드 Job) restricted 로 올리는 게 다음 단계 |

이 표를 `decisions/2026-10-23.md` 로 옮기는 건 STATUS 담당 스레드에서 정리한다 (선택 / 대안 / 이유 / 측정값 / 연결 심사 항목: 클라우드 활용 30, 팀 개발·대안 문서화 20).

---

## 7. 깨뜨렸다 고치기: DNS 를 막아 보기

default deny 를 처음 거는 팀이 가장 많이 밟는 장애다. "서비스가 갑자기 다 안 된다, 그런데 IP 로는 된다".

1. `charts/tenant/templates/networkpolicy.yaml` 의 3) allow-dns 블록 전체를 주석 처리(각 줄 앞에 `# `) → commit → push.
2. Argo CD 가 반영하면 (`kubectl -n tenant-a get networkpolicy` 에서 allow-dns 가 사라지면):

```bash
KEEP=1 poc/03-tenant-isolation/scripts/test-isolation.sh net
# 기대: a -> a (같은 테넌트) 가 FAIL (BLOCKED). 같은 namespace 인데도!
kubectl -n tenant-a exec iso-client -- curl -s --max-time 3 http://iso-echo         # 이름으로: 실패
kubectl -n tenant-a exec iso-client -- curl -s --max-time 3 http://$(kubectl -n tenant-a get svc iso-echo -o jsonpath='{.spec.clusterIP}')   # IP 로: iso-echo
kubectl -n kube-system exec ds/cilium -c cilium-agent -- hubble observe --namespace tenant-a --verdict DROPPED --port 53 --last 5
# 53번 포트(DNS)로 가는 UDP 가 DROPPED. 노드가 여러 대라 다른 cilium 파드에 있을 수 있다:
#   kubectl -n kube-system get pods -l k8s-app=cilium -o wide 로 iso-client 와 같은 노드 것을 골라 exec
```

3. 원인 한 문장을 스레드에 쓴다. 그다음 주석을 풀고 push → 다시 `test-isolation.sh net` 이 전부 PASS.

확인 질문: allow-dns 의 namespaceSelector 와 podSelector 사이에 `- ` 를 하나 더 붙여 OR 로 만들면 무엇까지 열리나?

---

## 8. 측정 (Claude 스크립트, 숫자는 Jeong 이 표에)

```bash
poc/03-tenant-isolation/scripts/measure.sh neighbor
# tenant-b 의 iso-echo 를 tenant-b 안에서 200번 불러 p50/p95/max(ms):
#   baseline / hog-tenant (tenant-a 에 무한 루프 4개, 각 200m 로 묶임) / hog-free (fn-demo 에 무한 루프 4개, 제한 없음)
# 3번 반복해서 중앙값을 표에. 결과: results/neighbor-*.csv

poc/03-tenant-isolation/scripts/measure.sh onboard 3
# tenants/tenant-c.yaml 을 만들어 commit+push → 울타리가 다 생겨 Healthy 가 될 때까지 초 (온보딩)
# 파일을 지워 push → namespace 가 사라질 때까지 초 (오프보딩). 3번. main 에 실제로 push 한다
# ApplicationSet 은 기본 약 3분마다 Git 을 보는데, 스크립트가 새로고침 신호를 보내서 그 대기를 뺀다 【추정: 신호가 안 먹으면 숫자가 3분 근처로 나온다. 그러면 알려 줘】
```

| 항목 | 1회 | 2회 | 3회 | 중앙값 |
|---|---|---|---|---|
| 클러스터 재생성 + Cilium + Argo CD (rebuild-cluster.sh 총 초) | | | | |
| 격리 실험 PASS / 전체 | | | | |
| 무한 루프 파드 실제 CPU (m) / limits | | | | |
| tenant-b p95 baseline (ms) | | | | |
| tenant-b p95 hog-tenant (ms) | | | | |
| tenant-b p95 hog-free (ms) | | | | |
| 테넌트 온보딩 (s) | | | | |
| 테넌트 오프보딩 (s) | | | | |

설계 문서용 한 줄 틀: "옆 테넌트가 CPU 를 폭주시켜도 내 함수 p95 는 baseline X ms → Y ms (울타리 없을 때 Z ms). 새 테넌트는 파일 하나 push 후 N 초에 격리된 채로 준비된다."

---

## 9. 셀프 연습 1개: L7 정책

tenant-a 가 tenant-b 의 함수를 **GET 으로만** 부를 수 있게 열어 본다. 다른 메서드(POST)는 Cilium 이 HTTP 403 으로 막아야 한다.

- 쓸 것: tenant-b namespace 에 `CiliumNetworkPolicy` 한 장 (관리자 kubectl apply. 울타리 오브젝트라 테넌트 Project 로는 못 넣는 게 맞다).
  - `endpointSelector`: tenant-b 의 iso-echo 파드
  - `ingress.fromEndpoints`: `k8s:io.kubernetes.pod.namespace: tenant-a`
  - `toPorts.ports: 5678/TCP` 아래 `rules.http: [{method: GET, path: "/"}]`
- 주의: 표준 NetworkPolicy 는 tenant-a 쪽 **나가기**도 막고 있다 (tenant-a 의 default deny Egress). tenant-a 에도 tenant-b 로 나가는 허용이 한 장 필요하다.
- 문서: https://docs.cilium.io/en/stable/security/policy/layer7/
- 통과 기준:

```bash
KEEP=1 poc/03-tenant-isolation/scripts/test-isolation.sh net >/dev/null
kubectl -n tenant-a exec iso-client -- curl -s -o /dev/null -w "%{http_code}\n" http://iso-echo.tenant-b       # 200
kubectl -n tenant-a exec iso-client -- curl -s -o /dev/null -w "%{http_code}\n" -X POST http://iso-echo.tenant-b   # 403
```

- 덤 질문: 이 정책을 차트에 넣는다면 values 를 어떤 모양으로 둘까? (`network.allowFromTenants` 같은 목록)

---

## 10. 검증 명령과 기대 출력

```bash
grep -rn ___ poc/03-tenant-isolation --include=*.yaml --exclude-dir=solution
# 기대: 출력 없음 (빈칸 44개 다 채움)

kubectl get nodes -L pool
# 기대: faas-control-plane + 워커 3대 Ready, POOL 열에 system / build / exec

cilium status | grep -E "Cilium:|Hubble Relay:"
# 기대: Cilium: OK, Hubble Relay: OK

kubectl -n argocd get applications
# 기대: root, hello-fn, tenant-a, tenant-b, tenant-a-hello, tenant-b-hello 모두 Synced / Healthy

kubectl get ns -l tenant -L pod-security.kubernetes.io/enforce
# 기대: tenant-a, tenant-b, ENFORCE 열에 고른 레벨 (정답본 baseline)

poc/03-tenant-isolation/scripts/test-isolation.sh | tail -1
# 기대: 합계: PASS 17 / FAIL 0  (net 5 + cpu 3 + rbac 8 + argocd 1. FAIL 이 있으면 그 줄을 붙여 줘)

kubectl auth can-i get pods/log -n tenant-b --as=alice --as-group=tenant-a-developers
# 기대: no

ls poc/03-tenant-isolation/results/
# 기대: isolation-*.csv 1개 이상, neighbor-*.csv 3개, onboard-*.csv 1개
```

---

## 11. 검증 상태 (Claude 가 이 폴더를 만들 때 확인한 것)

- 【사실】 정답본 차트를 `helm template` 으로 펼치면 tenant-a 기준 8종 10장(allowFromNamespaces 추가 뒤엔 11장)이 나오고, `kubeconform -strict` (쿠버네티스 1.33 스키마 + Argo CD CRD 스키마) 로 차트 출력·gitops 3개·fixtures 전부 통과 (14 + 5 오브젝트, 2026-10-20).
- 【사실】 빈칸 뼈대에 정답 값을 넣고 펼친 결과가 정답본 출력과 주석 빼고 한 글자도 다르지 않다 (tenant-a, tenant-b).
- 【사실】 스크립트 3개 `bash -n` + `shellcheck -S warning` 통과.
- 【미검증】 실제 클러스터에서의 동작 전부 (Cilium 설치, Hubble 출력 모양, NetworkPolicy 차단, cgroup CPU 측정). Quota·AppProject 거절 문구, valueFiles 의 차트 밖 상대 경로(같은 저장소 안이면 허용), ApplicationSet 새로고침 주석(application-set-refresh)은 공식 문서·소스로 확인했다 (docs/guide 01·03장). Claude 의 클라우드 컨테이너는 중첩 컨테이너에 필요한 커널 권한이 없어서 kind 노드에서 파드를 띄울 수 없었다. 첫 실행에서 FAIL 이 나오면 출력 그대로 스레드에 붙여 줘. 스크립트 쪽 문제면 Claude 가 고친다.
- 【추정】 `test-isolation.sh` 의 기대 PASS 개수는 17 (net 5 + cpu 3 + rbac 8 + argocd 1). 10절의 숫자는 이걸 기준으로 본다.
