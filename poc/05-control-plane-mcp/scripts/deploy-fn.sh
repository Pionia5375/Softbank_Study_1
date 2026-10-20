#!/usr/bin/env bash
# 함수 하나를 배포하고 단계별 시간을 잰다 (Claude 작성, 완성본).
#   사용: scripts/deploy-fn.sh <tenant> <name> <code-file>
#   예:   scripts/deploy-fn.sh tenant-a hello samples/hello-v1.py
# 환경 변수
#   CP     컨트롤 플레인 주소 (기본 http://localhost:8080)
#   GW     Knative 입구 주소. 비우면 첫 요청 시간은 안 잰다 (예: http://localhost:8081)
#   OUT    결과 CSV (기본 results/deploy-times.csv)
# 출력: 사람이 읽는 줄 + CSV 한 줄 (ts,tenant,name,build_id,build_s,apply_s,total_s,first_request_ms,http_code)
set -euo pipefail
cd "$(dirname "$0")/.."

TENANT=${1:?tenant}; NAME=${2:?name}; FILE=${3:?code file}
CP=${CP:-http://localhost:8080}
GW=${GW:-}
OUT=${OUT:-results/deploy-times.csv}

now() { python3 -c 'import time; print(time.time())'; }
since() { python3 -c "print(round($(now) - $1, 2))"; }

# 코드 파일을 JSON 문자열로 안전하게 감싼다 (따옴표·줄바꿈 이스케이프)
BODY=$(python3 -c 'import json,sys; print(json.dumps({"name": sys.argv[1], "code": open(sys.argv[2]).read()}))' "$NAME" "$FILE")

T0=$(now)
RESP=$(curl -sS -f -X POST "$CP/api/v1/tenants/$TENANT/functions" \
  -H 'Content-Type: application/json' -H "X-Actor: ${USER:-jeong}" -d "$BODY")
BUILD_ID=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["buildId"])' "$RESP")
echo "접수: buildId=$BUILD_ID"

BUILD_S=""; PHASE=""; LAST=""
while true; do
  STATUS=$(curl -sS "$CP/api/v1/tenants/$TENANT/functions/$NAME" || true)
  PHASE=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("phase",""))' "$STATUS" 2>/dev/null || echo "")
  SERVING=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("buildId") or "")' "$STATUS" 2>/dev/null || echo "")
  if [[ "$PHASE" != "$LAST" ]]; then echo "  $(since "$T0")s  $PHASE"; LAST=$PHASE; fi
  if [[ -z "$BUILD_S" && "$PHASE" != "BUILDING" ]]; then BUILD_S=$(since "$T0"); fi
  if [[ "$PHASE" == "READY" && "$SERVING" == "$BUILD_ID" ]]; then break; fi
  if [[ "$PHASE" == "BUILD_FAILED" || "$PHASE" == "FAILED" ]]; then echo "실패: $STATUS"; exit 1; fi
  if (( $(python3 -c "print(int($(since "$T0") > 600))") )); then echo "10분 넘음"; exit 1; fi
  sleep 0.5
done
TOTAL_S=$(since "$T0")
APPLY_S=$(python3 -c "print(round($TOTAL_S - $BUILD_S, 2))")
URL=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get("url") or "")' "$STATUS")

FIRST_MS=""; CODE=""
if [[ -n "$GW" && -n "$URL" ]]; then
  HOST=$(python3 -c 'import sys,urllib.parse; print(urllib.parse.urlparse(sys.argv[1]).hostname)' "$URL")
  read -r CODE SECS < <(curl -sS -o /dev/null -w '%{http_code} %{time_total}\n' -H "Host: $HOST" "$GW" -d 'jeong')
  FIRST_MS=$(python3 -c "print(round($SECS*1000))")
fi

echo "빌드 ${BUILD_S}s + 반영 ${APPLY_S}s = 총 ${TOTAL_S}s, 첫 요청 ${FIRST_MS:-?}ms (HTTP ${CODE:-?})"
mkdir -p "$(dirname "$OUT")"
[[ -f "$OUT" ]] || echo "ts,tenant,name,build_id,build_s,apply_s,total_s,first_request_ms,http_code" > "$OUT"
echo "$(date +%Y-%m-%dT%H:%M:%S),$TENANT,$NAME,$BUILD_ID,$BUILD_S,$APPLY_S,$TOTAL_S,$FIRST_MS,$CODE" >> "$OUT"
