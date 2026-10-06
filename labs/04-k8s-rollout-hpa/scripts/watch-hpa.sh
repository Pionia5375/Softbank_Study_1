#!/usr/bin/env bash
# 5초마다 "시각 / HPA 가 본 CPU / 현재 Pod 수" 를 한 줄씩 찍고 results/hpa-<이름표>.log 에도 남긴다.
# 쓰는 법: scripts/watch-hpa.sh <이름표>   (Ctrl+C 로 멈춤)
set -u
out="results/hpa-${1:-run}.log"
mkdir -p results
start=$(date +%s)
while true; do
  line=$(kubectl get hpa hello --no-headers -o custom-columns=CPU:.status.currentMetrics[0].resource.current.averageUtilization,DESIRED:.status.desiredReplicas,CURRENT:.status.currentReplicas 2>/dev/null)
  printf '%4ss  cpu%%/desired/current: %s\n' "$(( $(date +%s) - start ))" "$line" | tee -a "$out"
  sleep 5
done
