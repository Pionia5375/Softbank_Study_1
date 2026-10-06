로드맵 위치: W1 D7 (10/11 분량, 10/6 진행) / Terraform으로 로컬 환경 한 번에 / 본선 연결점: 10/11 게이트 "셋업 드릴 60분 + 두 환경 배포". 본선에서 팀이 섞여도 `terraform apply` 한 줄로 같은 환경을 다시 세운다. 작년 우승 스택에도 Terraform 이 있었다 (P0-4).

# Lab 07 — Terraform 으로 kind + Traefik + metrics-server + hello 한 번에

Lab 02~04 에서 손으로 친 명령 (`kind create cluster`, `helm install traefik`, `helm install metrics-server`, `kind load docker-image`, `helm install hello`) 을 Terraform 코드로 옮긴다. 목표는 셋:

1. `terraform apply` 한 줄 → `curl localhost:8088/hello` 가 200
2. 같은 모듈로 환경 두 개 (dev / demo) 를 띄운다
3. apply·destroy 를 환경마다 3번씩 돌리고 시간을 잰다

AWS 는 안 쓴다. 전부 맥 안 (kind) 에서 끝난다.

## 큰 그림

```
envs/dev (또는 envs/demo)          ← 여기서 terraform 실행. 값은 terraform.tfvars
  │
  ├─ module "cluster"   (modules/cluster)
  │     kind_cluster: control-plane 1 + 워커 N, 맥 host_port → 노드 30080
  │     output: name, endpoint, 인증서 3종, host_port
  │            │
  │            ▼  (output → input)
  ├─ provider "helm"   ← endpoint·인증서로 클러스터에 붙는다
  │            │
  └─ module "platform"  (modules/platform)
        helm_release traefik         (Lab 02 traefik-values.yaml 그대로)
        helm_release metrics_server  (kube-system, --kubelet-insecure-tls)
        terraform_data load_hello_image  → kind load docker-image lab01-hello:multi
        helm_release hello           (Lab 04 차트 + values-demo.yaml, replicas 만 덮어쓰기)
```

Terraform 은 이 화살표(누가 누구 값을 쓰는지)를 보고 순서를 정한다. 만들 땐 위→아래, 지울 땐 아래→위.

## 용어

| 용어 | 한 줄 뜻 |
|---|---|
| provider | Terraform 이 바깥 세상(kind, Helm, AWS…)을 만지게 해 주는 플러그인. `terraform init` 때 받는다 |
| resource | "이런 게 있어야 한다" 한 덩어리. 예: `kind_cluster`, `helm_release` |
| module | resource 묶음 + 입력(variable) + 출력(output). 폴더 하나 = 모듈 하나. 같은 모듈을 값만 바꿔 여러 번 쓴다 |
| variable / output | 모듈의 입력칸 / 모듈이 밖으로 내보내는 값. A 모듈 output 을 B 모듈 variable 에 꽂으면 A 가 먼저 만들어진다 |
| state | Terraform 의 기억장. "내가 뭘 만들었고 지금 어떤 값인지" 를 `terraform.tfstate` 파일에 적어 둔다 |
| plan / apply / destroy | plan = 코드 vs state vs 실제를 비교해서 할 일 목록만 보여 줌. apply = 그걸 실행. destroy = 만든 걸 전부 지움 |
| drift | 실제 상태가 state 기억과 달라진 것. 예: Terraform 몰래 `kind delete cluster` 를 한 경우 |
| provisioner | resource 를 만들 때 셸 명령을 덤으로 실행. Terraform 이 결과를 추적 못 해서 최후 수단이다 |

## 구조

```
labs/07-terraform-kind/
├── modules/
│   ├── cluster/              kind 클러스터 (워커 라벨·taint 는 변수)
│   │   ├── versions.tf       provider 버전 고정 (tehcyx/kind ~> 0.11.0)
│   │   ├── variables.tf      name, node_image, host_port, node_port, workers
│   │   ├── main.tf
│   │   └── outputs.tf        name, endpoint, 인증서 3종 → envs 와 platform 이 받는다
│   └── platform/             클러스터 위에 올릴 것들
│       ├── versions.tf       hashicorp/helm ~> 3.3
│       ├── variables.tf
│       ├── main.tf           TODO(human) 1곳: hello 의 wait
│       └── outputs.tf        hello_url, 차트 버전
├── envs/
│   ├── dev/                  tf-dev,  워커 1 (tier=app),            hello 1개, 맥 8088
│   └── demo/                 tf-demo, 워커 2 (app / batch+taint),   hello 3개, 맥 8089
│       (두 폴더는 terraform.tfvars 만 다르고 나머지 .tf 는 같다)
├── scripts/drill.sh          apply → curl → destroy 를 N번, 시간 기록
└── results/                  drill.log (git 제외)
```

