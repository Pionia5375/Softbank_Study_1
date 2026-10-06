#!/usr/bin/env bash
# 메모리 비용 재기. 두 가지 눈으로 본다.
#   1) kubectl top: 네임스페이스별 Pod 메모리 합 (컨테이너 working set, metrics-server 값)
#   2) docker stats: kind 노드 컨테이너 3개가 Mac 의 Docker VM 에서 실제로 차지하는 양 (K8s 자체 + 모든 Pod 포함)
# 쓰는 법: scripts/stack-mem.sh <이름표>   예) before / after
# 결과: results/mem-<이름표>.log
set -eu
label=${1:?usage: $0 <이름표>}
cluster=${CLUSTER:-lab05}
cd "$(dirname "$0")/.."
mkdir -p results
out="results/mem-${label}.log"

{
  echo "# $(date '+%F %T') label=$label"
  echo "## kubectl top pods: 네임스페이스별 합계 (Mi)"
  kubectl top pods -A --no-headers 2>/dev/null | awk '
    { mem=$4; sub(/Mi$/,"",mem); s[$1]+=mem; t+=mem }
    END { for (n in s) printf "%-14s %6d Mi\n", n, s[n]; printf "%-14s %6d Mi\n", "TOTAL", t }' | sort
  echo
  echo "## monitoring 네임스페이스 Pod 별"
  kubectl top pods -n monitoring --no-headers 2>/dev/null | sort -k3 -h -r || echo "(monitoring 없음)"
  echo
  echo "## docker stats (kind 노드 = 컨테이너)"
  docker stats --no-stream --format '{{.Name}}\t{{.MemUsage}}' | grep "^${cluster}-" || true
} | tee "$out"
