# 06. 기술 스택 지도 — 2025 본선 우승팀(sh-final-blue) 스택 분해

> 작성일: 2026-10-05 · 범위: 조사 요청 6번 "[기술 스택 지도]"만 다룸
> 대상 독자: Java/Spring 백엔드 경험 O, 인프라 실습 경험 거의 없음

## 표기 규칙

| 표시 | 의미 |
|---|---|
| **[사실]** | sh-final-blue 레포의 코드·설정·README에서 직접 확인한 내용 (파일 경로 병기) |
| **[공식]** | 해당 프로젝트/벤더의 공식 문서·공식 블로그 기준 |
| **[추정]** | 레포 근거로부터의 추론, 또는 일반적인 업계 지식에 기반한 판단 (검증 안 됨) |
| **[없음]** | 찾아봤지만 레포에 근거가 없는 것 |

출처 레포 (2026-10-05 클론 시점 HEAD):
`.github`(ad9c604) · `infra-iac`(0328554) · `kops-repo`(36faeac) · `poc-wasm-spin`(b907aec) · `web-faas-builder`(cfb5b99) · `web-backend`(f685ba5) · `helm-charts`(c92ee0f) · `2025softbank-hackathon-final`(aea6514)
모두 `https://github.com/sh-final-blue/<레포명>`.

---

## 0. 한 장 요약

- **주제** [사실]: "Run Your Functions Instantly over HTTP — EC2/Compute Engine 위에서 구현하는 차세대 Serverless 플랫폼" (`.github/profile/README.md`). 기간 2025.11.28–12.07.
- **핵심 아이디어** [사실]: 컨테이너 대신 **WebAssembly(Spin)** 로 함수를 실행해 콜드스타트와 격리 문제를 해결한다는 서사.
- **실제 구조** [사실]:
  사용자 Python 코드 → (FastAPI Builder) `mypy` 검증 → `spin build`로 WASM 빌드 → `spin registry push`로 **ECR(OCI)** 에 푸시 → `spin kube scaffold`로 **SpinApp** 매니페스트 생성 → `kubectl apply` → **SpinKube(spin-operator + containerd-shim-spin)** 가 노드에서 WASM 실행.
  클러스터는 **Terraform으로 VPC/ALB/CloudFront/WAF/ECR**을 만들고, **kOps로 자체 관리형 K8s**(Cilium, Cluster Autoscaler, Spot 노드 그룹)를 올림. 관측은 **Prometheus + Loki**를 백엔드 API가 직접 질의해 함수별 CPU·로그를 대시보드에 노출.
- **진화 과정** [사실, 커밋 이력]: POC는 **RKE2** (`poc-wasm-spin/README.md`) → Terraform으로 **K3s** 클러스터 모듈 작성(11/30) → 12/01 "Disable K3s cluster by default" → 최종 **kOps** (`kops-repo`, 12/06 커밋). 즉 **같은 문제를 세 가지 K8s 배포판으로 시도**한 흔적.
- **학습자에게 중요한 관찰** [추정]: 우승 포인트는 "도구 개수"보다 **"서버리스의 본질 문제(콜드스타트·격리·비용)를 정의하고, 그걸 푸는 기술(WASM)을 골라, 그 선택이 인프라 설계(Spot·노드 분리·오토스케일)까지 일관되게 이어진 것"**으로 보인다. 단, README의 "Docker 대비 10~100배 빠른 기동"은 **레포 안에 측정 스크립트·결과가 없음** [없음]. 우리가 본선에서 차별화할 지점은 바로 이 "실측 숫자"다.

---

## 1. 레포별 역할 지도 [사실]

