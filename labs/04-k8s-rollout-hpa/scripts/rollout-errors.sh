#!/usr/bin/env bash
# 롤아웃(Pod 전부 교체) 중에 요청이 몇 개나 실패하는지 센다.
# 쓰는 법: scripts/rollout-errors.sh <이름표>   예) scripts/rollout-errors.sh no-probe
# 하는 일:
#   1) 0.1초마다 localhost:8088/hello 를 부르며 HTTP 코드를 기록 (백그라운드)
#   2) kubectl rollout restart 로 Pod 를 전부 새로 띄우고, 끝날 때까지 기다린다
#   3) 5초 더 부른 뒤 멈추고, 코드별 개수를 출력한다
set -u
label=${1:-run}
out="results/rollout-${label}.log"
mkdir -p results
: > "$out"

( while true; do
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 localhost:8088/hello)
    echo "$code" >> "$out"
    sleep 0.1
  done ) &
loop=$!

sleep 3                                   # 평소 상태 몇 초
start=$(date +%s)
kubectl rollout restart deployment/hello
kubectl rollout status deployment/hello --timeout=180s
end=$(date +%s)
sleep 5
kill "$loop"

total=$(wc -l < "$out" | tr -d ' ')
fail=$(grep -vc '^200$' "$out")
echo "---- ${label} ----"
echo "롤아웃 시간: $((end - start))s"
echo "요청 ${total}개 중 실패 ${fail}개"
sort "$out" | uniq -c                     # 000 = 연결 실패/타임아웃, 502/503/404 = Traefik 이 넘길 곳이 없음
