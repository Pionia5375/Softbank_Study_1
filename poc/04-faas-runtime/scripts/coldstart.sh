#!/usr/bin/env bash
# 콜드 스타트 측정 (Claude 작성, 완성본). 결과는 results/coldstart.csv 에 쌓이고 마지막에 p50/p95 를 찍는다.
# 쓰는 법: scripts/coldstart.sh hello-runc 10
#          scripts/coldstart.sh hello-gvisor 10
#          IDLE=30 scripts/coldstart.sh hello-gvisor-warm 10   (min-scale 1 이라 0 이 안 된다 → 30초 쉬고 요청)
#
# 한 번 재기 =
#   1. 그 함수의 Pod 가 0개가 될 때까지 기다린다 (window 6s + scale-to-zero-grace-period 30s + 종료 시간 → 보통 40~70초)
#   2. 요청 1번을 보내고 응답까지 걸린 시간을 잰다
#      = Kourier → activator(요청을 잡아 둠) → 오토스케일러가 Pod 1개 생성 → 스케줄 → 컨테이너 시작 → 준비 확인 → 응답
#   3. 응답 JSON 의 cold 가 true 인지 본다 (새 프로세스의 첫 요청이었나 = 진짜 콜드 스타트였나)
# 10회면 한 함수에 10분쯤 걸린다. p95 는 20회 이상일 때 의미가 있다 (10회면 사실상 최댓값)
set -euo pipefail
source "$(dirname "$0")/lib.sh"
svc="${1:?함수 이름 (예: hello-runc)}"
N="${2:-10}"
IDLE="${IDLE:-30}"
host=$(fn_host "$svc")
minscale=$(kubectl -n "$NS" get ksvc "$svc" -o jsonpath='{.spec.template.metadata.annotations.autoscaling\.knative\.dev/min-scale}')
csv="$RESULTS/coldstart.csv"
[ -f "$csv" ] || echo "time,fn,run,ms,cold,http,pod_node" > "$csv"
tmp=$(mktemp)

pods() { kubectl -n "$NS" get pods -l "serving.knative.dev/service=$svc" --no-headers 2>/dev/null | wc -l | tr -d ' '; }

echo "함수 $svc ($host), $N회, min-scale=${minscale:-0}"
for i in $(seq 1 "$N"); do
  if [ "${minscale:-0}" -ge 1 ] 2>/dev/null; then
    sleep "$IDLE"
  else
    waited=0
    until [ "$(pods)" = "0" ]; do
      sleep 2; waited=$((waited+2))
      [ $waited -lt 300 ] || { echo "5분이 지나도 0개가 안 된다. kubectl -n $NS get pods 확인"; exit 1; }
    done
    sleep 2   # Kourier·activator 가 "0개" 를 알아챌 틈
  fi
  out=$(curl -s -o "$tmp" -w '%{http_code} %{time_total}' -H "Host: $host" --max-time 120 "$GATEWAY/")
  code=${out% *}; ms=$(awk -v s="${out#* }" 'BEGIN{printf "%.1f", s*1000}')
  cold=$(grep -o '"cold":[a-z]*' "$tmp" | cut -d: -f2 || true)
  pod=$(grep -o '"pod":"[^"]*"' "$tmp" | cut -d'"' -f4 || true)
  node=$( [ -n "$pod" ] && kubectl -n "$NS" get pod "$pod" -o jsonpath='{.spec.nodeName}' 2>/dev/null || echo "?")
  echo "$(date +%FT%T),$svc,$i,$ms,$cold,$code,$node" >> "$csv"
  printf "  %2d/%d  %8.1fms  cold=%s  http=%s  node=%s\n" "$i" "$N" "$ms" "$cold" "$code" "$node"
done
rm -f "$tmp"
echo "$svc 요약 (이번 실행 $N회): $(tail -n "$N" "$csv" | awk -F, '$6==200{print $4}' | summarize)"
