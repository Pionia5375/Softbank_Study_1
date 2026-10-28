#!/usr/bin/env bash
# 30분 셋업 드릴: 빈 맥 → kind → Argo CD → Prometheus/Grafana → Git 에서 앱·알림 규칙 → curl 200. Claude 작성, 완성본.
# 안내서: starter-pack/infra-prep/02-drill-30min.md (단계마다 무엇을 하는지, 기대 출력, 막히면 볼 곳)
#
# 사용법 (레포 루트에서)
#   starter-pack/infra-prep/scripts/drill-30.sh            처음부터 끝까지 (이미 prep 클러스터가 있으면 지우고 새로)
#   DELETE=1 starter-pack/infra-prep/scripts/drill-30.sh   끝나고 클러스터도 지운다 (연속 회차용, destroy 시간도 잰다)
#   LABEL=2회차 starter-pack/infra-prep/scripts/drill-30.sh  results/drill.csv 에 라벨을 남긴다
# 단계마다 [N s] 를 찍고 마지막에 단계별 시간을 표로 보여 준다. 그 표를 results/drill.md 에 옮겨 적는다.
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"          # starter-pack/infra-prep
ROOT="$(cd "$HERE/../.." && pwd)"                 # 레포 루트
ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-10.10.5}"   # poc/01 과 같은 값 (Argo CD v3.5.5). 최신은 10.11.6 (2026-10-28)
KPS_CHART_VERSION="${KPS_CHART_VERSION:-92.14.1}"         # kube-prometheus-stack (Operator v0.94.2)
LABEL="${LABEL:-$(date '+%m/%d %H:%M')}"
mkdir -p "$HERE/results"

START=$(date +%s)
TIMES=()
say() { echo; echo "[$(( $(date +%s) - START ))s] ==== $*"; }
lap() { TIMES+=("$1 $(( $(date +%s) - $2 ))"); }

# Argo CD Application 이 Synced + Healthy 가 될 때까지 기다린다 (poc/run-all.sh 와 같음)
wait_app() {
  local app="$1" timeout="${2:-300}" t=0 s h
  while [ "$t" -lt "$timeout" ]; do
    s=$(kubectl -n argocd get application "$app" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)
    h=$(kubectl -n argocd get application "$app" -o jsonpath='{.status.health.status}' 2>/dev/null || true)
    if [ "$s" = "Synced" ] && [ "$h" = "Healthy" ]; then echo "  $app: Synced/Healthy (${t}s)"; return 0; fi
    sleep 5; t=$((t + 5))
  done
  echo "  $app: ${timeout}s 안에 Healthy 가 안 됨 (지금 $s/$h). kubectl -n argocd describe application $app 로 원인 확인"
  return 1
}

# ---------- 0. 점검 ----------
say "0/5 점검: 도구와 Docker 메모리"
for c in docker kind kubectl helm curl; do command -v "$c" >/dev/null || { echo "  $c 없음 → scripts/preflight.sh"; exit 1; }; done
docker info >/dev/null 2>&1 || { echo "  Docker 데몬에 못 붙음. Docker Desktop 켜기"; exit 1; }
mem=$(docker info --format '{{.MemTotal}}'); echo "  Docker 메모리 $(( mem / 1000000000 ))GB"
[ "$mem" -ge 6000000000 ] || echo "  경고: 6GB 미만이면 Prometheus 가 뜨다 멈출 수 있다"

# ---------- 1. kind ----------
say "1/5 kind 클러스터 prep (control-plane 1 + worker 2)"
t=$(date +%s)
if kind get clusters 2>/dev/null | grep -qx prep; then
  echo "  이미 있는 prep 삭제 (매번 빈 상태에서 시작해야 시간이 비교된다)"
  kind delete cluster --name prep
fi
kind create cluster --config "$HERE/cluster/kind-config.yaml"
kubectl wait --for=condition=Ready nodes --all --timeout=180s
kubectl get nodes
lap "1-kind" "$t"

