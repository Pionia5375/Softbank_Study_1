로드맵 위치: 4주차 10/27 (화) / 로컬 PoC 를 AWS EC2(시스템 온디맨드 + 실행 스팟 + 빌드) 위 k3s 로 옮기기 / 본선 연결점: 클라우드 활용 30점. 작년 본선 우승팀 구성(EC2 위 직접 k8s, 스팟 실행 노드, 빌드 노드 분리)을 우리 손으로 세우고, 생성·파괴 시간과 시간당 비용·스팟 회수 복구 시간을 숫자로 들고 간다

# PoC 7단계: EC2 + 스팟 + k3s 로 옮기기

> ⚠️ **AWS 리소스 생성·`terraform apply`·`terraform destroy` 는 Jeong 승인 후 로컬 세션에서만.** 이 문서와 코드는 클라우드 스레드에서 `terraform validate` 와 오프라인 렌더링까지만 검증했다. 당일 순서는 [RUNBOOK.md](RUNBOOK.md).

오늘 끝나면 되는 것 4개
1. `terraform apply` 한 번으로 EC2 4대(시스템 1, 실행 스팟 2, 빌드 1)가 뜨고, k3s 클러스터 하나로 묶여 노드마다 라벨·taint 가 붙어 있다
2. Argo CD 를 깔고 root 하나만 넣으면 1단계부터 만든 앱들이 **로컬 kind 와 같은 Git 폴더에서** EC2 로 따라온다
3. 함수는 실행(스팟) 노드에만, 빌드 Job 은 빌드 노드에만, Argo CD 는 시스템 노드에만 뜬 걸 `kubectl get pods -o wide` 로 보여 줄 수 있다
4. 숫자 5개: apply 시간, 노드 Ready 까지 시간, Argo 동기화 시간, 스팟 회수 → 복구 시간(+실패 요청 수), destroy 시간. 그리고 다음 날 실제 청구액

진행 방식 (1단계와 같다)
- 개념(1절) → 그림(2절) → 파일 지도(3절) → 단계마다: 파일 주석을 위에서 아래로 읽기 → 빈칸 채우기 → 명령(한 줄씩 설명) → 확인 질문 → 출력 붙여 주기.
- 빈칸은 밑줄 세 개(`___`) + `TODO(human)` 주석. 30분 넘게 막히면 `solution/` 의 같은 경로 파일을 본다 ([solution/README.md](solution/README.md)).
- **분담**: Terraform·스크립트는 Claude 가 완성본으로 써 뒀다(읽기만). Jeong 이 쓰는 건 k3s 템플릿 3개, Argo CD 덧씌우기 values, Application 4개, 배치 확인 매니페스트 2개.
- **4.1·4.2 는 AWS 없이 10/26 이전에 끝낼 수 있다.** 10/27 당일은 런북대로 apply → 측정 → destroy 만 한다.

---

## 0. 준비물 (맥, 10/26 까지)

| 도구 | 확인 명령 | 왜 |
|---|---|---|
| Terraform 1.10 이상 | `terraform version` | EC2·VPC 를 코드로 만든다 |
| AWS CLI v2 | `aws --version` | 자격 증명, SSM 접속, FIS 실행 |
| Session Manager 플러그인 | `session-manager-plugin --version` | SSH 없이 노드 접속·포트 터널. 설치: `brew install --cask session-manager-plugin` 【사실: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html】 |
| kubectl, helm, jq | `kubectl version --client`, `helm version`, `jq --version` | 1단계에서 이미 씀 (jq 는 measure.sh 용) |
| AWS 자격 증명 | `aws sts get-caller-identity` | 계정 번호가 나와야 한다. 예선 때 노출된 키는 폐기했어야 한다(10/6 정리 스레드). 새 키 또는 SSO 프로필로 |

---

## 1. 개념 (0부터)

### 1.1 지금까지와 무엇이 달라지나

1~6단계는 전부 맥 안의 kind 였다. kind 의 "노드"는 사실 맥 위 Docker 컨테이너라서, 노드가 꺼지는 일도, 돈이 드는 일도, 인터넷에서 들어오는 일도 없었다.

이번에는 노드가 **진짜 컴퓨터(EC2 가상 머신)** 다. 그래서 새로 생기는 문제가 셋이다.
- **돈**: 켜져 있는 동안 1초 단위로 과금된다. 끄는 걸 잊으면 계속 나간다.
- **사라짐**: 스팟 인스턴스는 AWS 가 2분 예고 후 회수해 간다. 노드가 진짜로 없어진다.
- **접속**: 맥에서 클러스터 API 에 닿을 길을 만들어야 하고, 그 길을 아무나 못 쓰게 막아야 한다.

### 1.2 AWS 쪽 용어 (이 단계에 나오는 것만)

