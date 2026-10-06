#!/usr/bin/env bash
# k6 를 클러스터 안 Pod 로 한 번 돌리고, 결과 요약 + 그동안의 hello Pod 수·CPU·메모리 최댓값을 찍는다.
# 쓰는 법: scripts/k6-run.sh <이름표> [traefik|direct] [RPS] [본측정 시간]
#   예)    scripts/k6-run.sh r3            → Traefik 경유, 200 RPS, 2분
#          scripts/k6-run.sh r1 traefik 400 2m
# 대상:
#   traefik (기본) = k6 Pod → Traefik Service → hello Pod. Traefik 지표(PromQL 1~3)도 같이 쌓인다
#   direct         = k6 Pod → hello Service → hello Pod. Traefik 을 빼고 앱만 잴 때. 이때 PromQL 1~3 은 0 으로 보인다
# 결과: results/k6-<이름표>.log (k6 출력), results/top-<이름표>.log (10초마다 kubectl top)
set -eu

label=${1:?usage: $0 <이름표> [traefik|direct] [RPS] [DURATION]}
mode=${2:-traefik}
rate=${3:-200}
duration=${4:-2m}
image=grafana/k6:2.3.0

case "$mode" in
  traefik) target=http://traefik.traefik.svc.cluster.local/hello ;;
  direct)  target=http://hello.default.svc.cluster.local/hello ;;
  *) echo "대상은 traefik 또는 direct"; exit 1 ;;
esac

cd "$(dirname "$0")/.."
mkdir -p results
log="results/k6-${label}.log"
top="results/top-${label}.log"
: > "$top"

# 지금 조건을 로그 맨 위에 적어 둔다 (나중에 표 채울 때 헷갈리지 않게)
{
  echo "# $(date '+%F %T') label=$label mode=$mode rate=$rate duration=$duration"
  echo "# hello replicas(spec)=$(kubectl get deploy hello -o jsonpath='{.spec.replicas}')" \
       "resources=$(kubectl get deploy hello -o jsonpath='{.spec.template.spec.containers[0].resources}')"
  echo "# hpa: $(kubectl get hpa hello --no-headers 2>/dev/null || echo none)"
} | tee "$log"

# 뒤에서 10초마다 hello Pod 의 CPU/메모리를 적는다 (metrics-server 값)
(
  while true; do
    kubectl top pods -l app=hello --no-headers 2>/dev/null | sed "s/^/$(date +%s) /" >> "$top" || true
    sleep 10
  done
) &
sampler=$!
trap 'kill $sampler 2>/dev/null || true' EXIT

# k6 Pod 를 띄워 스크립트를 표준입력으로 넘긴다 (`k6 run -` = 스크립트를 stdin 에서 읽기).
#   --rm: 끝나면 Pod 삭제 / -i: 내 터미널의 stdin 을 Pod 에 연결 / --restart=Never: 한 번만 실행
#   임계값을 넘으면 k6 가 0 이 아닌 코드로 끝나는데, 측정 자체는 정상이므로 멈추지 않고 계속 간다
pod="k6-$(date +%s)"
kubectl run "$pod" --rm -i --restart=Never --image="$image" --pod-running-timeout=3m \
  -- run --quiet --no-usage-report -e TARGET="$target" -e RATE="$rate" -e DURATION="$duration" - \
  < k6/hello.js 2>&1 | tee -a "$log" || true

kill $sampler 2>/dev/null || true

# top 로그에서 최댓값 뽑기. 한 줄 = "<시각> <pod> <CPU>m <MEM>Mi"
summary=$(awk '
  { t=$1; cpu=$3; mem=$4; sub(/m$/,"",cpu); sub(/Mi$/,"",mem);
    pods[t]++; sum[t]+=cpu; if (mem+0>maxmem) maxmem=mem+0; if (cpu+0>maxcpu) maxcpu=cpu+0 }
  END { mp=0; ms=0; for (k in pods) { if (pods[k]>mp) mp=pods[k]; if (sum[k]>ms) ms=sum[k] }
        printf "max_pods=%d  max_cpu_total=%dm  max_cpu_per_pod=%dm  max_mem_per_pod=%dMi", mp, ms, maxcpu, maxmem }
' "$top")
echo "TOP | $summary" | tee -a "$log"
echo
echo "표에 옮길 줄:"
grep -E '^(RESULT|TOP) ' "$log" || echo "(RESULT 줄이 없다. $log 를 열어 k6 오류를 확인)"