워커 라벨·taint: `tier=app` 워커 1, `tier=batch` + `dedicated=batch:NoSchedule` 워커 2. Lab 05 (taint/toleration) 에서 이 모양을 쓴다고 가정했다. 바꾸려면 `terraform.tfvars` 의 `workers` 만 고치면 된다.

## 진행 순서

모든 명령은 이 폴더에서: `cd labs/07-terraform-kind`

### 0. 준비

```bash
brew tap hashicorp/tap                  # HashiCorp 공식 저장소 추가 (brew 기본 terraform 은 1.5.7 에서 멈춰 있다)
brew install hashicorp/tap/terraform    # 2026-10 기준 최신 1.16.x
terraform version                       # Terraform v1.16.x on darwin_amd64
docker images lab01-hello:multi         # 없으면 Lab 01 에서 빌드
kind get clusters                       # lab02 가 보이면 아래 줄
kind delete cluster --name lab02        # lab02 가 맥 8088 을 잡고 있어서 dev 와 부딪힌다. 메모리도 돌려받는다
```

OpenTofu 로 하고 싶으면 `brew install opentofu` 후 아래 `terraform` 을 전부 `tofu` 로 바꾼다 (드릴은 `TF=tofu scripts/drill.sh dev`).

### 1. 코드 읽기 (10분)

```bash
cat modules/cluster/main.tf             # kind-config.yaml 이 HCL 로 어떻게 바뀌었나
cat modules/platform/main.tf            # helm install 3번 + kind load 1번
cat envs/dev/main.tf                    # module.cluster.endpoint 가 platform 으로 들어가는 줄 찾기
diff envs/dev envs/demo                 # tfvars 만 다르다는 걸 확인
```

`modules/platform/main.tf` 의 TODO(human) (hello 의 `wait`) 를 읽고 정한다. 모르겠으면 추천값 `true` 그대로 둔다.

### 2. dev 한 번 띄우기

```bash
cd envs/dev
terraform init                          # provider 2개(kind, helm) 다운로드 + .terraform.lock.hcl 생성 (이 파일은 커밋)
terraform plan                          # 만들 것 목록. "Plan: 5 to add" 쯤이 나와야 한다
time terraform apply                    # yes 입력. 클러스터 → helm 3개 순서로 만든다
curl -s localhost:8088/hello            # 응답 오면 성공
kubectl --context kind-tf-dev get nodes -L tier     # control-plane + worker(tier=app)
kubectl --context kind-tf-dev get pods -A -o wide   # traefik, metrics-server, hello 가 어느 노드에 있나
```

kind 가 맥의 `~/.kube/config` 에 `kind-tf-dev` context 를 넣어 준다. 같은 내용이 `envs/dev/tf-dev-config` 파일로도 떨어진다 (git 제외).

### 3. state 들여다보기

```bash
terraform state list                    # Terraform 이 기억하는 resource 목록 (5줄)
terraform state show module.cluster.kind_cluster.this   # 클러스터 하나의 기억 내용 (endpoint, node_image …)
terraform state show module.platform.helm_release.hello # 차트 경로, values, replicaCount
terraform output                        # envs/dev/outputs.tf 의 값. sensitive 는 (sensitive) 로 가려진다
terraform plan                          # 아무것도 안 바꿨으니 "No changes." 가 나와야 한다
```

`terraform.tfstate` 를 열어 보면 인증서·키가 평문으로 들어 있다. 그래서 git 에 안 올리고, 팀이 쓸 땐 원격 state (S3 등) + lock 으로 옮긴다 (10/12~13).

### 4. 값 하나 바꿔 보기

```bash
terraform apply -var hello_replicas=2   # plan 에 helm_release.hello 만 "~ update in-place" 로 나온다
terraform apply -var host_port=8090     # 이번엔 kind_cluster 가 "-/+ must be replaced" → 클러스터부터 통째로 다시. kind provider 는 수정을 못 한다
terraform apply                         # tfvars 값으로 되돌리기 (두 번째 줄을 yes 했다면 또 재생성)
```

두 번째 줄은 plan 만 보고 `no` 해도 된다. "어떤 값은 제자리 수정, 어떤 값은 재생성" 을 plan 기호(`~`, `-/+`)로 읽는 게 목적.

### 5. destroy

```bash
time terraform destroy                  # hello → metrics-server, traefik → 클러스터 순으로 지운다
kind get clusters                       # tf-dev 가 없어야 한다
cd ../..
```

