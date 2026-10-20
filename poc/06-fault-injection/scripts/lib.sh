# 6단계 스크립트 공통 함수 (Claude 작성). 맥 기본 bash 3.2 에서도 돌게 썼다.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/env.sh"
mkdir -p "$RESULTS"

# 현재 시각 (유닉스 초, 소수점 1자리). 맥 date 는 소수점 초를 못 줘서 perl
now() { perl -MTime::HiRes=time -e 'printf "%.1f\n", time'; }
# 두 시각의 차 (초, 소수점 1자리)
since() { perl -e "printf '%.1f', $2 - $1"; }
log() { echo "[$(date +%H:%M:%S)] $*"; }
die() { echo "에러: $*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "$1 가 없다. 설치 후 다시"; }
need kubectl
need perl
need python3

# 지금 kubectl 이 어느 클러스터를 보는지 보여 준다 (엉뚱한 클러스터에 장애를 넣지 않게)
show_ctx() { log "kubectl 컨텍스트: $(kubectl config current-context)"; }

# Prometheus 에 PromQL 을 묻는다. API 서버의 서비스 프록시를 타서 port-forward 가 필요 없다.
# 결과 시계열 개수를 출력. Prometheus 가 없으면 -1
prom_count() {
  local ns="${PROM_SVC%%/*}" rest="${PROM_SVC#*/}"
  local q; q=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "$1")
  # 응답을 먼저 변수에 받는다. 파이프로 바로 넘기면 pipefail 때문에 kubectl 실패 시 -1 이 두 번 찍힌다 (실제로 밟았다)
  local body; body=$(kubectl get --raw "/api/v1/namespaces/$ns/services/$rest/proxy/api/v1/query?query=$q" 2>/dev/null) || { echo -1; return 0; }
  printf '%s' "$body" | python3 -c 'import json,sys
try: print(len(json.load(sys.stdin)["data"]["result"]))
except Exception: print(-1)'
}
# 알림 이름이 firing 상태인가 (1/0, Prometheus 없으면 -1)
alert_firing() {
  local c; c=$(prom_count "ALERTS{alertname=\"$1\",alertstate=\"firing\"}")
  if [ "$c" = "-1" ]; then echo -1; elif [ "$c" -gt 0 ]; then echo 1; else echo 0; fi
}
prom_ok() { [ "$(prom_count 'up')" != "-1" ]; }