| 레포 | 언어/형태 | 역할 | 비고 |
|---|---|---|---|
| `.github` | Markdown | 조직 프로필 README(발표용 요약) | 기술 스택 배지, 아키텍처 그림, 로드맵(KEDA, OTel/Tempo) |
| `infra-iac` | Terraform(HCL) | VPC, SG, ECR, ALB, CloudFront+S3, WAF, Secrets Manager, (K3s 모듈, Bastion) | state는 S3 + DynamoDB lock (`backend.tf`). K3s·Bastion은 최종적으로 비활성 |
| `kops-repo` | YAML + Shell + 문서 | kOps `cluster.yaml`(K8s 1.33.6), ALB 라우팅 스크립트, IRSA·ALB 가이드, 트러블슈팅 리포트 | 커밋 1개(최종 스냅숏 업로드로 보임 [추정]) |
| `poc-wasm-spin` | Python | RKE2 위 SpinKube POC, 빌드·배포 FastAPI 초안 | `.kiro/specs/` 존재 → Kiro(AI IDE) 스펙 기반 개발 [사실] |
| `web-faas-builder` | Python(FastAPI) | **빌더 서비스**: 검증→빌드→ECR 푸시→scaffold→deploy, S3/DynamoDB에 작업 상태 저장 | k8s 매니페스트(Kustomize, HPA, IRSA), GitHub Actions로 ECR 빌드 |
| `web-backend` | Python(FastAPI) + React | **플랫폼 API**(워크스페이스/함수 CRUD, invoke, 로그·메트릭 조회) + 프론트엔드 + Helm 차트 | GitHub 표시 언어는 TypeScript지만 백엔드는 Python |
| `helm-charts` | Helm | 백엔드 배포 차트 | 커밋 2개 |
| `2025softbank-hackathon-final` | TypeScript | 프론트엔드(Vite + React + shadcn/ui + Monaco 에디터 + Recharts) | `lovable-tagger` 의존성 → Lovable(AI 웹 빌더)로 초안 생성 [추정] |

---

## 2. 기술 스택 지도 (핵심 표)

난이도 기준 (Java/Spring 백엔드·인프라 실습 0 기준) [추정]:
**★1** 하루 안에 "돌려보기" 가능 · **★2** 2~3일 · **★3** 1주 · **★4** 1~2주, 사전지식(네트워크·리눅스·K8s) 필요 · **★5** 2주+, 디버깅에 깊은 이해 필요

### 2-1. 인프라 프로비저닝 / 클러스터