| 용어 | 한 줄 뜻 |
|---|---|
| EC2 인스턴스 | AWS 가 빌려주는 가상 머신 한 대. 타입(t3.medium = 2 vCPU, 4 GiB)에 따라 시간당 값이 다르다 |
| 온디맨드 / 스팟 | 온디맨드 = 정가, 내가 끌 때까지 안 사라짐. 스팟 = AWS 의 남는 자리를 싸게(보통 60~90% 할인 【추정】) 빌림, 대신 AWS 가 필요하면 **2분 예고 후 회수** 【사실: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/spot-instance-termination-notices.html】 |
| VPC / 서브넷 | 내 전용 사설 네트워크(10.70.0.0/16) / 그걸 가용 영역(AZ, 같은 리전 안 다른 데이터센터)별로 자른 칸 |
| 인터넷 게이트웨이 | VPC 와 인터넷 사이 문. 퍼블릭 IP 가 있는 인스턴스는 이걸로 밖에 나간다 |
| 보안 그룹 | 인스턴스 앞 방화벽. "어디서, 몇 번 포트로 들어와도 되나" 목록 |
| Launch Template + Auto Scaling Group(ASG) | "이런 모양 인스턴스" 설계도 + "그걸 항상 N대 유지해" 관리자. 한 대가 죽으면 새로 띄운다 |
| user_data | 인스턴스가 **처음 부팅할 때 한 번** root 로 실행하는 스크립트. 여기서 k3s 를 설치한다 |
| IAM 역할 / 인스턴스 프로파일 | 인스턴스가 AWS API 를 부를 때 쓰는 권한. 이번엔 SSM 접속 권한 하나만 |
| SSM Session Manager | SSH 키·22번 포트 없이 AWS API 를 통해 인스턴스 셸에 들어가거나 포트를 맥으로 끌어오는 기능 |
| FIS | Fault Injection Service. "스팟 회수 경고 보내기" 같은 장애를 일부러 일으키는 AWS 서비스 |
| AWS Budgets | 이번 달 쓴 돈이 기준을 넘으면 메일. **실시간이 아니다** (하루 최대 3번 갱신 【사실: https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html】) |

### 1.3 k3s 가 뭔가 (kind 와 비교)

