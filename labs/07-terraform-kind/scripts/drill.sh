#!/usr/bin/env bash
# 셋업 드릴: apply → curl 200 확인 → destroy 를 N번 반복하고 시간을 잰다.
#   사용법: scripts/drill.sh <dev|demo> [반복 횟수=3]
#   예:     scripts/drill.sh dev        # dev 3회
#           scripts/drill.sh demo 1     # demo 1회
# 결과: results/drill.log (전체 출력), 마지막에 요약표.
# macOS 기본 bash 3.2 에서도 돌게 썼다 (연관 배열·mapfile 안 씀).
set -euo pipefail

ENV="${1:-}"
RUNS="${2:-3}"
CURL_WAIT_MAX=120   # apply 끝나고 첫 200 을 몇 초까지 기다릴지

if [ "$ENV" != "dev" ] && [ "$ENV" != "demo" ]; then
  echo "사용법: $0 <dev|demo> [반복 횟수]" >&2
  exit 1
fi

LAB_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_DIR="$LAB_DIR/envs/$ENV"
LOG="$LAB_DIR/results/drill.log"
TF="${TF:-terraform}"   # OpenTofu 로 돌릴 땐: TF=tofu scripts/drill.sh dev
mkdir -p "$LAB_DIR/results"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }
# 중간에 실패하면 어디서 멈췄는지 알려 준다. 클러스터가 남아 있을 수 있으니 destroy 를 손으로 한 번
trap 'echo "실패. 로그: $LOG  / 정리: (cd $ENV_DIR && $TF destroy -auto-approve)" >&2' ERR

# ---- 사전 점검 ----
docker image inspect lab01-hello:multi >/dev/null 2>&1 \
  || { echo "lab01-hello:multi 이미지가 없다. Lab 01 에서 먼저 빌드" >&2; exit 1; }

PORT="$(sed -n 's/^host_port *= *\([0-9]*\).*/\1/p' "$ENV_DIR/terraform.tfvars")"
if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "맥 $PORT 포트를 이미 누가 쓰고 있다 (예: Lab 02 의 lab02 클러스터). 확인: lsof -nP -iTCP:$PORT -sTCP:LISTEN" >&2
  echo "lab02 라면: kind delete cluster --name lab02" >&2
  exit 1
fi

cd "$ENV_DIR"
log "===== drill env=$ENV runs=$RUNS port=$PORT ($($TF version | head -1)) ====="
$TF init -input=false >>"$LOG" 2>&1

SUMMARY=""
for i in $(seq 1 "$RUNS"); do
  log "--- run $i/$RUNS: apply ---"
  t0=$(date +%s)
  $TF apply -auto-approve -input=false >>"$LOG" 2>&1
  t1=$(date +%s)
  apply_s=$((t1 - t0))
  log "apply ${apply_s}s"

  # apply 가 끝난 뒤 첫 200 이 오기까지 (wait=true 면 거의 0 이어야 한다)
  first200="timeout"
  for _ in $(seq 1 "$CURL_WAIT_MAX"); do
    code="$(curl -s -o /dev/null -w '%{http_code}' "localhost:$PORT/hello" || true)"
    if [ "$code" = "200" ]; then
      first200=$(( $(date +%s) - t1 ))
      break
    fi
    sleep 1
  done
  log "curl localhost:$PORT/hello → 첫 200 까지 ${first200}s"
  (curl -s "localhost:$PORT/hello" || true) | tee -a "$LOG"; echo | tee -a "$LOG"

  log "--- run $i/$RUNS: destroy ---"
  t2=$(date +%s)
  $TF destroy -auto-approve -input=false >>"$LOG" 2>&1
  destroy_s=$(( $(date +%s) - t2 ))
  log "destroy ${destroy_s}s"

  SUMMARY="${SUMMARY}| ${ENV} | ${i} | ${apply_s} | ${first200} | ${destroy_s} |
"
done

{
  echo
  echo "| env | 회차 | apply (s) | apply 후 첫 200 (s) | destroy (s) |"
  echo "|---|---|---|---|---|"
  printf '%s' "$SUMMARY"
} | tee -a "$LOG"