# ---------- 2. Argo CD ----------
say "2/5 Argo CD (차트 $ARGOCD_CHART_VERSION, poc/01 values)"
t=$(date +%s)
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update argo >/dev/null
# upgrade --install = 없으면 설치, 있으면 갱신. --wait = 파드가 다 Ready 될 때까지 기다린다
helm upgrade --install argocd argo/argo-cd --version "$ARGOCD_CHART_VERSION" -n argocd --create-namespace \
  -f "$ROOT/poc/01-argocd/platform/argocd/values.yaml" --wait --timeout 5m
lap "2-argocd" "$t"

# ---------- 3. Prometheus + Grafana ----------
say "3/5 kube-prometheus-stack (차트 $KPS_CHART_VERSION): Operator + Prometheus + Grafana + kube-state-metrics + node-exporter"
t=$(date +%s)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update prometheus-community >/dev/null
# 이 차트는 CRD(ServiceMonitor, PrometheusRule 같은 새 종류)를 먼저 만들고 Operator 를 띄운다. 처음엔 이미지 받느라 길다
helm upgrade --install kps prometheus-community/kube-prometheus-stack --version "$KPS_CHART_VERSION" -n monitoring --create-namespace \
  -f "$HERE/monitoring/kps-values.yaml" --wait --timeout 10m
lap "3-kps" "$t"

# ---------- 4. Git 에서 앱 + 알림 규칙 ----------
say "4/5 root Application → Argo CD 가 Git 에서 podinfo + monitoring-rules 를 올린다"
t=$(date +%s)
kubectl apply -f "$HERE/gitops/root.yaml"
# root 가 apps/ 의 Application 두 개를 만들 때까지
for i in $(seq 1 30); do kubectl -n argocd get application podinfo monitoring-rules >/dev/null 2>&1 && break; sleep 2; done
wait_app root
wait_app podinfo 300
wait_app monitoring-rules 300
lap "4-gitops" "$t"

# ---------- 5. 확인 ----------
say "5/5 확인: 맥 9898 → podinfo"
t=$(date +%s)
code=000
for i in $(seq 1 60); do
  code=$(curl -s -o /dev/null -w '%{http_code}' localhost:9898 || true)
  [ "$code" = "200" ] && break
  sleep 2
done
echo "  curl localhost:9898 → $code"
[ "$code" = "200" ] || { echo "  200 이 아니다. 02-drill-30min.md '막히면' 5번"; exit 1; }
curl -s localhost:9898 | head -c 200; echo
echo; kubectl -n podinfo get pods -o wide
echo; kubectl -n argocd get applications
echo; kubectl -n monitoring get prometheusrule
# Prometheus 가 podinfo 를 긁기 시작했나 (targets 에 podinfo 가 있나). Operator 가 설정을 반영하는 데 30초쯤 걸린다
kubectl -n monitoring port-forward svc/kps-prometheus 19090:9090 >/dev/null 2>&1 &
pf=$!; sleep 3
if curl -s 'localhost:19090/api/v1/targets?state=active' | grep -q '"namespace":"podinfo"'; then
  echo "  Prometheus targets 에 podinfo 있음"
else
  echo "  Prometheus 가 아직 podinfo 를 안 긁는다 (30초 뒤 ports.sh 로 http://localhost:9090/targets 확인)"
fi
kill "$pf" 2>/dev/null || true
lap "5-check" "$t"

TOTAL=$(( $(date +%s) - START ))

# ---------- (선택) 삭제 ----------
if [ "${DELETE:-0}" = "1" ]; then
  say "삭제: kind delete cluster --name prep"
  t=$(date +%s); kind delete cluster --name prep; lap "6-delete" "$t"
fi

# ---------- 표 ----------
echo; echo "==== 단계별 시간 ($LABEL)"
printf '  %-12s %6s\n' 단계 초
line="$LABEL"
for x in "${TIMES[@]}"; do
  set -- $x; printf '  %-12s %6s\n' "$1" "$2"; line="$line,$1=$2"
done
echo "  총 ${TOTAL}s ($(( TOTAL / 60 ))분 $(( TOTAL % 60 ))초) — 목표 1800s"
echo "$line,total=$TOTAL" >> "$HERE/results/drill.csv"
echo "  → results/drill.csv 에 한 줄 추가됨. results/drill.md 표에도 옮겨 적기"
echo
echo "다음: starter-pack/infra-prep/scripts/ports.sh  (Argo CD 8080 / Grafana 3000 / Prometheus 9090)"
