로드맵 위치: 본선 D-10 / 30분 셋업 드릴: 빈 맥 → 클러스터 + GitOps + 모니터링 + 샘플 앱 / 본선 연결점: 킥오프 다음 날 첫 1시간에 팀 공용 바닥을 세우는 사람이 된다 (완성도·데모 30)

# 02. 30분 셋업 드릴

드릴 = 같은 순서를 시간 재며 반복해서, 생각 없이도 손이 하게 만드는 것. 프로젝트 게이트 "11/1 셋업 드릴 30분" 이 이것이다.

끝나면 이렇게 되어 있다:
- kind 클러스터 `prep` (노드 3개)
- Argo CD 가 떠 있고, **이 레포의 `starter-pack/infra-prep/gitops/`** 를 보고 있다
- Prometheus + Grafana 가 떠 있고, podinfo 지표를 긁고 있다
- podinfo 2개가 `http://localhost:9898` 로 응답한다
- 알림 규칙 1개(`PodinfoHighErrorRate`)가 Prometheus 에 들어가 있다
- 단계별 시간 표 1장

---

## 1. 무엇이 어떻게 이어지나 (0부터)

```
맥
 ├ kind ─────────── Docker 컨테이너 3개 = 노드 3개 (cluster/kind-config.yaml)
 │                    맥 9898 ──→ 노드 31198 (NodePort) ──→ podinfo 파드
 ├ helm ──────────► argocd 네임스페이스: Argo CD (poc/01 values)
 ├ helm ──────────► monitoring 네임스페이스: Operator + Prometheus + Grafana + kube-state-metrics + node-exporter
 └ kubectl apply ─► root Application (gitops/root.yaml)
                        │  Argo CD 가 GitHub 의 gitops/apps/ 를 읽는다
                        ├─► podinfo Application ──► Helm 저장소에서 podinfo 차트 ──► podinfo 네임스페이스에 파드 2개 + Service + ServiceMonitor
                        └─► monitoring-rules Application ──► gitops/monitoring/ 의 PrometheusRule + 대시보드 ConfigMap
                                                                    │                      │
                                           Operator 가 보고 Prometheus 설정에 넣음     Grafana 사이드카가 보고 대시보드로 올림
```

두 가지 설치 방식이 섞여 있는 이유:
- **helm 으로 직접**(Argo CD, 모니터링 스택): "플랫폼 바닥" 이고 CRD 가 커서, Argo CD 자기 자신을 Argo CD 로 올리는 건 드릴에선 과하다. 【대안】 `poc/07` 처럼 Argo CD 가 kube-prometheus-stack 도 올리게 할 수 있다(App of Apps 에 추가). 그러면 "전부 Git" 이 되지만 CRD 동기화 옵션(`ServerSideApply`, `Replace`)을 알아야 한다. 본선에서 시간이 있으면 그쪽으로.
- **Argo CD 로**(앱, 알림 규칙, 대시보드): 자주 바뀌는 것. push 하면 따라온다.

## 2. 먼저 읽기 (1회차에만, 20분)

아래 순서로 열어서 **주석을 위에서 아래로** 읽는다. 명령은 아직 치지 않는다.

1. `cluster/kind-config.yaml` — 노드 3개, 포트 매핑 1개. 질문: 왜 컨트롤 플레인에만 포트를 매핑해도 워커의 파드에 닿나?
2. `scripts/drill-30.sh` — 5단계. 각 단계의 첫 명령이 뭘 하는지 한 줄씩 아래 3절과 맞춰 본다.
3. `gitops/root.yaml` → `gitops/apps/podinfo.yaml` → `gitops/apps/monitoring-rules.yaml` — Application 3개의 `source` 와 `destination` 만 본다.
4. `monitoring/kps-values.yaml` — `*NilUsesHelmValues: false` 3줄이 왜 핵심인지.
5. `gitops/monitoring/podinfo-rules.yaml` — 알림 1개. 식은 03 문서에서 다시 본다.