### 6. 드릴: 환경마다 3번 (측정표 채우기)

```bash
scripts/drill.sh dev                    # apply → curl 200 → destroy ×3, results/drill.log
scripts/drill.sh demo                   # 같은 걸 demo 로
```

마지막에 요약표가 찍힌다. 그대로 아래 측정표에 옮긴다. 한 회 3~4분 【추정】 이라 두 환경 합쳐 20~25분.

### 7. 두 환경 동시에 (게이트 "두 환경 배포")

```bash
(cd envs/dev  && terraform apply -auto-approve)
(cd envs/demo && terraform apply -auto-approve)
curl -s localhost:8088/hello; echo; curl -s localhost:8089/hello; echo
docker stats --no-stream --format '{{.Name}}\t{{.MemUsage}}'   # 노드 컨테이너 5개 메모리 합 → 측정표
kubectl --context kind-tf-demo get nodes -L tier                 # 워커 2개, tier=app / tier=batch
kubectl --context kind-tf-demo describe node tf-demo-worker2 | grep Taints   # dedicated=batch:NoSchedule
(cd envs/demo && terraform destroy -auto-approve)
(cd envs/dev  && terraform destroy -auto-approve)
```

state 는 폴더마다 따로다 (`envs/dev/terraform.tfstate`, `envs/demo/terraform.tfstate`). 그래서 dev 를 지워도 demo 는 안 건드린다.

## 메모리·포트

- 포트: dev 는 맥 8088, demo 는 8089. 클러스터 안쪽 (Traefik NodePort) 은 둘 다 30080 이다. 안쪽 포트는 클러스터마다 따로라 안 부딪힌다. 부딪히는 건 맥 쪽 포트뿐이다
- Lab 02 의 `lab02` 클러스터가 살아 있으면 8088 이 이미 잡혀 있다. 0단계에서 지운다
- 메모리 어림 【추정】: Lab 02 에서 노드 1대짜리 K8s 가 약 510MB, hello Pod 1개가 약 175MB 였다. 워커 노드 1대 +200MB 쯤으로 잡으면 dev 약 1.3GB, demo 약 1.9GB, 동시에 약 3.2GB
- 7.7GB Docker Desktop 에 둘 다 들어가긴 한다. 하지만 측정할 땐 한 번에 하나만 띄운다 (6단계). 둘이 같이 뜨면 CPU 를 나눠 써서 apply 시간이 부풀려진다. 동시 실행은 7단계에서 한 번, 메모리 숫자 재는 용도로만
- 클러스터 여러 개를 띄울 때 kind 가 "too many open files" 로 실패하는 경우가 있다 (Docker VM 의 inotify 한도). 노드 5대 정도는 보통 괜찮다 【추정】

## 측정표

| 항목 | 방법 | 1회 | 2회 | 3회 |
|---|---|---|---|---|
| dev apply (s) | drill.sh dev | | | |
| dev apply 후 첫 200 (s) | drill.sh dev | | | |
| dev destroy (s) | drill.sh dev | | | |
| demo apply (s) | drill.sh demo | | | |
| demo apply 후 첫 200 (s) | drill.sh demo | | | |
| demo destroy (s) | drill.sh demo | | | |

| 항목 | 방법 | 결과 |
|---|---|---|
| 손으로 했을 때 (Lab 02: 클러스터 30.5s + helm·load 명령) 대비 | Lab 02 측정표와 비교 | |
| dev + demo 동시, 노드 컨테이너 메모리 합 | 7단계 `docker stats` | |
| 드릴 전체 (0단계 ~ demo 3회 끝) | 시계 | 60분 안? |

## 핵심 결정 3개와 대안

1. **도구 = Terraform**
   - 대안: OpenTofu (Terraform 1.5 에서 갈라진 오픈소스판. 문법·명령 거의 같고 `tofu` 로 바꿔 부르면 된다), Pulumi Java (익숙한 언어로 쓰지만 팀원이 못 읽을 수 있고 state 기본 저장소가 Pulumi 서비스), 셸 스크립트 (제일 빠르게 쓰지만 "지금 상태 vs 원하는 상태" 비교가 없다. 두 번 돌리면 "이미 있다" 에러, 반쯤 실패하면 어디까지 됐는지 모른다)
   - 이유: 작년 우승팀·예선 팀 모두 Terraform. 본선 팀이 섞여도 공용어가 된다. 라이선스 (BSL) 가 걸리면 OpenTofu 로 바로 옮길 수 있다는 것도 대안 설명에 쓸 수 있다
