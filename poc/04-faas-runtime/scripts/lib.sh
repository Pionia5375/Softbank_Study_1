#!/usr/bin/env bash
# 공통 값과 함수 (Claude 작성). 다른 스크립트가 source 로 불러 쓴다.
# 값은 환경 변수로 바꿀 수 있다. 예: NS=tenant-a scripts/coldstart.sh hello-runc
POC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS="$POC_DIR/results"
CLUSTER="${CLUSTER:-faas}"
NS="${NS:-fn-runtime}"                 # 함수(ksvc) namespace
BUILD_NS="${BUILD_NS:-fn-build}"       # 빌드 Job namespace
DOMAIN="${DOMAIN:-faas.local}"         # setup.sh 가 Knative config-domain 에 넣은 값
GATEWAY="${GATEWAY:-http://localhost:8081}"   # 맥 8081 → Kourier NodePort 31080 (kind-config extraPortMappings)
mkdir -p "$RESULTS"

# Knative 는 Host 헤더로 어느 함수인지 고른다: <함수>.<namespace>.<도메인>
fn_host() { echo "$1.$NS.$DOMAIN"; }

# 숫자(한 줄에 하나)를 받아서 "n= p50= p95= min= max=" 를 찍는다. 백분위는 nearest-rank 방식
summarize() {
  sort -n | awk '
    { v[NR]=$1 }
    END {
      if (NR==0) { print "n=0"; exit }
      i50=int(NR*0.50); if (i50<NR*0.50) i50++; if (i50<1) i50=1
      i95=int(NR*0.95); if (i95<NR*0.95) i95++; if (i95<1) i95=1
      printf "n=%d p50=%.1fms p95=%.1fms min=%.1fms max=%.1fms\n", NR, v[i50], v[i95], v[1], v[NR]
    }'
}

# summarize 출력에서 값 하나 꺼내기. 예: pick p95 "$line" → 123.4
pick() { echo "$2" | tr ' ' '\n' | awk -F= -v k="$1" '$1==k{gsub("ms","",$2); print $2}'; }

now_ms() { python3 -c 'import time; print(int(time.time()*1000))'; }