## 3. 스크립트 줄 단위 설명

### 0/5 점검
`docker info --format '{{.MemTotal}}'` — Docker Desktop 에 잡힌 메모리. 이 드릴은 다 뜨면 약 4~6GB 【추정】 를 쓴다.

### 1/5 kind
- `kind delete cluster --name prep` — 이전 회차가 남아 있으면 지운다. **매번 빈 상태에서 시작해야 시간이 비교된다.**
- `kind create cluster --config cluster/kind-config.yaml` — 컨테이너 3개 → kubeadm init/join → kindnet → kubeconfig 에 `kind-prep` 컨텍스트 (01 문서 2절)
- `kubectl wait --for=condition=Ready nodes --all --timeout=180s` — 노드 3개가 Ready 될 때까지 기다린다. CNI 가 깔려야 Ready 가 된다.

### 2/5 Argo CD
- `helm repo add argo https://argoproj.github.io/argo-helm` — 차트 저장소 등록 (한 번만, `|| true` 로 이미 있어도 통과)
- `helm repo update argo` — 저장소 목록 새로고침
- `helm upgrade --install argocd argo/argo-cd --version 10.10.5 -n argocd --create-namespace -f poc/01-argocd/platform/argocd/values.yaml --wait --timeout 5m`
  - `upgrade --install` = 없으면 설치, 있으면 갱신 (두 번 돌려도 안전)
  - `-n argocd --create-namespace` = 네임스페이스 없으면 만들고 거기에
  - `-f ... values.yaml` = `poc/01` 에서 Jeong 이 채운 값 (dex 끔, insecure, polling 120s+60s). 그대로 재사용
  - `--wait` = 파드가 전부 Ready 될 때까지 명령이 안 끝난다 → 이 단계 시간 = Argo CD 가 실제로 뜨는 시간

### 3/5 kube-prometheus-stack
- 같은 꼴. 차트 `prometheus-community/kube-prometheus-stack` 92.14.1, 값 `monitoring/kps-values.yaml`.
- 이 차트는 먼저 **CRD**(ServiceMonitor, PrometheusRule, Prometheus 같은 "새 종류") 를 만들고, Operator 파드를 띄우고, Operator 가 `Prometheus` 리소스를 보고 Prometheus StatefulSet 을 만든다. 그래서 `--wait` 가 Operator 까지만 보고 끝나고, Prometheus 본체는 몇십 초 더 걸릴 수 있다 (4단계 동안 뜬다).
- `--timeout 10m` — 첫 회는 이미지 5개(Operator, Prometheus, Grafana, kube-state-metrics, node-exporter)를 받는다.

### 4/5 Git 에서 앱
- `kubectl apply -f gitops/root.yaml` — Application 1개를 만든다. 이게 **드릴에서 유일하게 손으로 apply 하는 앱 리소스** 다.
- 그다음 `wait_app root / podinfo / monitoring-rules` — 각 Application 의 `.status.sync.status` 가 `Synced`, `.status.health.status` 가 `Healthy` 가 될 때까지 5초마다 본다.
- 느리다면: Argo CD 가 GitHub 에서 레포를 clone → `apps/` 폴더 읽기 → podinfo 차트 다운로드 → 파드 뜨기. 보통 1~2분 【추정】. `kubectl -n argocd describe application podinfo` 의 Events 에 어디서 멈췄는지 나온다.

### 5/5 확인
- `curl -s -o /dev/null -w '%{http_code}' localhost:9898` — 본문은 버리고(`-o /dev/null`) 상태 코드만(`-w`). 200 이면 맥 → kind → NodePort → 파드가 뚫린 것.
- `kubectl -n podinfo get pods -o wide` — 파드 2개가 **다른 워커** 에 있나 (스케줄러가 퍼뜨린다. 같은 노드면 그것도 기록)
- `curl 'localhost:19090/api/v1/targets?state=active' | grep podinfo` — Prometheus 가 podinfo 를 긁기 시작했나. Operator 가 ServiceMonitor 를 읽어 설정에 넣는 데 30초쯤 걸려서 아직이면 "안 긁는다" 가 찍힌다. 잠시 뒤 `ports.sh` 로 http://localhost:9090/targets 에서 확인.

