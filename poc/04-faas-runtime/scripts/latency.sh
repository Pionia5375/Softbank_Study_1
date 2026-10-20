#!/usr/bin/env bash
# 켜져 있는(웜) 함수에 요청을 연달아 보내 p50/p95 를 잰다 (Claude 작성, 완성본).
# 쓰는 법:
#   scripts/latency.sh hello-gvisor-warm                       → 동시 4줄 × 200회, 쿼리 없음
#   C=8 REQ=500 QUERY='work=io&n=200' scripts/latency.sh hello-runc
#   WHILE_PID=1234 scripts/latency.sh hello-runc               → 그 프로세스가 끝날 때까지 계속 (build-noise.sh 가 쓴다)
# 출력 마지막 줄: n= p50= p95= min= max=  (curl 이 잰 요청~응답 전체 시간)
# 주의: 시간에는 맥 → Docker → Kourier 구간이 포함된다. 절대값보다 "같은 조건에서 A 와 B 의 차이" 로 읽는다
set -euo pipefail
source "$(dirname "$0")/lib.sh"
svc="${1:?함수 이름}"
C="${C:-4}"; REQ="${REQ:-200}"; QUERY="${QUERY:-}"; WHILE_PID="${WHILE_PID:-}"
host=$(fn_host "$svc")
url="$GATEWAY/${QUERY:+?$QUERY}"
dir=$(mktemp -d)

# curl 한 번에 요청 k개 (연결 재사용). -w 가 요청마다 "코드 시간" 한 줄씩 찍는다
batch() {
  local k=$1 cfg="$dir/cfg.$2"
  : > "$cfg"
  for _ in $(seq 1 "$k"); do printf 'url = "%s"\noutput = "/dev/null"\n' "$url" >> "$cfg"; done
  curl -s -H "Host: $host" -w '%{http_code} %{time_total}\n' --config "$cfg" || true
}
worker() {
  if [ -n "$WHILE_PID" ]; then
    while kill -0 "$WHILE_PID" 2>/dev/null; do batch 20 "$1"; done
  else
    batch "$REQ" "$1"
  fi > "$dir/w$1"
}
curl -s -o /dev/null -H "Host: $host" "$url"   # 첫 요청(혹시 콜드)은 버린다
for w in $(seq 1 "$C"); do worker "$w" & done
wait
errors=$(cat "$dir"/w* | awk '$1!=200' | wc -l | tr -d ' ')
line=$(cat "$dir"/w* | awk '$1==200{printf "%.2f\n", $2*1000}' | summarize)
rm -rf "$dir"
echo "$svc ${QUERY:-(no query)} C=$C errors=$errors"
echo "$line"
