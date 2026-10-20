#!/usr/bin/env bash
# PoC 01~05 를 정답본 기준으로 한 클러스터에 끝까지 올린다 (+ 06 은 별도 대역 클러스터). Claude 작성, 완성본.
# 안내서: poc/RUN-ALL.md (단계마다 무엇을 하는지, 기대 출력, 막히면 볼 곳)
#
# 왜 단계별 README 순서(01 → 02 → 03 재생성 → 04 재생성 → 05)대로 안 하나
#   03·04 단계는 클러스터를 지우고 다시 만든다(CNI 를 Cilium 으로, 노드 풀에 taint). 그래서 02 에서 깐 것이 사라진다.
#   여기서는 처음부터 "최종 모양" 클러스터(04 kind-config: Cilium + 워커 3대 + taint + 8081)를 한 번 만들고
#   그 위에 01 → 04 → 02 → 03 → 05 를 차례로 얹는다. 06 은 클러스터를 망가뜨리는 실험이라 대역 클러스터(kind-chaos)에서.
#
# 사용법 (레포 루트에서)
#   poc/run-all.sh                 preflight → platform → rollouts → tenants → control-plane → check (전부)
#   poc/run-all.sh tenants check   원하는 단계만 (앞 단계가 이미 떠 있어야 한다)
#   poc/run-all.sh chaos           06 대역 클러스터 세우기 (faas 와 별개. 메모리 약 3GB 더)
# 단계마다 [N s] 를 찍고 마지막에 단계별 시간을 표로 보여 준다 → 셋업 드릴 기록
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
P="$ROOT/poc"
CP_PORT="${CP_PORT:-8090}"   # 컨트롤 플레인 port-forward 맥 포트. 8080 은 Argo CD UI 가 쓰니까 피한다
START=$(date +%s)
TIMES=()

say()  { echo; echo "[$(( $(date +%s) - START ))s] ==== $*"; }
lap()  { TIMES+=("$1 $(( $(date +%s) - $2 ))s"); }

# Argo CD Application 이 Synced + Healthy 가 될 때까지 기다린다
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

preflight() {
  say "preflight: 필요한 도구와 Docker 자원"
  local miss=0
  for c in docker kind kubectl helm cilium python3 git; do
    if command -v "$c" >/dev/null; then echo "  ok  $c"; else echo "  없음 $c"; miss=1; fi
  done
  command -v kubectl-argo-rollouts >/dev/null && echo "  ok  kubectl-argo-rollouts" || echo "  (선택) kubectl-argo-rollouts 없음: brew install argoproj/tap/kubectl-argo-rollouts"
  [ "$miss" = 0 ] || { echo "위 '없음' 을 brew install 로 깔고 다시"; exit 1; }
  docker info --format '  Docker: {{.NCPU}} CPU, {{.MemTotal}} bytes'
  local mem; mem=$(docker info --format '{{.MemTotal}}')
  [ "$mem" -ge 8000000000 ] || echo "  경고: Docker 메모리 8GB 미만. Docker Desktop → Settings → Resources 에서 10GB 이상 권장"
  # 정답본이 원래 자리에 올라와 있는지 (빈칸이 남았으면 Argo CD sync 가 실패한다)
  if grep -rn --include=*.yaml -E '^[^#]*___' "$P"/0[2-6]-* --exclude-dir=solution --exclude-dir=standin >/dev/null; then
    echo "  빈칸(___)이 남은 YAML 이 있다. git pull origin main 으로 최신 main 을 받았나?"; exit 1
  fi
  echo "  빈칸 없음"
}

platform() {
  say "platform: 클러스터 + Cilium + Argo CD(01) + 레지스트리·Knative·gVisor·빌드·함수(04)"
  local t=$(date +%s)
  # 04 단계 셋업 드릴 스크립트를 그대로 쓴다: 옛 faas 삭제 → 생성 → Cilium/Hubble → Argo CD + root → setup.sh → 빌드 v1 → faas-functions
  "$P/04-faas-runtime/scripts/rebuild-cluster.sh"
  wait_app root
  wait_app hello-fn
  wait_app faas-functions 420 || echo "  (hello-gvisor 가 안 뜨면 gVisor 문제. RUN-ALL.md 의 '막히면' 참고. 나머지는 계속 진행)"
  lap platform "$t"
}

rollouts() {
  say "rollouts(02): Argo Rollouts + Prometheus + podinfo"
  local t=$(date +%s)
  helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
  helm repo update argo prometheus-community >/dev/null
  # upgrade --install = 없으면 설치, 있으면 갱신. 두 번 돌려도 안전하다
  helm upgrade --install argo-rollouts argo/argo-rollouts --version 2.43.8 -n argo-rollouts --create-namespace \
    -f "$P/02-rollouts/platform/rollouts/values.yaml" --wait --timeout 5m
  helm upgrade --install prometheus prometheus-community/prometheus --version 29.37.0 -n monitoring --create-namespace \
    -f "$P/02-rollouts/platform/prometheus/values.yaml" --wait --timeout 5m
  kubectl apply -f "$P/02-rollouts/gitops/podinfo.yaml"
  wait_app podinfo
  lap rollouts "$t"
}

