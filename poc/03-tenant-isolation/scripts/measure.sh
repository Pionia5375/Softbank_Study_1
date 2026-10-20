#!/usr/bin/env bash
# 설계 문서에 넣을 숫자 2종을 잰다 (Claude 작성, 완성본).
#
#   scripts/measure.sh neighbor
#     "옆집 소음" 실험. tenant-b 함수의 응답 시간(p50/p95)을 세 상황에서 200번씩 잰다.
#       baseline   : 아무도 CPU 를 안 먹을 때
#       hog-tenant : tenant-a 에서 무한 루프 파드 4개 (LimitRange 때문에 각 200m 로 묶임)
#       hog-free   : fn-demo(울타리 없는 namespace)에서 무한 루프 파드 4개 (limits 없음 = 코어를 통째로 먹음)
#     → "울타리가 있으면 옆 테넌트가 폭주해도 p95 가 얼마나 덜 흔들리나" 가 숫자로 나온다.
#
#   scripts/measure.sh onboard [횟수=3]
#     "새 테넌트 하나 추가에 몇 초?" tenants/tenant-c.yaml 을 만들어 git commit + push 하고,
#     namespace·Quota·NetworkPolicy 가 다 생겨 Application 이 Healthy 가 될 때까지 시간을 잰다.
#     그다음 파일을 지우고 push 해서 namespace 가 사라질 때까지(오프보딩)도 잰다. 이걸 N번.
#     ⚠ main 에 실제로 commit + push 한다 (1인 레포 규칙대로). 끝나면 tenant-c 파일은 지워진 상태로 남는다.
#     SOLUTION=1 이면 solution/tenants/ 를 쓴다 (정답본 ApplicationSet 을 붙였을 때).
#
# 결과: results/neighbor-<시각>.csv, results/onboard-<시각>.csv
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
FIX="$HERE/fixtures"
POC="$(cd "$HERE/.." && pwd)"
ROOT="$(cd "$POC/../.." && pwd)"
RESULTS="$POC/results"
mkdir -p "$RESULTS"
TS=$(date +%Y%m%d-%H%M%S)

now_ms() { perl -MTime::HiRes=time -e 'printf "%d\n", time*1000'; }

# ---------------------------------------------------------------------------
# neighbor
# ---------------------------------------------------------------------------
# tenant-b 안의 iso-client 가 iso-echo 를 200번 부르고 p50/p95/max(ms)를 출력
latency() {
  kubectl -n tenant-b exec iso-client -- sh -c '
    for i in $(seq 1 200); do
      curl -s -o /dev/null -w "%{time_total}\n" --max-time 5 http://iso-echo
    done' \
  | awk '{ printf "%d\n", $1*1000 }' | sort -n \
  | awk '{ v[NR]=$1 } END { p50=v[int(NR*0.50)]; p95=v[int(NR*0.95)]; printf "%d %d %d\n", p50, p95, v[NR] }'
}

start_hogs() {
  local ns="$1"
  for i in 1 2 3 4; do
    sed "s/name: iso-hog$/name: iso-hog-$i/" "$FIX/iso-hog.yaml" | kubectl -n "$ns" apply -f - >/dev/null
  done
  for i in 1 2 3 4; do kubectl -n "$ns" wait --for=condition=Ready "pod/iso-hog-$i" --timeout=120s >/dev/null; done
  sleep 5   # CPU 가 다 달아오를 때까지
}

stop_hogs() {
  local ns="$1"
  for i in 1 2 3 4; do kubectl -n "$ns" delete pod "iso-hog-$i" --ignore-not-found --wait=true >/dev/null; done
}

