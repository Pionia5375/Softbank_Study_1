로드맵 위치: 본선 D-10 (10/28~10/30, 주제 공개 전) / 주제와 무관하게 미리 해 둘 수 있는 인프라 준비 / 본선 연결점: 킥오프 다음 날 첫 1시간 안에 "클러스터 + GitOps + 모니터링"이 서 있게, 그리고 설계 논의에서 대안·트레이드오프를 입으로 말할 수 있게 (완성도·데모 30, 클라우드 활용 30, 팀 개발 20)

# 주제 공개 전 인프라 준비 팩

주제는 10/30(금) 20:00 킥오프에서 나온다【사용자】. 그 전에는 "무엇을 만들지"는 못 정하지만, **어떤 주제가 나와도 똑같이 필요한 바닥**은 정해져 있다.

- 쿠버네티스 클러스터를 **몇 분 안에, 매번 같은 모양으로** 세우는 손
- 그 위에 **Git 에서 자동으로 앱이 올라오는 길**(Argo CD)
- **숫자를 보여 주는 화면**(Prometheus + Grafana) 과 **알림 하나**
- 각 부품을 **왜 그렇게 골랐는지** 30초 안에 말하는 입

이 폴더는 그 네 가지만 다룬다. 주제가 나온 뒤에 할 일(아키텍처, 기능·API 명세)은 여기 없다.

> 레포 현황【사실, 10/28 `git log` 와 `results/` 폴더 기준】: `labs/01~05` 는 측정값까지 있고, `labs/06`(관측)·`labs/07`(Terraform)·`poc/01~07` 은 코드는 다 있지만 `results/` 가 비어 있다. 즉 **관측 스택과 PoC 전체 실행은 아직 맥에서 한 번도 안 돌았다.** 그래서 이 팩의 우선순위는 "새 걸 더 만들기" 가 아니라 **"이미 있는 걸 손으로 한 번 끝까지 돌려서 시간을 재기"** 다.

## 1. 우선순위 목록

시간은 처음 하는 사람 기준 【추정】. 맥 메모리는 Docker Desktop 에 10GB 이상 잡혀 있어야 한다 (`docker info --format '{{.MemTotal}}'`).

| 순위 | 할 일 | 1일차(10/31)에 어떻게 도움 되나 | 시간 | 문서 |
|---|---|---|---|---|
| **P0-1** | 도구 점검 + `Brewfile` | 팀원 맥에 같은 도구를 10분 안에 맞춘다. "환경은 이걸로 통일하자" 를 1일차 첫 10분에 꺼낼 수 있다 | 20분 | `scripts/preflight.sh`, `Brewfile` |
| **P0-2** | kind 부팅 원리 읽기 + **30분 드릴 1회** (스크립트를 한 줄씩 읽고 돌린다) | 주제가 뭐든 첫 산출물은 "클러스터가 서 있고 Git 에서 앱이 올라오고 그래프가 보인다" 다. 이걸 손이 외우고 있어야 설계 논의에 머리를 쓸 수 있다 | 읽기 40분 + 1회차 90분 | [01-cluster-boot.md](01-cluster-boot.md) 1~2절, [02-drill-30min.md](02-drill-30min.md) |
| **P0-3** | 드릴 2·3회차 (목표: 30분 안) | 2회차부터는 "어디서 시간이 새나" 가 보인다. 그 숫자가 설계 문서의 첫 측정값이 된다 | 회당 30~40분 | [02-drill-30min.md](02-drill-30min.md) 6절 |
| **P0-4** | **k3s 를 VM 2대에 손으로 한 번** (multipass) + k3d 15분 | 작년 우승팀은 EC2 위에 직접 k8s, 예선 부산 우승팀도 k3s 였다【사실, notes/research/career/03】. 본선에서 EC2 + k3s 로 갈 확률이 높고, `poc/07` 의 user_data 가 바로 이 명령이다. 서버 1대 + 에이전트 1대를 토큰으로 묶어 본 사람과 아닌 사람은 1일차 발언 무게가 다르다 | 90분 + 15분 | [01-cluster-boot.md](01-cluster-boot.md) 3~4절, `scripts/k3s-multipass.sh`, `scripts/k3d-boot.sh` |
| **P1-1** | 모니터링 기본: 골든 시그널 4개 · SLO 1개 · 알림 1개를 **드릴 클러스터에서 실제로 울려 본다** | 작년 본선 참가자들이 공통으로 약했던 게 모니터링【사용자, 10/28 내정자 조언】. "에러율 5% 넘으면 1분 뒤 알림" 을 실제로 울려 본 사람은 데모 때 숫자로 말한다 | 90분 | [03-monitoring-basics.md](03-monitoring-basics.md) |
| **P1-2** | "왜 이렇게 설계했나" 1페이지 읽고, 스택마다 **30초씩 소리 내어 말해 보기** | 1일차 아키텍처 논의에서 "Argo CD 말고 Flux 는?" "gVisor 는 왜?" 가 나온다. 대안·버린 이유·트레이드오프를 한 줄씩 들고 가면 리드 역할이 자연스럽다 (팀 개발 20점의 "대안 문서화" 가 이것) | 90분 | [04-why-designed-this-way.md](04-why-designed-this-way.md) |
| **P2-1** | `poc/run-all.sh` 전체 1회 (FaaS 참조 아키텍처: Cilium + Argo CD + Knative + gVisor + 컨트롤 플레인) | 이미 만들어 둔 참조 아키텍처를 **본 적이 있어야** 주제가 비슷할 때 30% 만 고쳐 쓴다. 단, 메모리 10GB·2시간이 든다. 시간이 남을 때만 | 2시간 | `poc/RUN-ALL.md` |
| **P2-2** | EKS 는 **읽기만** (생성 금지) | 팀원이 "EKS 로 가자" 할 때 비용·시간·운영 부담을 말할 수 있으면 된다. 지금 만들어 볼 필요는 없다 | 30분 | [01-cluster-boot.md](01-cluster-boot.md) 5절 |
| **P3** | kubeconfig 컨텍스트 정리 습관, 디스크 정리 | 1일차에 클러스터가 셋(kind, k3s, 팀 공용)이 되면 `kubectl` 이 어디를 보는지 헷갈려서 사고가 난다 | 20분 | [01-cluster-boot.md](01-cluster-boot.md) 6절 |