| 기술 | 어디서 확인 [사실] | 왜 썼나 | 대안 | 난이도 | Spring 개발자 관점 비유 [추정] |
|---|---|---|---|---|---|
| **AWS** (서울 리전) | `infra-iac/providers.tf`, `kops-repo/README.md` | [사실] 해커톤 제공 환경으로 보임(테마 문구 "EC2/Compute Engine 위에서"). [추정] 주제가 "관리형 서버리스(Lambda) 쓰지 말고 VM 위에 직접 만들어라"였을 가능성 | GCP Compute Engine, 온프렘 VM | ★3 (VPC/서브넷/SG/IAM 개념) | — |
| **Terraform** | `infra-iac/` 모듈 9개, S3+DynamoDB 원격 state | [사실] VPC·ALB·CloudFront·WAF·ECR 등 **클러스터 바깥 AWS 리소스**를 코드로 관리. [추정] 팀원 간 재현성, 8일짜리 비용 추산(README에 8일 예상비용 표)까지 문서화 | **OpenTofu**(Terraform 오픈소스 포크, 문법 거의 동일), **Pulumi**(Java/TS 등 일반 언어로 IaC — Java 개발자에게 진입장벽 낮음), AWS CDK, CloudFormation, Crossplane(K8s CRD로 클라우드 리소스 관리) | ★2~3 (문법은 쉽고, plan/apply/state 개념과 AWS 리소스 이해가 본체) | `build.gradle`처럼 선언형으로 "원하는 상태"를 적고, `terraform plan`은 일종의 dry-run diff |
| **K3s → kOps** (+ POC의 RKE2) | `infra-iac/modules/k3s/`(비활성), `kops-repo/cluster.yaml`, `poc-wasm-spin/README.md` | [사실] 최종은 kOps로 **Self-managed K8s** 구축, 컨트롤 플레인 1대(t4g.medium) + 노드 그룹 5종. [추정] EKS가 아닌 이유: ① 노드에 **containerd-shim-spin**을 설치해야 해서 노드 OS·containerd 설정 제어가 필요 ② "VM 위에 직접 구현"이라는 테마 충족 ③ K3s 수동 설치보다 kOps가 **인스턴스 그룹·Spot·Cluster Autoscaler·IRSA**를 선언형으로 한 번에 제공. 단 K3s→kOps 전환 이유는 레포에 명시 안 됨 [없음] | **EKS**(관리형 컨트롤 플레인, 커스텀 AMI/노드 부트스트랩으로 shim 설치 가능 [추정]), **K3s**(가볍고 단일 바이너리, 수동 HA·오토스케일 구성 필요), RKE2, kubeadm, Cluster API | kOps ★4, K3s ★3, EKS ★3 | 톰캣을 직접 설치·튜닝(kOps) vs 클라우드 PaaS에 WAR 올리기(EKS) |
| **Cilium** (kube-proxy 대체) | `cluster.yaml`: `networking.cilium`, `kubeProxy.enabled: false` | [사실] eBPF 기반 네트워킹. [추정] 성능/관측 이점 + 최신 기술 어필 | AWS VPC CNI(EKS 기본), Calico, Flannel(K3s 기본) | ★4 (네트워크 문제 디버깅이 어려움) | — |
| **Cluster Autoscaler** | `cluster.yaml`: `clusterAutoscaler.enabled`, `scaleDownUtilizationThreshold: 0.5` | [사실] 노드 수 자동 조절. Spot 노드 그룹 3~6대 | **Karpenter**(그룹 없이 파드 요구에 맞춰 인스턴스 직접 선택, 빠름), 수동 스케일 | ★3 | 커넥션 풀 min/max를 노드 단위로 |
| **Spot 인스턴스 + 노드 그룹 분리** | `cluster.yaml`: spot(c5/c6i/c7i.large, capacity-optimized), observability(taint), build(c7i.xlarge, taint) / `web-faas-builder/src/models/manifest.py`: `use_spot=True` 기본 | [사실] Stateless WASM 실행 노드는 Spot으로 비용 절감, 빌드·모니터링은 taint로 격리. [추정] "빌드가 실행 노드를 잡아먹지 않게" = 노이지 네이버 방지 | 전부 On-Demand, Fargate, Savings Plan | ★3 (taint/toleration/affinity 개념) | 스레드 풀을 작업 종류별로 분리(벌크헤드 패턴) |
| **AWS Load Balancer Controller / ALB** | `kops-repo/README.md` 애드온 목록, `infra-iac/modules/alb`, `kops-repo/scripts/add-alb-route.sh` | [사실] HTTPS 진입점, `*.eunha.icu` 와일드카드로 서비스 라우팅. [사실] 부트스트랩 시 ALB 컨트롤러 webhook이 먼저 등록돼 파드 생성이 막힌 **chicken-egg 장애**를 겪음(`troubleshooting-report.md`). [추정] 그래서 Terraform으로 만든 ALB에 스크립트로 라우트를 붙이는 방식도 병행 | NGINX Ingress / Gateway API, Traefik(K3s 기본), Cilium Gateway | ★3~4 | — |
| **IRSA** (IAM Roles for Service Accounts) | `cluster.yaml`: `serviceAccountIssuerDiscovery`, `kops-repo/docs/AWS-IRSA-GUIDE.md`, `web-faas-builder/k8s/serviceaccount.yaml` | [사실] 빌더 파드가 액세스 키 없이 ECR/S3/DynamoDB 접근 | EKS Pod Identity, 노드 IAM 롤(권한 과다), Secret에 키 저장(비권장) | ★4 (OIDC·IAM 신뢰 정책) | Spring Security에서 서비스 계정별 권한 위임 |
| **cert-manager, Metrics Server, EBS CSI** | `kops-repo/README.md` 애드온 | [사실] ALB 컨트롤러 의존(cert-manager), HPA 지원(Metrics Server), PV(EBS) | — (사실상 표준 애드온) | ★2 (설치만) | — |
| **CloudFront + S3 + WAF** | `infra-iac/modules/cloudfront`, `waf`, `docs/s3-frontend-deploy.md` | [사실] 프론트엔드 정적 호스팅 + 캐싱 + 웹 방화벽 | Vercel/Netlify, S3 단독, Nginx 파드 | ★2 | — |

### 2-2. 서버리스 런타임 (이 팀의 핵심)

