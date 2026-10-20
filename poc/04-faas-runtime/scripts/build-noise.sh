#!/usr/bin/env bash
# "빌드가 도는 동안 함수가 느려지나?" 를 잰다 (Claude 작성, 완성본). results/build-noise.csv 에 남긴다.
# 쓰는 법: scripts/build-noise.sh hello-gvisor-warm      (min-scale 1 인 함수를 쓴다. 콜드 스타트가 섞이면 안 돼서)
#
# 3가지 조건을 차례로
#   baseline : 빌드 없음
#   build    : 캐시 없는 빌드를 build 풀에서 돌리는 동안
#   exec     : 같은 빌드를 일부러 exec 풀(함수와 같은 노드)에서 돌리는 동안
# 함수 요청은 빈 요청(QUERY 없음) 동시 2줄. work=cpu 를 쓰면 함수 자신의 CPU limit(500m) 조절(throttling)이 섞여서
#   "옆 빌드 때문에 느려진 것" 과 구분이 안 된다 (README 8절 Claude 측정값 참고). 바꾸려면 C=4 QUERY=... 로
#
# 주의 (kind 의 한계): kind 노드는 전부 같은 맥의 CPU 를 나눠 쓴다. 그래서 build 풀로 옮겨도
#   맥 CPU 가 바쁘면 함수도 느려진다. 이 숫자는 "스케줄링 분리" 효과만 보여 준다.
#   진짜 기계 분리 효과는 7단계(EC2) 에서 다시 잰다.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
svc="${1:-hello-gvisor-warm}"
export C="${C:-2}" QUERY="${QUERY:-}" JOB_FILE="${JOB_FILE:-}"
csv="$RESULTS/build-noise.csv"
[ -f "$csv" ] || echo "time,fn,scenario,p50_ms,p95_ms,n,errors,build_s" > "$csv"
here="$(dirname "$0")"

record() {  # $1=시나리오 $2=latency 출력 $3=빌드초
  local s; s=$(echo "$2" | tail -1)
  local e; e=$(echo "$2" | head -1 | grep -o 'errors=[0-9]*' | cut -d= -f2)
  echo "$(date +%FT%T),$svc,$1,$(pick p50 "$s"),$(pick p95 "$s"),$(pick n "$s"),$e,$3" >> "$csv"
  echo "  $1: $s (build ${3}s)"
}

echo "1/3 baseline (빌드 없음)"
out=$(REQ=2000 "$here/latency.sh" "$svc"); record baseline "$out" 0

for pool in build exec; do
  echo "빌드 시작 (pool=$pool, 캐시 없음)"
  log=$(mktemp)
  NOCACHE=1 POOL=$pool "$here/build.sh" "noise-$pool-$(date +%s)" > "$log" 2>&1 &
  bpid=$!
  # 빌드 Pod 가 실제로 돌기 시작할 때까지 (스케줄·이미지 받는 시간은 빼려고)
  until kubectl -n "$BUILD_NS" get pods -l app=fn-build --field-selector=status.phase=Running --no-headers 2>/dev/null | grep -q .; do
    kill -0 $bpid 2>/dev/null || break; sleep 1
  done
  out=$(WHILE_PID=$bpid "$here/latency.sh" "$svc")
  wait $bpid || true
  secs=$(grep -o '결과: [a-z]*, [0-9.]*s' "$log" | grep -o '[0-9.]*s' | tr -d s)
  record "$pool" "$out" "${secs:-?}"
  rm -f "$log"
done
echo "CSV: $csv"
tail -4 "$csv"