합계 약 13시간 【추정】. 10/28 저녁 + 10/29 + 10/30 낮 = 쓸 수 있는 시간 약 18시간이니, 다른 스레드 산출물(노션·GitHub 규칙·일정·첫 회의 안건) 검토 시간을 빼도 들어간다.

## 2. 3일 배치 (제안)

**10/28 (화) 저녁, 약 4시간**
- P0-1 도구 점검 (20분) → `preflight.sh` 출력 붙여 보내기
- P0-2 [01-cluster-boot.md](01-cluster-boot.md) 1~2절 읽기 (40분)
- P0-2 드릴 1회차: [02-drill-30min.md](02-drill-30min.md) 대로 **스크립트와 YAML 을 먼저 한 줄씩 읽고** 돌린다 (90분). 마지막 표를 `results/drill.md` 에 적고 붙여 보내기
- 남으면 [03-monitoring-basics.md](03-monitoring-basics.md) 1절(골든 시그널)만 읽기

**10/29 (수), 약 10시간**
- 오전: 드릴 2회차 (40분) → P0-4 k3s multipass 손으로 (90분) → k3d (15분)
- 오후: P1-1 모니터링 (90분, 알림 울리기까지) → P1-2 설계 이유 읽기 + 말하기 (90분)
- 저녁: P2-1 `poc/run-all.sh` (시간·메모리 되면) 또는 드릴 3회차 + 셀프 연습

**10/30 (목) 낮, 약 7시간 (20:00 킥오프)**
- 오전: 드릴 3회차 타임어택 (30분 목표) → P2-2 EKS 읽기 (30분) → P3 정리 (20분)
- 오후: 다른 스레드 산출물 검토(노션 구조, GitHub 규칙, 일정표, 첫 회의 안건), 킥오프 때 할 말 정리
- 19:30 전: 맥 재부팅, Docker 메모리 확인, 드릴 클러스터는 지워 두기 (킥오프 때 화면 공유할 수 있게 가볍게)

## 3. 폴더 지도

```
starter-pack/infra-prep/
├── README.md                     ← 지금 이 파일 (우선순위·일정·검증)
├── 01-cluster-boot.md            kind / k3d / k3s / EKS 가 각각 어떻게 "부팅" 되나, 뭘 연습할까
├── 02-drill-30min.md             30분 셋업 드릴 안내 (스크립트 줄 단위 설명, 회차 기록표)
├── 03-monitoring-basics.md       골든 시그널 4개 · SLO 1개 · 알림 1개 (실제로 울려 보기)
├── 04-why-designed-this-way.md   스택별 "왜 이렇게 설계했나" 1페이지 (대안 / 이유 / 트레이드오프)
├── Brewfile                      brew bundle 로 팀원 도구 통일
├── cluster/kind-config.yaml      드릴용 kind 설정 (control-plane 1 + worker 2, 맥 9898 → podinfo)
├── monitoring/kps-values.yaml    kube-prometheus-stack 다이어트 값
├── gitops/
│   ├── root.yaml                 App of Apps 뿌리 (이 폴더의 apps/ 를 가리킨다)
│   ├── apps/podinfo.yaml         샘플 앱 (Helm 차트, ServiceMonitor 켬, NodePort)
│   ├── apps/monitoring-rules.yaml  아래 monitoring/ 폴더를 올리는 Application
│   └── monitoring/               PrometheusRule(알림 1개) + Grafana 대시보드 ConfigMap
├── scripts/
│   ├── preflight.sh              도구·버전·Docker 메모리 점검
│   ├── drill-30.sh               드릴 본체: kind → Argo CD → Prometheus/Grafana → root → curl 200, 단계별 시간
│   ├── ports.sh                  Argo CD · Grafana · Prometheus port-forward 한 번에
│   ├── k3d-boot.sh               k3s 를 Docker 안에서 (빠른 길)
│   └── k3s-multipass.sh          k3s 를 VM 2대에 (진짜 노드 2대, poc/07 과 같은 명령)
└── results/                      회차 기록 (drill.md 는 커밋, *.log 는 git 제외)
```