| 기술 | 어디서 확인 [사실] | 왜 썼나 | 대안 | 난이도 | 비유 [추정] |
|---|---|---|---|---|---|
| **WebAssembly + Spin** (Fermyon Spin, Python SDK) | `poc-wasm-spin/python-spin-test/spin.toml`, `web-faas-builder/src/services/build.py`(`spin build`) | [사실, README 주장] 컨테이너 레이어 제거로 콜드스타트 단축, 메모리 샌드박싱으로 Container Escape 위험 감소. [없음] 기동 시간 측정 데이터는 레포에 없음 | 컨테이너 기반 FaaS(**Knative**, **OpenFaaS**, Fission), microVM(**Firecracker**, AWS Lambda 방식), gVisor, wasmCloud, WasmEdge | ★3 (개념) / ★4 (Python→WASM 제약: 네이티브 확장 패키지 사용 불가 등 [추정]) | JVM 바이트코드처럼 "어디서나 도는 이식 가능한 바이너리 + 샌드박스" |
| **SpinKube** (spin-operator v0.6.1 + containerd-shim-spin v0.22.0 + RuntimeClass, kwasm) | `poc-wasm-spin/INSTALL.md`, `kops-repo/kwasm-annotator.yaml`, SpinApp 매니페스트(`executor: containerd-shim-spin`) | [사실] K8s에서 WASM을 "파드처럼" 스케줄링·스케일. SpinApp CRD 하나로 Deployment+Service 자동 생성. [공식] SpinKube는 Fermyon이 CNCF에 기여, 현재 `spinframework` 조직에서 관리 | Knative Serving(컨테이너, scale-to-zero 내장), runwasi 기반 다른 shim(WasmEdge 등), K8s 밖에서 Spin 직접 실행 | ★4 (CRD/오퍼레이터, containerd 런타임 설정) | Spring Boot Starter처럼 "CRD 하나 쓰면 오퍼레이터가 알아서 리소스 생성" |
| **mypy** (코드 검증) | `web-faas-builder/src/services/validation.py` | [사실] 빌드 전 타입 검사로 실패를 앞당김 | ruff, pylint, 샌드박스 사전 실행 | ★1 | 컴파일 단계 타입 체크 |
| **OCI 레지스트리 = ECR** | `infra-iac/modules/ecr`(faas-builder, faas-app 레포), `push.py` | [사실] WASM 아티팩트를 컨테이너 이미지처럼 OCI로 배포. POC는 Docker Hub | GHCR, Harbor(온프렘), Docker Hub | ★2 | Maven 저장소에 jar 올리기 |
| **HPA** (CPU/메모리) | `web-faas-builder/k8s/hpa.yaml`, `manifest.py`의 `enableAutoscaling` | [사실] CPU 70%/메모리 80% 기준. [사실] README 로드맵에서 "CPU 기반 HPA → **KEDA**로 요청량 기반 0→N" 을 **미구현 과제로 명시** | **KEDA**(이벤트·요청량 기반, scale-to-zero), Knative KPA | HPA ★2, KEDA ★3 | — |

### 2-3. 애플리케이션 / 데이터

| 기술 | 어디서 확인 [사실] | 왜 썼나 | 대안 | 난이도 |
|---|---|---|---|---|
| **Python + FastAPI** | `web-faas-builder`, `web-backend/backend` | [추정] 함수 런타임이 Python(Spin Python SDK)이라 빌더도 Python으로 통일, 비동기 I/O, 자동 OpenAPI 문서(`/docs`) | **Spring Boot**(학습자 주력), Go(Gin), Node(Nest) | Spring 경험자에게 ★1~2 |
| **DynamoDB (single-table) + S3** | `web-backend/backend/README.md`, `web-faas-builder/src/services/dynamodb.py`, `s3_storage.py` | [사실] 함수 메타데이터·빌드 작업 상태·실행 이력 저장, 소스/아티팩트는 S3. [추정] 서버리스 서사에 맞는 서버리스 DB, 운영 부담 0 | RDS(PostgreSQL), K8s 위 DB, Redis | ★2 (single-table 모델링은 ★3) |
| **subprocess로 CLI 호출** (`spin`, `kubectl`) | `deploy.py`, `scaffold.py`, 백엔드의 `kubectl delete spinapp` | [사실] K8s 클라이언트 라이브러리 대신 CLI를 감싸 빠르게 구현. [추정] 해커톤 속도 우선의 트레이드오프 | Kubernetes 공식 클라이언트(Python/Java fabric8), 오퍼레이터 직접 작성 | ★1 |
| **React + Vite + shadcn/ui + Monaco** | `2025softbank-hackathon-final/package.json` | [사실] 브라우저 코드 에디터(Monaco)로 함수 작성, Recharts로 메트릭 차트, i18n(react-i18next — 일본어 대응 [추정]) | Next.js, Vue | ★2 |

### 2-4. CI/CD

