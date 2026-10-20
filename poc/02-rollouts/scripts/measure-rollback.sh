#!/usr/bin/env bash
# 나쁜 배포가 자동으로 멈추고 되돌아가기까지의 시간과, 그동안 사용자가 본 에러 수를 잰다 (Claude 작성, 완성본)
#
#   scripts/measure-rollback.sh [반복횟수=3]
#
# 1회차: 이 스크립트를 먼저 켜 두고, 나쁜 배포를 git push 한다. 카나리가 시작되는 순간부터 잰다.
# 2회차부터: 이미 abort 된 같은 나쁜 배포를 `kubectl argo rollouts retry` 로 다시 시작시켜 잰다.
#            (git push 를 반복하지 않아도 같은 조건으로 3~5회 잴 수 있다)
#
# 결과: results/rollback.csv 에 한 줄씩 쌓인다
#   detect_s  = 카나리 시작 → abort 까지 초 (분석이 나쁜 걸 알아채는 데 걸린 시간)
#   clean_s   = 카나리 시작 → 카나리 파드가 트래픽에서 다 빠질 때까지 초 (사용자가 에러를 볼 수 있던 시간)
#   value     = abort 직전 마지막 측정값 (카나리 2xx 비율)
#   requests/errors/error_pct = 그 구간에 부하 Pod 가 본 전체 요청 / 2xx 아닌 응답 / 비율
#
# 전제: scripts/load.sh start 로 부하가 돌고 있다. kubectl argo rollouts 플러그인이 깔려 있다.
set -euo pipefail

NS=${NS:-fn-canary}
RO=${RO:-podinfo}
RUNS=${1:-3}
DIR=$(cd "$(dirname "$0")/.." && pwd)
OUT="$DIR/results/rollback.csv"
TIMEOUT=600

get() { kubectl -n "$NS" get rollout "$RO" -o jsonpath="$1"; }
now() { date +%s; }

# 조건이 참이 될 때까지 1초마다 확인. 시간 넘으면 실패
wait_until() {
  local desc=$1; shift
  local start; start=$(now)
  until "$@"; do
    if (( $(now) - start > TIMEOUT )); then echo "시간 초과: $desc" >&2; exit 1; fi
    sleep 1
  done
}

canary_started() { [[ "$(get '{.status.currentPodHash}')" != "$(get '{.status.stableRS}')" ]]; }
aborted()        { [[ "$(get '{.status.abort}')" == "true" ]]; }
not_aborted()    { ! aborted; }
finished()       { aborted || [[ "$(get '{.status.phase}')" == "Healthy" ]]; }
canary_gone() {
  local ready
  ready=$(kubectl -n "$NS" get rs "$RO-$1" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)
  [[ -z "$ready" || "$ready" == "0" ]]
}

[[ -f "$OUT" ]] || echo "run,started_at,detect_s,clean_s,value,requests,errors,error_pct" > "$OUT"
kubectl -n "$NS" get pod load >/dev/null 2>&1 || { echo "부하 Pod 가 없다. 먼저 scripts/load.sh start" >&2; exit 1; }

for run in $(seq 1 "$RUNS"); do
  if aborted; then
    echo "[$run/$RUNS] abort 상태 → retry 로 같은 카나리를 다시 시작"
    kubectl argo rollouts retry rollout "$RO" -n "$NS" >/dev/null
    wait_until "retry 반영" not_aborted
    T0=$(now)
  else
    echo "[$run/$RUNS] 카나리 시작 대기 중. 지금 나쁜 배포를 git push 하고, 빨리 보려면 Argo CD 에서 Refresh"
    wait_until "카나리 시작" canary_started
    T0=$(now)
  fi
  HASH=$(get '{.status.currentPodHash}')
  echo "  카나리 시작 (hash=$HASH, t=0)"

  wait_until "abort 또는 승격" finished
  T1=$(now)
  if ! aborted; then
    echo "  !! abort 없이 100% 승격됐다 (분석이 나쁜 배포를 못 잡음). 여기서 멈춘다" >&2
    echo "$run,$T0,promoted,,,,,"  >> "$OUT"
    exit 1
  fi
  echo "  abort: +$((T1 - T0))s"

  wait_until "카나리 파드 빠짐" canary_gone "$HASH"
  T2=$(now)
  echo "  카나리 0개: +$((T2 - T0))s"

  # 이번 카나리의 가장 최근 AnalysisRun 에서 마지막 측정값
  AR=$(kubectl -n "$NS" get analysisrun -l rollouts-pod-template-hash="$HASH" \
        --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1:].metadata.name}')
  VALUE=$(kubectl -n "$NS" get analysisrun "$AR" \
        -o jsonpath='{.status.metricResults[0].measurements[-1:].value}' | tr -d '[]')

  # 부하 로그가 kubectl logs 로 나올 때까지 잠깐 여유
  sleep 2
  STATS=$("$DIR/scripts/load.sh" stats "$T0" "$T2")
  REQ=$(sed -E 's/.*requests=([0-9]+).*/\1/' <<<"$STATS")
  ERR=$(sed -E 's/.*errors=([0-9]+).*/\1/' <<<"$STATS")
  PCT=$(sed -E 's/.*error_pct=([0-9.]+).*/\1/' <<<"$STATS")
  echo "  분석 마지막 값=$VALUE  $STATS"
  echo "$run,$T0,$((T1 - T0)),$((T2 - T0)),$VALUE,$REQ,$ERR,$PCT" >> "$OUT"

  # 다음 회차 전에 stable 이 5개 다 Ready 로 돌아오길 기다린다
  sleep 10
done

echo
echo "결과: $OUT"
column -s, -t < "$OUT"