- **k3s** = Rancher(SUSE)가 만든 가벼운 쿠버네티스 배포판. 바이너리 하나(약 70MB)에 API 서버·스케줄러·컨트롤러·kubelet·containerd·flannel(네트워크)·CoreDNS·Traefik(인그레스)·local-path(스토리지)·metrics-server 가 다 들어 있다 【사실: https://docs.k3s.io/】.
- **server** = 컨트롤 플레인이 도는 노드. 기본 저장소는 etcd 대신 SQLite(서버 1대일 때). **agent** = 워커 노드. kubelet + containerd 만.
- agent 는 "서버 주소 + 토큰(공유 비밀번호)"만 알면 붙는다. 이 둘을 Terraform 이 user_data 로 넘겨 준다.
- kind 와 차이: kind 는 "Docker 안의 노드", k3s 는 "진짜 리눅스 위의 노드". 매니페스트·Helm·Argo CD 는 똑같이 쓴다. 다른 건 노드를 만드는 방법뿐.
- 대안: kubeadm(CKA 시험 방식, 부품을 하나하나 설치해서 단계가 많다), EKS(AWS 가 컨트롤 플레인을 대신 운영, 시간당 $0.10 추가 【사실: https://aws.amazon.com/eks/pricing/】, 생성 15분 안팎 【추정】). 결정 1 참고.

### 1.4 k3s 설정 파일과 노드 라벨·taint (복습 + 새것)

- k3s 는 시작할 때 `/etc/rancher/k3s/config.yaml` 을 읽는다. 명령줄 옵션 `--node-label pool=exec` 를 YAML 키 `node-label: ["pool=exec"]` 로 쓰는 식이다 【사실: https://docs.k3s.io/installation/configuration#configuration-file】.
- **라벨**(Lab 05 복습) = 노드에 붙이는 이름표. 파드는 `nodeSelector` 로 "이 이름표 붙은 노드에만" 을 고른다. **끌어당기는** 쪽.
- **taint** = 노드에 붙이는 "출입 금지" 표시. 그 표시를 견디는(`tolerations`) 파드만 들어온다. **밀어내는** 쪽.
- 둘은 짝이다. 빌드 노드에 taint 만 걸면 다른 파드는 못 오지만 빌드 Job 이 꼭 거기 간다는 보장은 없다. 그래서 빌드 Job 은 toleration(들어갈 자격) + nodeSelector(거기로만) 둘 다 쓴다.
- 이번 설계 (라벨 키는 3·4단계 로컬 kind 와 같은 `pool`):

| 노드 | 구매 | 라벨 | taint | 누가 뜨나 |
|---|---|---|---|---|
| 시스템 (k3s server) | 온디맨드 1 | `pool=system`, `capacity-type=on-demand` | `CriticalAddonsOnly=true:NoExecute` | k3s 기본 부품, Argo CD |
| 실행 | 스팟 2 | `pool=exec`, `capacity-type=spot` | 없음 | 함수 파드 (기본 착지점) |
| 빌드 | 온디맨드 1 | `pool=build`, `capacity-type=on-demand` | `pool=build:NoSchedule` | 빌드 Job 만 |

- `CriticalAddonsOnly` 는 k3s 가 기본 부품(CoreDNS, Traefik, metrics-server 등)에 이미 toleration 을 넣어 둔 키다. 그래서 이 taint 를 걸어도 클러스터 기본 기능은 시스템 노드에 그대로 뜨고, 일반 파드만 못 온다 【사실: k3s 문서의 전용 서버 예시 https://docs.k3s.io/datastore/ha-embedded 등에서 이 taint 를 권한다. 부품별 toleration 은 【추정】, 당일 `kubectl -n kube-system get pods -o wide` 로 확인】.

### 1.5 템플릿: Terraform 이 k3s 설정을 끼워 넣는 방법

- `templatefile("파일", {이름 = 값})` = 파일을 읽어서 `${이름}` 자리를 값으로 바꾼 글자열을 돌려주는 Terraform 함수 【사실: https://developer.hashicorp.com/terraform/language/functions/templatefile】.
- 그래서 k3s 설정 파일을 `.tftpl`(Terraform 템플릿)로 쓰고, 토큰·서버 주소·풀 이름 자리를 `${token}` 처럼 비워 둔다. Terraform 이 값을 채워서 user_data 로 넣는다.
- 조건문도 된다: `%{ if pool == "build" ~}` … `%{ endif ~}` 사이 줄은 조건이 참일 때만 남는다. `~` 는 지시문 뒤 줄바꿈을 지워 빈 줄이 안 생기게 한다.
- **함정 두 개**
  1. bash 의 `${VAR}` 도 Terraform 이 자기 자리표시자로 착각한다. 템플릿 안 셸 변수에 중괄호를 쓰려면 `$${VAR}` 로 쓴다. (이번 install 스크립트는 셸 변수 중괄호를 안 써서 해당 없음)
  2. **주석 안이라도** `%{` 나 `${` 를 쓰면 Terraform 이 읽는다. 주석에서 문법을 설명하고 싶으면 말로 쓴다.

### 1.6 스팟이 회수될 때 무슨 일이 일어나나

```
T-2분  AWS: "이 인스턴스 2분 뒤 회수" 를 인스턴스 메타데이터(IMDS)에 올림
       NTH(aws-node-termination-handler, 스팟 노드마다 1개 DaemonSet)가 그걸 읽음
       → kubectl cordon (새 파드 금지) + drain (파드를 다른 노드로 내보냄, PDB 지키면서)
       ASG: 회수 신호를 보고 교체 인스턴스를 새로 요청 (capacity_rebalance)
T-0    인스턴스 종료. OS 종료 신호 → kubelet 이 남은 파드를 60초 안에 정상 종료 (graceful node shutdown, 이중 안전장치)
T+1~3분 새 스팟 인스턴스 부팅 → user_data 로 k3s agent 설치 → 클러스터에 새 노드로 붙음 【추정, 당일 측정】
```
- NTH 가 없으면: 2분 동안 아무도 준비를 안 하고, 노드가 갑자기 꺼진다. k8s 는 노드가 응답이 없으면 기본 5분쯤 기다렸다가 파드를 옮긴다 【사실: 기본 toleration `not-ready`/`unreachable` 300초, https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/#taint-based-evictions】.
- 함정: k3s 에는 AWS 클라우드 컨트롤러가 없어서, 꺼진 노드 오브젝트가 `NotReady` 로 계속 남는다. 손으로 `kubectl delete node` 한다 (EKS 는 자동). 설계 문서 "운영 부담" 칸에 쓸 거리.
- **PDB(PodDisruptionBudget)** = "drain 할 때도 최소 N개는 살아 있어야 한다" 약속. 실행 노드가 2대이고 파드가 노드마다 1개씩 퍼져 있으면, 한 노드가 빠져도 다른 하나가 응답한다.

### 1.7 맥에서 클러스터에 닿는 길

```
맥 kubectl ──https://127.0.0.1:6443──▶ 맥 localhost:6443
                                         │ (scripts/tunnel.sh = aws ssm start-session 포트 포워딩)
                                         ▼
                            AWS SSM API (443, 인터넷)
                                         ▼
                            시스템 노드 localhost:6443 (k3s API)
```
- 6443·22 포트를 인터넷에 안 연다. 열리는 건 함수 데모용 80/443 뿐이고, 그것도 `ingress_cidrs` 에 적은 IP 만.
- k3s 가 만든 kubeconfig 의 서버 주소가 원래 `https://127.0.0.1:6443` 이라 터널과 딱 맞는다. 인증서도 127.0.0.1 용이라 고칠 게 없다.

### 1.8 돈 (자세한 표는 7절)

- 기본 구성은 시간당 약 **$0.17** (약 ₩240) 【추정】. 10시간 켜도 2달러 안쪽.
- 시간당 과금이 아닌데 놓치기 쉬운 것: EBS 디스크(인스턴스를 꺼도 남으면 과금), 퍼블릭 IPv4 주소(2024-02 부터 개당 시간당 $0.005 【사실: https://aws.amazon.com/blogs/aws/new-aws-public-ipv4-address-charge-public-ip-insights/】), NAT 게이트웨이(이번엔 안 씀, 있으면 이 실습 전체보다 비쌈).
- 안전장치 3겹: 예산 알람(늦게 옴) → 실행·빌드 풀 매일 23:00 자동 0대(ASG 예약) → **런북 마지막 destroy + `check-leftovers.sh`** (이게 본체).

---

## 2. 큰 그림

```
terraform/budget   (먼저 1번, 계속 둠)  aws_budgets_budget: 월 $5, 50%·80% 실제 / 100% 예측 → 메일

terraform/cluster  (10/27 apply → 같은 날 destroy)
 ├─ network.tf   VPC 10.70.0.0/16, 퍼블릭 서브넷 2개(AZ 2곳), IGW. NAT 없음
 ├─ security.tf  노드끼리 전부 허용, 밖→80/443 은 ingress_cidrs 만, 22·6443 안 엶
 ├─ iam.tf       노드 역할 = SSM 접속 권한만
 ├─ k3s.tf       토큰 생성 + 우분투 24.04 AMI + templatefile(../../k3s/*.tftpl) → user_data
 │                                           ▲ Jeong 이 쓰는 부분 (4.1)
 ├─ server.tf    aws_instance  시스템 노드 t3.medium 온디맨드 → k3s server
 ├─ pools.tf     module node-pool ×2
 │                 exec : ASG, 스팟, t3.medium|t3a.medium, 2대 → k3s agent (pool=exec)
 │                 build: ASG, 온디맨드, t3.medium, 1대     → k3s agent (pool=build, taint)
 │                 둘 다 매일 23:00(서울) 0대로 예약
 └─ fis.tf       FIS 실험 템플릿: Pool=exec 스팟 1대에 2분 회수 경고

부팅 후 (스크립트)
 tunnel.sh ─▶ get-kubeconfig.sh ─▶ bootstrap-argocd.sh
                                      helm install argocd (1단계 values + gitops/bootstrap/argocd-values-k3s.yaml)
                                      kubectl apply root-app.yaml (root-ec2)
                                           └─ Git: poc/07-ec2-k3s/gitops/apps/   ◀ Jeong (4.2)
                                                ├─ local-stage-apps  → poc/01-argocd/gitops/apps (hello-fn 등 앞 단계 전부)
                                                ├─ node-termination-handler (스팟 노드에만)
                                                └─ placement-check   → gitops/workloads/placement-check (fn-sample, fake-build)
```

---

## 3. 파일 지도

```
poc/07-ec2-k3s/
├── README.md                     이 문서
├── RUNBOOK.md                    10/27 당일 순서 (예산 → apply → 측정 → destroy → 잔여 확인)
├── terraform/                    ── Claude 완성본. 읽기만 ──
│   ├── budget/                   예산 알람 (먼저, 계속 둠)
│   ├── cluster/                  VPC·EC2·ASG·FIS (당일 만들고 당일 지움)
│   └── modules/node-pool/        Launch Template + ASG + 23:00 예약 (실행·빌드 풀이 같이 씀)
├── k3s/                          ── Jeong 작성 (4.1) ──
│   ├── install.sh.tftpl          user_data 본체: config.yaml 쓰기 + k3s 설치    빈칸 5
│   ├── server-config.yaml.tftpl  시스템 노드 라벨·taint                          빈칸 5
│   └── agent-config.yaml.tftpl   실행·빌드 노드 라벨·taint·종료 유예              빈칸 8
├── gitops/                       ── Jeong 작성 (4.2) ──
│   ├── bootstrap/
│   │   ├── argocd-values-k3s.yaml   1단계 values 위에 얹는 "EC2 에서 다른 점"     빈칸 3
│   │   └── root-app.yaml            root-ec2 Application                          빈칸 2
│   ├── apps/
│   │   ├── local-stage-apps.yaml    앞 단계 앱 폴더를 그대로 가리킴                빈칸 1
│   │   ├── node-termination-handler.yaml  스팟 회수 대응                          빈칸 2
│   │   └── placement-check.yaml     배치 확인 워크로드                              빈칸 1
│   └── workloads/placement-check/
│       ├── fn-sample.yaml           실행 풀 Deployment+Service+Ingress+PDB         빈칸 2
│       └── fake-build.yaml          빌드 풀 Job                                     빈칸 4
├── scripts/                      ── Claude 완성본 ──
│   ├── render-k3s.sh             AWS 없이 k3s 템플릿을 채워 보고 bash·YAML 검사
│   ├── render-check/main.tf      위 스크립트가 쓰는 provider 없는 Terraform
│   ├── tunnel.sh                 SSM 포트 포워딩 (맥 6443 → 시스템 노드 6443)
│   ├── get-kubeconfig.sh         SSM 으로 k3s.yaml 가져오기 → ./kubeconfig
│   ├── bootstrap-argocd.sh       Argo CD 설치 + root-ec2 적용 (--solution 가능)
│   ├── measure.sh                up / ready / argo / spot / down 시간 → results/times.csv
│   └── check-leftovers.sh        destroy 뒤 과금 리소스 남았나
├── results/                      times.csv (측정), rendered/ (렌더 결과, gitignore)
└── solution/                     k3s/, gitops/ 정답본 + README
```

`grep -rn ___ poc/07-ec2-k3s --exclude-dir=solution` 으로 남은 빈칸을 언제든 셀 수 있다.

---

## 4. 단계별

### 4.1 k3s 템플릿 3개 (AWS 없이, 10/26 전)

세 파일을 이 순서로: `server-config` → `agent-config` → `install.sh`. 설정이 무엇인지 먼저 알아야 설치 스크립트가 읽힌다.

**(1) `k3s/server-config.yaml.tftpl`** — 시스템 노드의 `/etc/rancher/k3s/config.yaml` 이 될 내용

| 줄 | 쓸 것 | 참고 |
|---|---|---|
| `token:` | Terraform 이 넘겨 주는 값 `token` 의 자리표시자. 달러 + 중괄호 + 이름 | 1.5절 |
| `write-kubeconfig-mode:` | `0600`(root 만) 또는 `0644`(누구나). get-kubeconfig.sh 는 SSM(root)로 읽으니 둘 다 동작. 고른 이유를 10절 결정 표 "부가 결정" 에 | https://docs.k3s.io/cli/server |
| `node-label:` 2줄 | `키=값` 형식. 1.4절 표의 시스템 노드 라벨 | 같은 문서 `--node-label` |
| `node-taint:` 1줄 | `키=값:effect`. 1.4절 표. **왜 NoSchedule 이 아니라 NoExecute 인지** 한 줄로 말할 수 있어야 한다 | https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/ |

**(2) `k3s/agent-config.yaml.tftpl`** — 실행·빌드 노드 공용. 받는 값: `server_url`, `token`, `pool`, `capacity_type`

| 줄 | 쓸 것 |
|---|---|
| `server:`, `token:` | 자리표시자 두 개 |
| `node-label:` 2줄 | 키는 서버와 같고, 값은 `pool`·`capacity_type` 자리표시자 → 한 파일로 두 풀을 다 만든다 |
| `%{ if ___ ~}` | 조건식. 빌드 풀일 때만 참. 비교는 `==`, 글자열은 큰따옴표 |
| `node-taint:` 1줄 | 빌드 노드 taint (1.4절 표) |
| `kubelet-arg:` 2줄 | graceful node shutdown 옵션 이름 2개. 문서 링크는 파일 주석에 |

**(3) `k3s/install.sh.tftpl`** — 위 둘 중 하나를 품고 첫 부팅 때 실행되는 bash

| 줄 | 쓸 것 |
|---|---|
| `mkdir -p`, `cat >`, `chmod` 의 경로 | k3s 설정 파일이 있어야 하는 **폴더**. 1.4절 첫 줄 |
| heredoc 가운데 | `config` 자리표시자 하나. 위 두 파일 중 하나가 통째로 여기 들어간다 |
| `curl ... \| ___='___' sh -s - ___` | 설치 채널 환경변수 이름(`INSTALL_K3S_` 로 시작), 그 값 자리표시자, 그리고 `role` 자리표시자 | 

읽을 때 볼 줄 (이미 채워져 있음)
- `set -euo pipefail` = 한 줄이라도 실패하면 바로 멈춤(-e), 없는 변수 쓰면 에러(-u), 파이프 중간 실패도 실패로(pipefail).
- `exec > >(tee -a /var/log/k3s-bootstrap.log) 2>&1` = 이 뒤 모든 출력을 화면과 로그 파일 양쪽에. 노드가 클러스터에 안 붙으면 이 로그부터 본다.
- `<<'K3SCONFIG'` 의 작은따옴표 = heredoc 안에서 bash 가 `$` 를 해석하지 않게. 토큰에 특수문자가 있어도 안전.

검사 (AWS·인터넷 필요 없음)

```bash
cd ~/softbank_study_1/Softbank_Study_1/poc/07-ec2-k3s   # 이 단계 폴더로
./scripts/render-k3s.sh
```
- 하는 일: provider 없는 작은 Terraform(`scripts/render-check/main.tf`)으로 세 템플릿에 가짜 토큰·IP 를 넣고 채운다 → `results/rendered/server.sh`, `exec.sh`, `build.sh` 가 생긴다 → 각각 `bash -n`(문법만 검사, 실행 안 함)과 YAML 검사.
- 기대 출력: `ok bash 문법` / `ok YAML` 이 세 역할 모두. 그리고 `build` 줄에만 `node-taint` 가 보인다.
- 빈칸이 남아 있으면 `vars map does not contain key "___"` 같은 에러가 난다. 몇 번째 줄인지 알려 준다.
- 정답본과 비교: `./scripts/render-k3s.sh --solution` 후 `diff`.

확인 질문: 실행 노드 템플릿에서 `capacity_type` 자리표시자를 빼고 `capacity-type=spot` 으로 고정해 버리면, 지금은 문제가 없는데 **어떤 변수 하나를 바꾸는 순간** 거짓말하는 라벨이 되나?

→ `results/rendered/build.sh` 의 heredoc 부분(K3SCONFIG 사이)을 붙여 줘.

### 4.2 GitOps 파일 7개 (AWS 없이, 10/26 전)

1단계에서 쓴 문법 그대로다. 새로운 건 "노드를 고르는 칸"(nodeSelector·tolerations)과 NTH 뿐.

| 파일 | 쓸 것 | 문서 |
|---|---|---|
| `gitops/bootstrap/argocd-values-k3s.yaml` | `global.nodeSelector` = 시스템 노드 라벨, `global.tolerations` = 시스템 taint 를 견디는 것 1개 (`operator: Exists` 면 값은 안 적는다) | 차트 values 의 `global` 절: `helm show values argo/argo-cd --version 10.10.5 \| grep -n -A20 '^global:'` |
| `gitops/bootstrap/root-app.yaml` | 이름(1단계 `root` 와 다르게), path(이 단계 apps 폴더, 레포 루트 기준) | https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/ |
| `gitops/apps/local-stage-apps.yaml` | path = 1단계 App of Apps 가 보는 폴더. **이 한 줄로 앞 단계 앱 전부가 EC2 에 온다** | 1단계 README 9절 |
| `gitops/apps/node-termination-handler.yaml` | 스팟 회수 drain 켜기, DaemonSet 을 스팟 노드에만 (라벨 키: 값) | https://github.com/aws/aws-node-termination-handler |
| `gitops/apps/placement-check.yaml` | 목적지 namespace 자동 생성 옵션 | https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/ |
| `gitops/workloads/placement-check/fn-sample.yaml` | 실행 풀 nodeSelector, PDB minAvailable | https://kubernetes.io/docs/tasks/run-application/configure-pdb/ |
| `gitops/workloads/placement-check/fake-build.yaml` | 빌드 풀 nodeSelector + toleration(키·값·effect 가 taint 와 글자 하나까지 같아야 함) | https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/ |

`global` 이 뭔가: argo-cd 차트는 컴포넌트(server, repo-server, application-controller, redis …)마다 `nodeSelector` 칸이 따로 있다. `global` 에 한 번 적으면 전부에 적용된다. 6개를 따로 적다가 하나 빠뜨리면 그 파드만 실행(스팟) 노드에 떠서, 스팟 회수 때 Argo CD 일부가 같이 죽는다.

NTH 차트 버전: `targetRevision: "0.*"` 은 임시다. 10/27 아침에 아래로 최신 버전을 보고 정확한 숫자로 바꾼다 【미확인: eks-charts 저장소에 최신 NTH 차트가 계속 올라오는지. 안 보이면 공식 README 의 OCI 주소(public.ecr.aws/aws-ec2/helm) 방식으로 바꿔야 하고, 그땐 Argo CD 에 OCI 저장소 등록이 필요하다】.
```bash
helm repo add eks https://aws.github.io/eks-charts   # AWS 공식 Helm 차트 저장소를 'eks' 라는 이름으로 등록
helm search repo eks/aws-node-termination-handler --versions | head -3   # 버전 목록 위 3개
helm show values eks/aws-node-termination-handler | grep -n -E 'daemonsetNodeSelector|enableSpotInterruptionDraining'   # 키 이름 확인 【추정】
```

로컬 kind 로 미리 검사 (AWS 없이)
```bash
grep -rn ___ gitops                                         # 빈칸 0 이어야 함
kubectl apply --dry-run=client -f gitops/workloads/placement-check/   # 문법만 검사, 클러스터에 안 만듦
kubectl apply --dry-run=server -f gitops/workloads/placement-check/ -n default
# ↑ kind 가 켜져 있으면 API 서버가 스키마까지 검사. 오타 난 필드가 있으면 여기서 걸린다
```
**다 채우면 main 에 push 한다.** Argo CD 는 맥이 아니라 GitHub 에서 읽기 때문에, push 안 한 파일은 EC2 클러스터가 못 본다.

확인 질문: `fake-build.yaml` 에서 nodeSelector 는 그대로 두고 toleration 만 지우면 Job 파드는 어떤 상태로 멈추고, `kubectl describe pod` 의 Events 에 어떤 단어가 나올까? (6절에서 직접 해 본다)

→ `kubectl apply --dry-run=client` 출력을 붙여 줘.

### 4.3 Terraform 읽기 (Claude 작성, 10/26 저녁 30분)

고칠 건 없다. 아래 순서로 열어서 주석을 읽고, 질문 3개에 답할 수 있으면 된다.

1. `terraform/budget/main.tf` — 알림 3개(실제 50%·80%, 예측 100%)
2. `terraform/cluster/variables.tf` — 바꿀 수 있는 손잡이 전부. 기본값이 곧 비용 표(7절)의 "기본 구성"
3. `network.tf` → `security.tf` → `iam.tf` — 1.2·1.7절 그림이 코드로 어떻게 되는지
4. `k3s.tf` — 4.1 에서 쓴 템플릿이 어디서 읽히는지. `templatefile` 이 두 겹(설정을 채우고 → 그걸 install 스크립트에 끼움)
5. `server.tf` — 왜 시스템 노드만 `aws_instance` 인지 (주석)
6. `modules/node-pool/main.tf` + `pools.tf` — `mixed_instances_policy` 하나로 스팟·온디맨드를 둘 다 표현하는 방법, `capacity_rebalance`, 23:00 예약
7. `fis.tf` — 회수 실험 대상 고르는 법(태그 Pool=exec + running 중 1대)

질문
- 실행 풀 `instance_types` 에 `t3.medium` 하나만 주면 스팟에서 무엇이 나빠지나?
- `user_data_replace_on_change = true` 가 없으면, k3s 템플릿을 고치고 `apply` 했을 때 무슨 일이 (안) 일어나나?
- NAT 게이트웨이를 안 쓰고 노드에 퍼블릭 IP 를 줬다. 보안상 대가는 무엇이고 어디서 막았나?

정적 검사 (AWS 자격 증명 없어도 됨)
```bash
cd terraform/cluster
terraform init          # provider(aws, random)를 내려받음. .terraform/ 폴더와 .terraform.lock.hcl 생성
terraform validate      # 문법·타입 검사. 기대: Success! The configuration is valid.
terraform fmt -check -recursive ..   # 들여쓰기 규칙. 기대: 출력 없음
```
`terraform plan` 은 AWS 자격 증명이 있어야 한다(AMI·AZ 를 조회). 자격 증명이 있으면 10/26 에 plan 까지 미리 해 본다. plan 은 아무것도 만들지 않는다.

### 4.4 10/27 당일 → [RUNBOOK.md](RUNBOOK.md)

---

## 5. 측정 방법

모두 `scripts/measure.sh` 가 `results/times.csv` 에 한 줄씩 쌓는다. 하루에 1회가 기본, 시간이 남으면 `down` → `up` 을 반복해 3회 (회당 약 15분 【추정】).

| 측정 | 명령 | 시작 → 끝 | 설계 문서에서 쓰는 곳 |
|---|---|---|---|
| apply | `measure.sh up` | apply 시작 → 끝 | "환경 재현 N분" |
| 노드 Ready | `measure.sh ready 4` (apply 직후) | → 4대 Ready | 콜드 스타트 상한 (스팟 교체 때도 이만큼) |
| Argo 동기화 | `measure.sh argo` (root 적용 직후) | → 모든 Application Synced+Healthy | "클러스터 재생성 → 서비스 복구 N분" |
| 스팟 회수 | `measure.sh spot http://<실행 노드 IP>/fn` | FIS 시작 → cordon / 파드 이동 / 교체 노드 Ready + 실패 요청 수 | 스팟 채택 근거 (싸지만 복구 N초, 실패 M건) |
| destroy | `measure.sh down` | destroy 시작 → 끝 | 비용 통제 |
| 실비용 | 다음 날 Cost Explorer (일별, 서비스별) | 10/27 하루 | 7절 추정과 비교 |

빌드 풀 콜드 스타트(셀프 연습)도 같은 CSV 에 손으로 한 줄 추가한다.

---

## 6. 깨뜨렸다 고치기 (빌드 Job 이 갈 곳을 잃는다)

1. `gitops/workloads/placement-check/fake-build.yaml` 에서 `tolerations:` 블록을 통째로 주석 처리.
2. Job 은 이미 완료돼서 다시 안 돈다. 이름을 `fake-build-2` 로 바꾸고 push.
3. 관찰
   ```bash
   kubectl -n placement-check get pods -o wide        # STATUS Pending, NODE <none>
   kubectl -n placement-check describe pod -l job-name=fake-build-2 | tail -5
   # 기대: FailedScheduling ... node(s) had untolerated taint {pool: build}, ... node(s) didn't match Pod's node affinity/selector
   ```
4. 읽는 법: "빌드 노드는 taint 때문에 거절, 나머지 노드는 nodeSelector 가 안 맞아서 거절" → 갈 곳 0.
5. 고치기: 주석 해제 → push → Argo CD 가 Job 을 다시 만들면 `Completed`. 걸린 시간을 메모.
6. 한 줄 정리 (README 하단 결정 표 옆에): 실행 풀에도 taint 를 걸었다면 **모든** 함수 매니페스트에 이 실수가 생길 수 있다 → 결정 3.

같은 실험은 로컬 kind(3·4단계 노드 3개 구성)에서도 되니 AWS 시간을 아끼려면 10/26 에 먼저 해 본다.

---

## 7. 비용 표 (서울 리전, 시간당, USD)

【추정】 2026-10 기준 공개 가격을 기억에 기대 적은 값이다. **10/27 아침에 아래 확인 명령으로 고쳐 쓰고**, 다음 날 실제 청구액과 비교한다. 환율 1 USD ≈ ₩1,400 【추정】.

| 항목 | 단가 | 기본 구성 | 시간당 |
|---|---|---|---|
| 시스템 t3.medium 온디맨드 | $0.052/h | 1대 | $0.052 |
| 실행 t3.medium/t3a.medium **스팟** | 약 $0.016~0.020/h (변동) | 2대 | 약 $0.036 |
| 빌드 t3.medium 온디맨드 | $0.052/h | 1대 | $0.052 |
| EBS gp3 | $0.0912/GB-월 → 20 GB 한 개 ≈ $0.0025/h | 4개 | $0.010 |
| 퍼블릭 IPv4 | $0.005/h 【사실, 위 링크】 | 4개 | $0.020 |
| 데이터 전송(나감) | 월 100 GB 까지 무료 | 이미지 받기는 들어옴(무료) | ≈ $0 |
| SSM Session Manager | 무료 | | $0 |
| **합계** | | | **약 $0.17/h (≈ ₩240)** |

| 비교 시나리오 | 시간당 | 기본 대비 |
|---|---|---|
| 빌드 풀 0대 (`build_desired=0`, 빌드 안 할 때) | 약 $0.11 | −35% |
| 실행 풀도 온디맨드 (`exec_capacity_type=on-demand`) | 약 $0.24 | +40% (스팟 절감액 ≈ $0.07/h) |
| EKS 로 같은 노드 + 컨트롤 플레인 | +$0.10 【사실: EKS 요금】 | +60% |
| 프라이빗 서브넷 + NAT 게이트웨이 1개 | +$0.059 + 처리 GB 당 요금 【추정】 | +35% 이상 |
| 스팟 회수 실험 1회 (FIS) | 액션-분당 $0.10 × 약 2분 ≈ $0.20 【추정】 | 1회성 |

**10/27 하루 예상**: 런북대로 약 4시간 켜면 $0.17 × 4 + FIS 3회 $0.6 ≈ **$1.3 (≈ ₩1,800)**. destroy 를 잊고 23:00 예약으로 실행·빌드만 꺼지고 시스템 노드가 다음 날 아침까지 남아도 약 $2.5. 예산 $5 안쪽.

확인 명령
```bash
# 스팟 현재가 (AZ 별). 표의 스팟 칸을 이 숫자로 바꾼다
aws ec2 describe-spot-price-history --region ap-northeast-2 \
  --instance-types t3.medium t3a.medium --product-descriptions "Linux/UNIX" \
  --start-time "$(date -u +%Y-%m-%dT%H:%M:%S)" \
  --query 'SpotPriceHistory[].[AvailabilityZone,InstanceType,SpotPrice]' --output table
# 온디맨드·EBS·IPv4 단가: https://aws.amazon.com/ec2/pricing/on-demand/ (리전 Asia Pacific (Seoul))
# 다음 날 실제 청구: 콘솔 Billing → Cost Explorer → 기간 10/27, 그룹 기준 Service
```

---

## 8. 문제 해결 표

| 증상 | 먼저 볼 것 | 흔한 원인 |
|---|---|---|
| `get-kubeconfig.sh` 가 "SSM 등록 안 됨" | 콘솔 EC2 → 인스턴스 → 상태 검사 / Systems Manager → Fleet Manager | 인스턴스 프로파일 누락, 아웃바운드 막힘, 부팅 직후(2~3분 기다림) |
| k3s.yaml 을 못 읽음 | `aws ssm start-session --target <server id>` → `sudo tail -n 50 /var/log/k3s-bootstrap.log` | 템플릿 빈칸, YAML 들여쓰기, 설치 채널 이름 오타 |
| 노드가 3대만 Ready | `kubectl get nodes -L pool,capacity-type` / 실행 노드에 들어가 `sudo journalctl -u k3s-agent -n 50` | 토큰·서버 주소 자리표시자 오타, 스팟 재고 부족(콘솔 ASG → 활동 탭) |
| Argo CD 파드 Pending | `kubectl -n argocd describe pod <이름>` Events | `global.tolerations` 와 시스템 taint 불일치 |
| `kubectl` 이 `connection refused` | tunnel.sh 창이 살아 있나 | 터널 끊김. 다시 실행 |
| `curl <IP>/fn` 응답 없음 | `ingress_cidrs` 에 지금 내 IP 가 있나 (`curl -s https://checkip.amazonaws.com`) | 카페·학교 와이파이로 IP 바뀜 → tfvars 고치고 apply (보안 그룹만 바뀜) |
| destroy 가 VPC 에서 멈춤 | `check-leftovers.sh` | 콘솔에서 손으로 만든 것(ENI 등)이 VPC 에 남음 |

---

## 9. 이 단계가 끝난 상태

| 항목 | 값 |
|---|---|
| 재현 명령 | `terraform -chdir=terraform/cluster apply` → `tunnel.sh` → `get-kubeconfig.sh` → `bootstrap-argocd.sh` |
| 클러스터 | k3s (채널 stable, 실제 버전은 times.csv 의 nodes_ready 메모), 서울, 노드 4 (system 1 / exec 스팟 2 / build 1) |
| Argo CD | 1단계와 같은 차트 10.10.5 + `argocd-values-k3s.yaml`, 시스템 노드에만 |
| Git | root-ec2 → `poc/07-ec2-k3s/gitops/apps/` → 앞 단계 앱 전부 + NTH + placement-check |
| 남는 것 | 예산 알람(계속), `results/times.csv`. **EC2·VPC 는 그날 destroy** |
| 본선에 가져갈 것 | 같은 Terraform 으로 본선 계정에 1회 apply 하면 팀 공용 클러스터. 노드 풀 구조가 그대로 FaaS 설계 문서의 "인프라" 절 |

---

## 10. 핵심 결정 3개 (+대안)

| 결정 | 이 PoC 의 선택 | 대안과 버린 이유 |
|---|---|---|
| 1. 클러스터를 어떻게 세우나 | **EC2 위 k3s, server 1대(온디맨드) + agent ASG** | (가) EKS: 컨트롤 플레인 시간당 $0.10 추가, 생성이 길고, 작년 본선 우승팀처럼 "VM 위 직접 구축" 을 보여 줄 수 없다. (나) kubeadm: CKA 출제 방식이라 공부엔 좋지만 설치 단계(containerd, kubeadm init/join, CNI)가 많아 당일 시간을 다 쓴다 → CKA 공부(본선 후)로. (다) server 3대 HA(내장 etcd): 컨트롤 플레인 비용 3배. 작년 우승팀도 컨트롤 플레인 1대였다 【사실: career/03 §6, kops-repo cluster.yaml】. 설계 문서엔 "본선 뒤 HA 로" 한 줄 |
| 2. 풀별 구매 방식 | **시스템 온디맨드 / 실행 스팟 2대(타입 2종, price-capacity-optimized) / 빌드 온디맨드** | (가) 전부 온디맨드: 시간당 약 40% 비쌈. (나) 빌드도 스팟: 더 싸지만 빌드 도중 회수되면 처음부터 다시 → 빌드 시간 숫자가 흔들린다. 빌드가 짧고(수십 초) 재시도해도 되면 스팟으로 바꿀 수 있다 → 셀프 연습에서 판단. (다) 시스템도 스팟: 회수 = 클러스터 API 증발 |
| 3. taint 를 어디에 거나 | **시스템(CriticalAddonsOnly NoExecute)·빌드(pool=build NoSchedule) 에만, 실행 풀은 안 건다** | (가) 실행 풀에도 taint: 모든 함수·앞 단계 앱에 toleration 을 달아야 하고 하나만 빠져도 그 앱은 갈 곳이 없다(6절). (나) taint 없이 라벨만: 아무 파드나 시스템·빌드 노드에 떠서 Argo CD·빌드와 메모리를 다툰다 |

부가 결정 (Jeong 이 채움)

| 결정 | 선택 | 이유 한 줄 |
|---|---|---|
| `write-kubeconfig-mode` | ___ | ___ |
| 클러스터 접속 | SSM 포트 포워딩 (6443·22 닫음) | 대안 6443 을 내 IP 로만 열기: IP 가 바뀔 때마다 apply, 인증서에 퍼블릭 IP 추가 필요 |
| 스팟 회수 대응 | NTH(drain) + graceful node shutdown | 대안 shutdown 만: 2분 예고를 못 쓰고 마지막 60초에 몰아서 정리 |
| 토큰 전달 | Terraform random_password → user_data | 대안 SSM Parameter Store: 더 안전(user_data 는 EC2 권한 있는 사람이 읽음)하지만 IAM·스크립트가 늘어남. 본선에서 팀 계정이면 Parameter Store 로 |

## 셀프 연습 1개

**빌드 풀 0대에서 시작하는 콜드 스타트를 재고, 결정 2 를 다시 판단한다.**
1. `terraform apply -var build_desired=0` (빌드 노드만 사라짐)
2. 6절처럼 이름을 바꾼 Job 을 push → Pending 확인
3. 시계 시작과 함께 `terraform apply -var build_desired=1` → Job 이 `Completed` 될 때까지 시간
4. 그 숫자로 판단: "빌드 노드를 평소 0대로 두고 요청 때 1대 띄우기(시간당 $0.052 절약)" 가 사용자 체감 몇 초를 대가로 하나? 이걸 자동으로 하려면 무엇이 필요한가(힌트: cluster-autoscaler 의 ASG 연동 https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler/cloudprovider/aws)
5. 결과를 `results/times.csv` 에 `build_cold_start` 로 한 줄, 판단을 결정 2 대안 칸에 한 줄.

## 검증 명령과 기대 출력

```bash
# (10/26, AWS 없이)
./scripts/render-k3s.sh
# 기대: ok bash 문법 ×3, ok YAML ×3, build 에만 node-taint

grep -rn ___ k3s gitops
# 기대: 출력 없음

terraform -chdir=terraform/cluster validate
# 기대: Success! The configuration is valid.

# (10/27, apply 후)
kubectl get nodes -L pool,capacity-type
# 기대: 4줄 Ready. system 1(on-demand), exec 2(spot), build 1(on-demand)

kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints[*].key
# 기대: system 노드 CriticalAddonsOnly, build 노드 pool, exec 노드 <none>

kubectl -n argocd get pods -o wide | awk '{print $7}' | sort | uniq -c
# 기대: 노드 이름이 시스템 노드 하나뿐

kubectl -n argocd get applications
# 기대: root-ec2, local-stage-apps, node-termination-handler, placement-check, hello-fn(앞 단계) 모두 Synced / Healthy

kubectl -n placement-check get pods -o wide
# 기대: fn-sample 2개가 서로 다른 exec 노드, fake-build 는 build 노드에서 Completed

curl -s http://<실행 노드 퍼블릭 IP>/fn | head -3
# 기대: Hostname: fn-sample-xxxx (whoami 응답)

cat results/times.csv
# 기대: apply, nodes_ready, argo_synced, spot_cordon, spot_pods_moved, spot_replaced, spot_requests, destroy 줄

./scripts/check-leftovers.sh
# 기대: == 통과: 과금 리소스 없음 (ap-northeast-2)
```