2. **클러스터 = kind provider (`tehcyx/kind`)**, 이미지 넣기만 provisioner
   - 대안: `terraform_data` + `kind create cluster` 셸 호출 (kind CLI 버전 그대로 쓰지만 endpoint·인증서를 output 으로 못 넘기고, destroy 도 셸로 따로 써야 한다), Terraform 없이 Lab 02 명령을 셸로 (위 1번과 같은 문제)
   - 이유: 클러스터가 state 에 올라가서 endpoint·인증서를 output → helm provider 입력으로 꽂을 수 있다. 대가: (a) provider 안에 든 kind 라이브러리는 v0.31 이라 맥의 kind CLI v0.33 과 다르다, (b) 값 하나만 바꿔도 클러스터 재생성, (c) `kind load` 는 provider 에 없어서 local-exec 로 메웠다. 노드 안 이미지를 지워도 Terraform 은 모른다
3. **state = 지금은 local (폴더마다 terraform.tfstate)**
   - 대안: 원격 state (S3 + DynamoDB lock 또는 S3 네이티브 lock, Terraform Cloud) — 팀원 둘이 동시에 apply 해도 lock 이 막아 주고 state 를 잃어버리지 않는다
   - 이유: 혼자 맥에서 쓰는 단계라 lock 이 필요 없고 AWS 를 안 쓴다는 규칙도 지킨다. 10/12~13 에 원격 state + lock 으로 옮긴다. 그때 envs/* 의 `terraform {}` 에 backend 블록만 더하면 된다

## 스스로 풀어 볼 문제 1개

dev 를 apply 해 둔 상태에서 Terraform 몰래 클러스터를 지운다.

```bash
cd envs/dev && terraform apply -auto-approve
kind delete cluster --name tf-dev
terraform plan
```

질문: plan 은 (a) "클러스터를 새로 만들게요" 라고 할까, (b) 에러를 낼까? state 는 아직 클러스터가 있다고 기억하고 있다. 예상을 먼저 적고 → 실행 → 그다음 `terraform apply` 로 다시 정상(curl 200)까지 되돌려 본다.

<details>
<summary>힌트 (예상 적은 다음에 열기)</summary>

- 이 provider 의 Read 함수 소스를 보면 클러스터를 못 찾을 때 "없음" 으로 처리하는 게 아니라 에러를 돌려준다. 그래서 (b) 쪽일 가능성이 높다 【추정: 소스만 읽음, 실행 안 함】
- 되돌리는 법 후보: `terraform state list` 로 기억 목록을 보고, 실제로 사라진 것들의 기억을 지운다 (`terraform state rm 'module.cluster'` `terraform state rm 'module.platform'`) → `terraform apply`. 클러스터가 사라지면 그 위 helm 릴리스도 같이 사라졌다는 점이 포인트
- 왜 `terraform apply -refresh=false` 는 답이 아닌지도 생각해 보기

</details>

## 검증 명령과 기대 출력

```bash
cd envs/dev
terraform validate                                  # Success! The configuration is valid.
terraform state list
# module.cluster.kind_cluster.this
# module.platform.helm_release.hello
# module.platform.helm_release.metrics_server
# module.platform.helm_release.traefik
# module.platform.terraform_data.load_hello_image
terraform plan -detailed-exitcode; echo $?          # No changes. → 0 (바뀐 게 있으면 2)
curl -s -o /dev/null -w '%{http_code}\n' localhost:8088/hello   # 200
kubectl --context kind-tf-dev get nodes -L tier     # tf-dev-control-plane, tf-dev-worker (TIER=app)
kubectl --context kind-tf-dev top nodes             # 1분쯤 뒤 CPU·MEMORY 숫자 (metrics-server 동작)
kubectl --context kind-tf-demo get deploy hello     # demo 를 띄웠다면 READY 3/3
```

## 알려진 불확실한 점

- 【미확인】 provider 안의 kind 라이브러리 (v0.31) 로 `kindest/node:v1.37.0` 이 뜨는지. Lab 02 는 kind CLI v0.33 으로 띄웠다. apply 가 kubeadm 쪽 에러로 실패하면 `terraform.tfvars` 에 `node_image = null` 을 넣는다 → provider 기본값 `kindest/node:v1.35.0` 을 받는다 (첫 apply 때 이미지 다운로드 1GB 안팎 추가)
- 【미확인】 Traefik·metrics-server 차트 버전은 고정 안 했다 (Lab 02·04 와 같이 최신). 첫 apply 후 `terraform output releases` 로 버전을 보고 `modules/platform` 의 `*_chart_version` 기본값에 적으면 재현성이 올라간다
- 【미확인】 OpenTofu 로 돌릴 때 `tehcyx/kind` 를 OpenTofu 레지스트리에서 받을 수 있는지