### 표
마지막에 단계별 초와 총 시간. `results/drill.csv` 에 자동 추가. **`results/drill.md` 표에 손으로 옮겨 적는다** (git 에 남는 건 md 뿐).

## 4. 할 일 (1회차)

- `starter-pack/infra-prep/scripts/preflight.sh` → 마지막 줄 "준비 완료" 확인
- 2절대로 파일 5개 읽기 (20분)
- `starter-pack/infra-prep/scripts/drill-30.sh` (레포 루트에서) — 첫 회는 20~40분 【추정】
- 끝나면 `starter-pack/infra-prep/scripts/ports.sh` 로 UI 3개 열기:
  - Argo CD http://localhost:8080 (admin / 스크립트가 출력한 비밀번호) → Applications 3개 초록
  - Grafana http://localhost:3000 (admin / admin) → Dashboards → "podinfo · 골든 시그널 4개"
  - Prometheus http://localhost:9090 → Status → Targets 에 `podinfo` / Alerts 에 `PodinfoHighErrorRate` (초록 = inactive)
- `results/drill.md` 1회차 줄 채우기
- 아래 "출력 붙여 보내기" 3개

**확인 질문 1개**: 3/5 단계에서 `--wait` 가 끝났는데 Prometheus 파드가 아직 없을 수 있다. 왜? (3절 3/5 참고. 답을 자기 말로 한 줄.)

**출력 붙여 보내기**: ① 스크립트 마지막 "단계별 시간" 표 ② `kubectl -n podinfo get pods -o wide` ③ `kubectl -n argocd get applications`

## 5. 막히면

| 증상 | 먼저 볼 것 | 흔한 원인 |
|---|---|---|
| 1/5 에서 `kind create` 가 멈춤/실패 | `docker ps -a`, Docker Desktop 메모리 | 메모리 부족, 이전 컨테이너 잔재 → `kind delete cluster --name prep`, `docker system prune` |
| 2/5 `--wait` 타임아웃 | `kubectl -n argocd get pods` | 이미지 받는 중(첫 회) → 그냥 다시 돌리면 `upgrade` 라 이어간다 |
| 3/5 Prometheus 파드 `Pending` | `kubectl -n monitoring describe pod <prometheus-kps-...>` | 메모리 부족(requests 256Mi 도 못 잡음) → Docker 메모리 늘리기 |
| 4/5 `podinfo` 가 `Unknown`/`ComparisonError` | `kubectl -n argocd describe application podinfo` | GitHub 에 못 붙음(네트워크), 또는 **이 파일들이 아직 main 에 push 안 됨** |
| 4/5 `monitoring-rules` 가 `SyncFailed` "no matches for kind PrometheusRule" | kps 가 떴나 (`kubectl get crd prometheusrules.monitoring.coreos.com`) | 3/5 가 실패했는데 넘어온 것. retry 5번 안에 kps 가 뜨면 알아서 성공 |
| 5/5 curl 이 000/연결 거부 | `kubectl -n podinfo get svc podinfo` 의 PORT 에 `31198` 이 있나 | 차트 값 `service.nodePort` 가 안 먹음, 또는 9898 을 다른 프로세스가 점유 (`lsof -nP -iTCP:9898`) |
| Grafana 에 대시보드가 안 보임 | `kubectl -n monitoring get cm podinfo-golden-signals --show-labels` | 라벨 `grafana_dashboard=1` 없음 / 사이드카가 아직 안 읽음 (1분 기다림) |
| Prometheus Targets 에 podinfo 없음 | `kubectl -n podinfo get servicemonitor` | ServiceMonitor 가 없거나, kps-values 의 `serviceMonitorSelectorNilUsesHelmValues: false` 가 빠짐 |