## 4. 금지·주의

- **AWS 리소스 생성, `terraform apply` 는 이 팩에 없다.** EKS 는 읽기만. (프로젝트 규칙)
- 드릴 클러스터 이름은 `prep`, k3d 는 `prep-k3d`, multipass VM 은 `k3s-server`/`k3s-agent`. 기존 `faas`, `lab05` 클러스터와 겹치지 않는다. 다만 **동시에 띄우면 메모리가 모자란다.** 하나 끝내고 지우고 다음.
- 맥 포트: 드릴은 9898(podinfo) 만 고정으로 쓴다. Argo CD 8080, Grafana 3000, Prometheus 9090 은 `scripts/ports.sh` 가 port-forward 할 때만 쓴다.

## 5. 핵심 결정 3개 (+대안)

자세한 기록: [decisions/2026-10-28.md](../../decisions/2026-10-28.md)

1. **연습 클러스터는 kind 를 주로, k3s 는 multipass VM 2대로 한 번.** 대안: k3s 만 / EKS 를 미리 만들어 보기. 이유: kind 는 이미 Lab 02~05 로 손에 익고 메모리가 가장 싸다. k3s 는 "진짜 노드 2대를 토큰으로 묶는" 경험이 `poc/07` 과 본선 EC2 시나리오에 직결된다. EKS 는 생성에 15~20분 + 시간당 과금이라 지금 손으로 익힐 이득이 적다.
2. **드릴의 관측 스택은 kube-prometheus-stack 한 차트.** 대안: `poc/02` 처럼 Prometheus 단독 차트 + Grafana 따로. 이유: ServiceMonitor·PrometheusRule 을 YAML 로 Git 에 두고 Argo CD 가 올리게 하려면 Operator 가 필요하다. 한 차트가 10분 더 무겁지만(【추정】 메모리 +600MB) "알림 규칙도 GitOps" 가 된다.
3. **샘플 앱은 podinfo.** 대안: 예선 앱 / `labs/01` hello. 이유: `/metrics` 에 요청 지연 히스토그램이 이미 있고 `/status/500`, `/delay/N` 으로 장애를 일부러 낼 수 있어서 골든 시그널·알림 실험에 앱 코드를 안 고쳐도 된다.

## 6. 셀프 연습 1개

드릴 3회차가 끝나면: `gitops/apps/podinfo.yaml` 의 `replicaCount` 를 2 → 3 으로 바꿔 `git push` 하고, Argo CD 가 알아채서 파드가 3개가 될 때까지 몇 초 걸리는지 잰다 (`kubectl -n podinfo get pods -w` 와 시계). 그 숫자가 `poc/01` README 에서 묻던 "polling 120s+jitter 60s 의 체감" 이다. 더 빠르게 하려면 뭘 바꿔야 하는지 [04-why-designed-this-way.md](04-why-designed-this-way.md) Argo CD 절을 보고 한 줄로 적는다.

## 7. 검증 명령과 기대 출력

```bash
# 레포 루트에서
starter-pack/infra-prep/scripts/preflight.sh
#   ok  docker 28.x / ok kind 0.3x / ok kubectl / ok helm / ok multipass / ok k3d ... 마지막 줄 "준비 완료"

starter-pack/infra-prep/scripts/drill-30.sh
#   [..s] 1/5 kind 클러스터 prep  →  [..s] 5/5 curl localhost:9898 → 200
#   마지막에 "단계별 시간" 표, 총 시간 (목표 1800s 이하)

kubectl -n argocd get applications
#   root / podinfo / monitoring-rules 모두 Synced  Healthy

curl -s localhost:9898 | head -3
#   {"hostname":"podinfo-...","version":"6.17.0", ...

kubectl -n monitoring get prometheusrule podinfo-slo
#   NAME          AGE
#   podinfo-slo   ...
```