| 기술 | 어디서 확인 [사실] | 왜 썼나 | 대안 | 난이도 |
|---|---|---|---|---|
| **GitHub Actions** | `web-backend/.github/workflows/back-deploy.yml`, `front-deploy.yml`, `web-faas-builder/.github/workflows/ecr-build.yaml` | [사실] Docker Buildx로 **amd64+arm64 멀티 아키텍처** 이미지를 ECR에 푸시(태그: latest + 버전-KST타임스탬프) | GitLab CI, Jenkins, AWS CodeBuild | ★2 |
| **ArgoCD** | `.github/profile/README.md` 배지, `web-backend/backend/README.md` ("Production API — ArgoCD 기준 레퍼런스 환경", "Infra: AWS EKS + ALB + ArgoCD") | [사실] 언급은 있음. [없음] **Application 매니페스트, Argo 설정 파일은 8개 레포 어디에도 없음.** [추정] 플랫폼 자체(백엔드/빌더)의 Helm·Kustomize 배포에 ArgoCD를 클러스터에서 수동 등록해 썼고, **사용자 함수 배포는 ArgoCD가 아니라 빌더의 `kubectl apply`** 경로 | **Flux**, Helm + `kubectl` 직접, Argo Rollouts(카나리) | ★3 (설치·UI는 ★2, App-of-Apps·sync 정책·시크릿 관리가 본체) |
| **Helm / Kustomize** | `helm-charts/`, `web-backend/web-backend-platform/`, `web-faas-builder/k8s/kustomization.yaml` | [사실] 백엔드는 Helm, 빌더는 Kustomize — 팀 내 통일 안 됨 | 둘 중 하나로 통일, Jsonnet, cdk8s | Helm ★2, Kustomize ★2 |

> 참고 [사실]: 백엔드 README와 빌더 `k8s/README.md`는 "EKS", `eksctl`을 언급하지만 실제 클러스터는 kOps다. 문서가 클러스터 전환(K3s→kOps)을 다 따라가지 못한 흔적으로 보임 [추정]. 마찬가지로 kOps README는 "ARM64(Graviton2) 40% 절감"을 이유로 들지만 실제 ARM은 컨트롤 플레인(t4g.medium) 1대뿐이고 워커는 전부 x86(t3a/c5/c6i/c7i)이다 [사실, `cluster.yaml`]. [추정] shim/이미지 아키텍처 호환 문제로 워커를 x86으로 돌렸을 가능성.

### 2-5. 관측 (Monitoring & Observability)

| 기술 | 어디서 확인 [사실] | 왜 썼나 | 대안 | 난이도 |
|---|---|---|---|---|
| **Prometheus** (kube-prometheus-stack) | `web-backend/backend/app/config.py`, `routers/metrics.py` | [사실] 백엔드가 PromQL `sum(rate(container_cpu_usage_seconds_total{...}[1m]))`로 **함수별 CPU 사용량**(instant + 60분 range)을 질의해 UI에 노출 | Amazon Managed Prometheus, VictoriaMetrics, Datadog | ★3 (PromQL, 라벨 설계) |
| **Grafana** | 프로필 README 배지 | [사실] 대시보드. [없음] 대시보드 JSON은 레포에 없음 | Prometheus UI, 자체 UI(이 팀은 프론트에서 Recharts로도 표시) | ★2 |
| **Loki + Promtail** | `config.py`: `loki-stack.logging.svc`, `routers/logs.py` | [사실] `function_id` 라벨로 함수별 로그 조회. 실행 이력은 별도로 DynamoDB에 저장 | ELK/OpenSearch, CloudWatch Logs, **Grafana Alloy**(Promtail 후속) | ★3 |
| **(로드맵) OpenTelemetry + Tempo** | 프로필 README Future Roadmap | [사실] **미구현**, 분산 트레이싱을 다음 과제로 제시 | Jaeger, Zipkin | ★3 |