## 6. 2·3회차: 시간 줄이기

2회차부터는 이미지가 캐시되어 있어 "진짜 부팅 시간" 이 나온다. 그래도 30분이 넘으면 어디가 긴지 표에서 보고 하나씩:
- **kps 가 길다**(보통 가장 길다): `--wait` 를 빼고 4단계로 넘어가서 병렬로 기다리기(스크립트에서 `--wait --timeout 10m` 삭제 → 5단계 전에 `kubectl -n monitoring rollout status`). 또는 node-exporter 를 끈다(노드 지표 포기).
- **Argo CD 가 길다**: `poc/01` values 가 이미 dex·notifications 를 껐다. 더 줄이려면 `applicationSet.enabled: false` (드릴은 ApplicationSet 안 씀).
- **4단계가 길다**: Argo CD 는 Git 을 **120s + 0~60s 무작위** 간격으로 본다(poc/01 values). `kubectl apply` 직후 첫 동기화는 바로 하니 보통 문제 없지만, 늦으면 UI 에서 Refresh. 자동으로 빠르게 하려면 `timeout.reconciliation` 을 줄인다 (04 문서 Argo CD 절의 트레이드오프).

3회차는 **타임어택**: 시계 보고 시작, 중간에 문서 안 보기. 그 총 시간이 "셋업 드릴 30분" 게이트 통과 여부다.

## 7. 치우기

```bash
kind delete cluster --name prep        # 전부 사라진다 (Docker 이미지 캐시는 남는다 → 다음 회차 빠름)
```
`DELETE=1 scripts/drill-30.sh` 로 돌리면 끝나고 자동으로 지우고 삭제 시간도 표에 남긴다.

---

## 핵심 결정 3개 (+대안)

1. **Argo CD·모니터링은 helm, 앱·규칙은 Argo CD.** 대안: 전부 Argo CD(App of Apps 에 kps 추가) / 전부 helm. 이유: 드릴은 30분 안에 "매번 같게" 가 목적. CRD 큰 차트를 Argo CD 로 올리면 `ServerSideApply` 등 옵션이 하나 더 들어가 실패 지점이 는다. 본선 2일차에 시간이 남으면 "전부 Git" 으로 올리는 게 보여 주기 좋다.
2. **Argo CD values 는 `poc/01` 것을 재사용.** 대안: 드릴 전용 values. 이유: Jeong 이 직접 채운 파일이라 설명할 수 있고, polling 120s+60s 결정의 체감을 셀프 연습으로 잴 수 있다.
3. **podinfo 를 Helm 저장소 source 로.** 대안: 차트를 레포에 복사(vendoring) / 매니페스트 YAML. 이유: 파일 1개로 끝나고 `targetRevision` 으로 버전이 고정된다. 트레이드오프: 외부 저장소가 죽으면 sync 가 안 된다(본선 당일엔 레포 안에 복사해 두는 쪽이 안전. 그때 `helm pull podinfo --repo ... --untar`).

## 셀프 연습 1개

`gitops/apps/podinfo.yaml` 의 `replicaCount: 2` → `3`, `git commit && git push origin main`. 그 시각을 적고 `kubectl -n podinfo get pods -w` 로 세 번째 파드가 뜨는 시각을 잰다. 2~3분 걸리면 polling 이 그 이유다. Argo CD UI 의 Refresh 를 누르면 즉시인 것도 확인. 그 숫자를 `results/drill.md` 소감 줄에.

## 검증 명령과 기대 출력

```bash
kubectl config current-context                 # kind-prep
kubectl get nodes                              # 3개 Ready
kubectl -n argocd get applications             # root, podinfo, monitoring-rules: Synced Healthy
curl -s -o /dev/null -w '%{http_code}\n' localhost:9898     # 200
kubectl -n monitoring get prometheusrule,servicemonitor -A | grep podinfo   # podinfo-slo, podinfo
```