tenants() {
  say "tenants(03): 테넌트 공장(ApplicationSet) + tenant-a/b 함수"
  local t=$(date +%s)
  kubectl apply -f "$P/03-tenant-isolation/gitops/tenants-appset.yaml"
  # ApplicationSet 이 tenant-a, tenant-b Application 을 찍어 낼 때까지
  for i in $(seq 1 30); do kubectl -n argocd get application tenant-a tenant-b >/dev/null 2>&1 && break; sleep 2; done
  wait_app tenant-a
  wait_app tenant-b
  kubectl apply -f "$P/03-tenant-isolation/gitops/tenant-a-hello.yaml" -f "$P/03-tenant-isolation/gitops/tenant-b-hello.yaml"
  wait_app tenant-a-hello
  wait_app tenant-b-hello
  lap tenants "$t"
}

control_plane() {
  say "control-plane(05): 이미지 빌드 → kind 에 싣기 → Argo CD 로 배포 → 함수 하나 배포"
  local t=$(date +%s)
  docker build -t faas-control-plane:0.1 "$P/05-control-plane-mcp/control-plane"
  kind load docker-image faas-control-plane:0.1 --name faas
  # README 5단계는 이 파일을 01 의 apps/ 폴더에 복사해 push 한다(App of Apps). 여기선 push 없이 같은 Application 을 직접 붙인다
  kubectl apply -f "$P/05-control-plane-mcp/k8s/argocd/platform-05.yaml"
  wait_app platform-05
  kubectl -n faas-system rollout status deploy/control-plane --timeout=180s
  kubectl -n faas-system port-forward svc/control-plane "$CP_PORT:80" >/dev/null 2>&1 &
  local pf=$! rc=0
  sleep 3
  (cd "$P/05-control-plane-mcp" && CP="http://localhost:$CP_PORT" GW=http://localhost:8081 \
    scripts/deploy-fn.sh tenant-a hello samples/hello-v1.py) || rc=$?
  kill "$pf" 2>/dev/null || true     # port-forward 정리
  [ "$rc" = 0 ] || { echo "  함수 배포 실패. RUN-ALL.md 의 '막히면' 5번"; exit "$rc"; }
  lap control-plane "$t"
}

check() {
  say "check: 전체 상태 한 번에"
  kubectl get nodes -L pool
  echo; kubectl -n argocd get applications
  echo; kubectl get ksvc -A
  echo; echo "-- 04 함수 (runc) 호출"
  curl -s -m 30 -H "Host: hello-runc.fn-runtime.faas.local" localhost:8081 || echo "  응답 없음"
  echo; echo "-- 05 함수 (tenant-a/hello) 호출"
  curl -s -m 30 -H "Host: hello.tenant-a.faas.local" localhost:8081 -d jeong || echo "  응답 없음"
  echo; echo "-- 03 격리 실험 (네트워크만, 빠른 확인)"
  "$P/03-tenant-isolation/scripts/test-isolation.sh" net || true
}

chaos() {
  say "chaos(06): 대역 클러스터 kind-chaos (faas 는 그대로 둔다)"
  local t=$(date +%s)
  local d="$P/06-fault-injection"
  kind get clusters | grep -qx chaos || kind create cluster --config "$d/standin/kind-config.yaml"
  kubectl config use-context kind-chaos
  kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -n argo-rollouts --server-side -f https://github.com/argoproj/argo-rollouts/releases/download/v1.10.1/install.yaml
  kubectl -n argo-rollouts rollout status deploy/argo-rollouts --timeout=180s
  kubectl apply -f "$d/standin/targets.yaml"
  kubectl apply -f "$d/standin/monitoring.yaml"
  (cd "$d" && ./standin/load-rules.sh defenses/prometheus-alerts-values.yaml)
  kubectl get pods -A -o wide | grep -E 'tenant|monitoring|rollouts' || true
  echo "  다음: cd poc/06-fault-injection && LABEL=방어전 ./scripts/s1-node-down.sh hard 1  (RUN-ALL.md 6절)"
  echo "  faas 로 돌아가기: kubectl config use-context kind-faas"
  lap chaos "$t"
}

STAGES=("$@")
[ ${#STAGES[@]} -gt 0 ] || STAGES=(preflight platform rollouts tenants control-plane check)
for s in "${STAGES[@]}"; do
  case "$s" in
    preflight) preflight ;;
    platform) platform ;;
    rollouts) rollouts ;;
    tenants) tenants ;;
    control-plane) control_plane ;;
    check) check ;;
    chaos) chaos ;;
    *) echo "모르는 단계: $s (preflight platform rollouts tenants control-plane check chaos)"; exit 1 ;;
  esac
done

echo; echo "==== 단계별 시간"
for x in ${TIMES[@]+"${TIMES[@]}"}; do echo "  $x"; done
echo "  총 $(( $(date +%s) - START ))s"