> [공식] **Promtail은 2025-02-13부터 LTS, 2026-03-02 EOL** — Grafana는 Grafana Alloy로의 이전을 안내. 올해 새로 구성한다면 Promtail 대신 **Alloy**를 쓰는 것이 맞다. (출처: [Grafana Loki 3.4 블로그, 2025-02-14](https://grafana.com/blog/grafana-loki-3-4-standardized-storage-config-sizing-guidance-and-promtail-merging-into-alloy/))

---

## 3. "왜 이 조합이었나" — 설계 결정의 연결고리 [추정]

```
문제 정의: 기존 FaaS = 콜드스타트 느림 + 컨테이너 탈출 위험
   └─> 기술 선택: WASM(Spin) — 메모리 할당만으로 기동, 샌드박스 격리
         └─> 실행 기반: SpinKube — K8s에서 WASM을 파드처럼 다룸
               └─> 노드 containerd에 shim 설치 필요 → 노드를 직접 제어하는 Self-managed K8s(kOps)
                     └─> Stateless 실행이므로 Spot 노드 그룹 → Cluster Autoscaler
                     └─> 빌드/관측은 taint로 분리 → 실행 노드 보호
               └─> 함수별 메트릭·로그 → Prometheus/Loki를 플랫폼 API가 직접 질의
```

심사위원 관점에서 "하나의 문제 정의가 런타임 → 클러스터 → 노드 전략 → 관측까지 일관된다"는 점이 설득력이었을 것으로 추정한다. 반대로 **약점**(우리가 넘어설 지점)은:

1. 성능 주장에 **측정 근거 없음** (콜드스타트 ms, p99, 동시성 등)
2. **scale-to-zero 미구현** — 서버리스의 핵심인데 CPU HPA에 머묾 (KEDA는 로드맵)
3. ArgoCD는 배지 수준, **GitOps 선언 파일 부재**
4. 문서와 실제 인프라 불일치 (EKS 표기, ARM 주장)

---

## 4. 학습 우선순위 제안 (이 문서 범위의 결론) [추정]

학습자 전제(Java/Spring, 인프라 0)에서 **"작년 스택을 그대로 재현"** 보다 **"각 층에서 하나씩 직접 띄우고 숫자를 재보는 것"** 이 본선 대비로 효율적이라고 판단한다. (상세 4주 계획은 5번 갭 분석 스레드 소관)

| 순서 | 무엇을 | 왜 | 대체 가능한 저비용 실습 |
|---|---|---|---|
| 1 | Docker → K8s 기초 (Deployment/Service/Ingress/HPA, taint·toleration) | 모든 층의 공통 언어 | 로컬 **kind** 또는 **k3d**(비용 0) |
| 2 | Terraform 기본 (plan/apply/state, VPC·EC2 모듈) | 예선 피드백 "인프라 고유 기능 확장"에 직결 | LocalStack 또는 `terraform plan`까지만 (apply는 학습자 승인 후) |
| 3 | Prometheus + Grafana + PromQL | "실측 숫자"를 만드는 도구 | kube-prometheus-stack을 kind에 설치 |
| 4 | 서버리스 런타임 비교 실험: Knative(컨테이너) vs SpinKube(WASM) 콜드스타트 | 작년 팀이 **안 한** 측정을 우리가 하는 것 | kind 위 SpinKube 퀵스타트 + `hey`/`k6`로 측정 |
| 5 | GitOps (ArgoCD 또는 Flux) 실제 App 선언 | 배포 파이프라인 주제 대비 | kind에 ArgoCD 설치 후 Helm 차트 sync |
| 6 | KEDA scale-to-zero | 작년 로드맵 = 올해 기본기일 가능성 | KEDA HTTP add-on 또는 Prometheus scaler |
| 후순위 | kOps, Cilium 심화, IRSA | 클라우드 비용·디버깅 난이도 높음. 개념 설명 가능 수준이면 충분 | — |

---

## 5. 출처

**레포 (사실의 근거)**
- https://github.com/sh-final-blue/.github (profile/README.md)
- https://github.com/sh-final-blue/infra-iac
- https://github.com/sh-final-blue/kops-repo
- https://github.com/sh-final-blue/poc-wasm-spin
- https://github.com/sh-final-blue/web-faas-builder
- https://github.com/sh-final-blue/web-backend
- https://github.com/sh-final-blue/helm-charts
- https://github.com/sh-final-blue/2025softbank-hackathon-final

**공식 출처**
- Promtail 지원 종료 일정: https://grafana.com/blog/grafana-loki-3-4-standardized-storage-config-sizing-guidance-and-promtail-merging-into-alloy/
- spin-operator (SpinKube): https://github.com/spinframework/spin-operator/
- kOps: https://kops.sigs.k8s.io/
- SpinKube: https://www.spinkube.dev/

**한계 / 확인 못 한 것**
- [없음] 심사위원 코멘트, 발표 자료 원본, 실제 측정 데이터.
- [없음] K3s→kOps 전환 사유, ArgoCD 실제 구성.
- 이 환경에서는 공식 문서 사이트 직접 접속이 막혀 있어, 대안 기술 설명과 난이도는 일반 업계 지식 기반 **[추정]** 이다. 위 공식 링크 중 Promtail 일정만 본문을 직접 확인했다.