neighbor() {
  local CSV="$RESULTS/neighbor-$TS.csv"
  echo "scenario,p50_ms,p95_ms,max_ms" > "$CSV"
  kubectl get ns fn-demo >/dev/null 2>&1 || kubectl create ns fn-demo >/dev/null
  kubectl -n tenant-b apply -f "$FIX/iso-echo.yaml" -f "$FIX/iso-client.yaml" >/dev/null
  kubectl -n tenant-b rollout status deploy/iso-echo --timeout=120s >/dev/null
  kubectl -n tenant-b wait --for=condition=Ready pod/iso-client --timeout=120s >/dev/null
  trap 'stop_hogs tenant-a; stop_hogs fn-demo; kubectl -n tenant-b delete deploy,svc,pod -l poc03=fixture --wait=false >/dev/null 2>&1' EXIT

  local r
  echo "baseline 측정 중..."
  r=$(latency); echo "baseline,${r// /,}" >> "$CSV"; echo "  baseline    p50/p95/max(ms) = $r"

  echo "tenant-a 에 무한 루프 4개 (각 limits 200m) ..."
  start_hogs tenant-a
  r=$(latency); echo "hog-tenant,${r// /,}" >> "$CSV"; echo "  hog-tenant  p50/p95/max(ms) = $r"
  stop_hogs tenant-a

  echo "fn-demo 에 무한 루프 4개 (limits 없음) ..."
  start_hogs fn-demo
  r=$(latency); echo "hog-free,${r// /,}" >> "$CSV"; echo "  hog-free    p50/p95/max(ms) = $r"
  stop_hogs fn-demo

  echo "→ $CSV"
}

# ---------------------------------------------------------------------------
# onboard
# ---------------------------------------------------------------------------
wait_until() {   # wait_until <제한초> <명령...> : 명령이 성공할 때까지 1초마다 재시도
  local limit="$1"; shift
  local t=0
  until "$@" >/dev/null 2>&1; do
    sleep 1; t=$((t+1))
    [ "$t" -ge "$limit" ] && return 1
  done
}

tenant_ready() {
  kubectl -n tenant-c get resourcequota tenant-quota &&
  kubectl -n tenant-c get networkpolicy default-deny-all &&
  [ "$(kubectl -n argocd get application tenant-c -o jsonpath='{.status.sync.status}/{.status.health.status}')" = "Synced/Healthy" ]
}
tenant_gone() { ! kubectl get ns tenant-c; }

# ApplicationSet 에 "지금 Git 다시 봐" 신호. 안 하면 기본 3분마다 한 번 본다 【사실: requeueAfterSeconds 기본 180초, ApplicationSet Git generator 문서】
refresh_appset() {
  kubectl -n argocd annotate applicationset tenants argocd.argoproj.io/application-set-refresh=true --overwrite >/dev/null 2>&1
}

git_push() {
  ( cd "$ROOT" && git add -A "$1" && git commit -q -m "$2" && git pull -q --rebase origin main && git push -q origin main )
}

onboard() {
  local n="${1:-3}"
  local TEN_DIR="$POC/tenants"
  [ "${SOLUTION:-0}" = "1" ] && TEN_DIR="$POC/solution/tenants"
  local F="$TEN_DIR/tenant-c.yaml"
  local CSV="$RESULTS/onboard-$TS.csv"
  echo "run,onboard_s,offboard_s" > "$CSV"

  for run in $(seq 1 "$n"); do
    printf 'name: tenant-c\nquota:\n  requestsCpu: 500m\n  requestsMemory: 512Mi\n  limitsCpu: "1"\n  limitsMemory: 1Gi\n  pods: "5"\n  services: "3"\n' > "$F"
    local t0 on off
    t0=$(now_ms)
    git_push "$F" "poc03: measure onboard tenant-c (run $run)"
    refresh_appset
    # Application 이 생기면 그것도 바로 새로고침 (repo-server 캐시 때문에 늦게 보는 걸 막음)
    wait_until 300 kubectl -n argocd get application tenant-c && \
      kubectl -n argocd annotate application tenant-c argocd.argoproj.io/refresh=normal --overwrite >/dev/null
    if wait_until 300 tenant_ready; then on=$(( ($(now_ms)-t0)/1000 )); else on=TIMEOUT; fi
    echo "  run $run: 온보딩 ${on}s"

    rm -f "$F"
    t0=$(now_ms)
    git_push "$F" "poc03: measure offboard tenant-c (run $run)"
    refresh_appset
    if wait_until 300 tenant_gone; then off=$(( ($(now_ms)-t0)/1000 )); else off=TIMEOUT; fi
    echo "  run $run: 오프보딩 ${off}s"
    echo "$run,$on,$off" >> "$CSV"
  done
  echo "→ $CSV"
}

case "${1:-}" in
  neighbor) neighbor ;;
  onboard) onboard "${2:-3}" ;;
  *) echo "사용법: $0 neighbor | onboard [횟수]"; exit 2 ;;
esac
