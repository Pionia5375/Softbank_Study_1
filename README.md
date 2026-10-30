<!-- 로드맵 위치: 4주차 / 레포 입구 정리 / 본선 연결점: 팀원·운영진이 처음 보는 화면에서 "무엇을 직접 돌려 보고 숫자로 남겼는지"가 바로 보이게 -->

# Softbank Study 1 — Cloud-native infra, learned by building

> Backend developer (Java/Spring) moving into cloud infrastructure. Hands-on labs and a FaaS platform PoC on Kubernetes, built toward the **SoftBank Hackathon 2026 finals (Nov 7–8, Seoul)**.
>
> Java/Spring 백엔드 개발자가 클라우드 인프라를 손으로 만들며 배운 기록. 설계 결정은 "대안 · 트레이드오프 · 실측 숫자"로 남긴다.

**Stack:** Docker · Kubernetes (kind, k3s) · Helm · Argo CD · Argo Rollouts · Knative · Cilium/Hubble · gVisor · Prometheus/Grafana/Loki · k6 · Terraform · AWS EC2

---

## 숫자로 남긴 것 (Labs, 직접 측정)

| 실험 | 결과 | 기록 |
|---|---|---|
| Spring Boot 이미지: single-stage vs multi-stage | 294.0 MB → **129.8 MB**, 코드 수정 후 재빌드 24.1 s → **9.2 s** | [Lab 01](labs/01-docker-basics/README.md) |
| 롤아웃 중 실패 요청: probe 없음 vs readiness probe | **51% → 3%** (롤아웃 시간 3 s → 12 s를 내준 대가) | [Lab 03](labs/03-k8s-probes/README.md) |
| 잘못된 배포 되돌리기 (`helm rollback`) | 명령 **0.25 s**, 서비스 중단 0 | [Lab 04](labs/04-k8s-rollout-hpa/README.md) |
| 노드 3대에서 PriorityClass 선점 | replicas 5 적용 → 5개 Running **35 s** | [Lab 05](labs/05-k8s-scheduling/README.md) |

측정 조건과 반복 횟수는 각 Lab README의 표에 있다. 1회 측정인 값은 그렇게 적어 두었다.

## Labs — 기초를 하나씩

| # | 주제 | 핵심 질문 |
|---|---|---|
| [01](labs/01-docker-basics/) | Docker 이미지 | 이미지를 작게, 재빌드를 빠르게 하려면? |
| [02](labs/02-k8s-basics/) | kind · Deployment · Service · Ingress · Helm | 컨테이너를 클러스터에 올리는 최소 단위는? |
| [03](labs/03-k8s-probes/) | probe · resources | Pod 교체 중 요청이 끊기지 않으려면? |
| [04](labs/04-k8s-rollout-hpa/) | preStop · 롤아웃/롤백 · HPA | 무중단 배포와 자동 확장은 어떻게 맞물리나? |
| [05](labs/05-k8s-scheduling/) | taint · nodeSelector · PriorityClass | "어디에 띄울지"를 누가, 무엇으로 정하나? |
| [06](labs/06-observability-k6/) | Prometheus · Loki · Grafana · k6 | 성능 주장을 p95로 증명하려면? |
| [07](labs/07-terraform-kind/) | Terraform | 같은 환경을 명령 한 줄로 다시 세우려면? |

## FaaS Platform PoC — 단계별로 쌓은 서버리스 플랫폼

"코드를 올리면 몇 초 뒤 URL이 나오는" 함수 플랫폼을 7단계로 쌓았다. 한 번에 올리기: [`poc/RUN-ALL.md`](poc/RUN-ALL.md) · 구조와 요청 흐름 분석: [`poc/ANALYSIS.md`](poc/ANALYSIS.md)

| 단계 | 내용 |
|---|---|
| [01 GitOps](poc/01-argocd/) | Argo CD App of Apps로 `git push` → 클러스터 반영 |
| [02 Progressive delivery](poc/02-rollouts/) | Argo Rollouts 카나리 + Prometheus 지표로 자동 롤백 |
| [03 Multi-tenancy](poc/03-tenant-isolation/) | Namespace · Quota · LimitRange · NetworkPolicy(Cilium) · RBAC · AppProject 6겹 격리 |
| [04 FaaS runtime](poc/04-faas-runtime/) | 노드 풀 분리, 클러스터 안 빌드(kaniko), Knative 0↔N, gVisor 샌드박스 |
| [05 Control plane + AI ops](poc/05-control-plane-mcp/) | 함수 배포 API + 운영 에이전트용 MCP 도구 (사람이 승인하는 구조) |
| [06 Fault injection](poc/06-fault-injection/) | 노드 장애·나쁜 배포·옆집 폭주를 일부러 일으키고 감지→복구 시간 재기, 런북 |
| [07 AWS](poc/07-ec2-k3s/) | EC2(온디맨드 + 스팟) 위 k3s로 이전, Terraform |

PoC는 AI 페어(Claude Code)와 함께 작성했고, 각 단계의 `results/`에 실측을 채워 가는 중이다. 단계별 해설: [`docs/guide/`](docs/guide/index.html)

## 결정 기록 · 노트

- [`decisions/`](decisions/) — 날짜별 결정 로그: 선택 / 버린 대안 / 이유 / 측정값
- [`notes/research/`](notes/research/) — 작년 본선 분석, 심사 기준, 기술 지도, KubeElasti vs Knative 비교 등
- [`notes/cka/`](notes/cka/) — CKA 대비 정리 (네트워킹)
- [`starter-pack/`](starter-pack/) — 본선 팀용 준비물: GitHub 운영 전략, Notion 구조, 일정안, 인프라 셋업 드릴

## 이 레포의 규칙

- 설계 결정은 항상 **대안과 버린 이유**를 같이 적는다.
- 성능·시간 주장은 **숫자**로 남긴다. 가능하면 3~5회 반복.
- 사실과 추측을 구분한다: 【사실】(출처) 【추정】 【미확인】.

## 핵심 결정 3개

1. **로컬은 kind, 클라우드는 EC2 위 k3s** — 대안: EKS(컨트롤 플레인 시간당 $0.10 추가, 생성이 길다), kubeadm(설치 단계가 많아 당일 시간을 다 쓴다). 근거: [`poc/07-ec2-k3s/README.md`](poc/07-ec2-k3s/README.md) 결정 1.
2. **배포는 Argo CD가 Git에서 당겨 온다(pull)** — 대안: CI에서 `kubectl apply`(push). 버린 이유: 클러스터 자격 증명을 CI에 두지 않고, Git이 곧 현재 상태가 된다.
3. **서버리스 런타임은 Knative 유지** — 대안: KubeElasti. 근거: [`notes/research/09-kubeelasti-vs-knative.md`](notes/research/09-kubeelasti-vs-knative.md)

<sub>셀프 연습: 아무 Lab 하나를 골라 README의 측정을 3회 반복해 표의 1회 값을 평균 ± 범위로 바꿔 본다. · 검증: `ls labs poc decisions` → 위 표의 폴더가 모두 보이면 링크가 맞다.</sub>
