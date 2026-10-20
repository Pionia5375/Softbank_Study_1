#!/usr/bin/env bash
# 클러스터 안에서 podinfo 에 계속 요청을 보내는 "가짜 사용자" (Claude 작성, 완성본)
#
#   scripts/load.sh start   부하 Pod(load) 를 띄운다. 초당 약 10개 요청, 한 줄에 "초 상태코드" 를 찍는다
#   scripts/load.sh stop    부하 Pod 를 지운다
#   scripts/load.sh stats [시작초 [끝초]]   그 구간의 요청 수 / 2xx 아닌 응답 수 / 비율
#
# 왜 필요한가: AnalysisTemplate 은 "실제로 들어온 요청" 의 성공률을 본다. 요청이 0 이면
# 분모가 0 이라 결과가 NaN 이 되고, NaN >= 0.95 는 거짓이라 멀쩡한 배포도 실패 처리된다.
# 그리고 사용자 쪽에서 본 에러 수(= 이 Pod 의 로그)가 롤백 효과를 재는 기준 숫자가 된다.
set -euo pipefail

NS=${NS:-fn-canary}
URL=${URL:-http://podinfo.${NS}.svc.cluster.local/}
SLEEP=${SLEEP:-0.1}   # 요청 사이 쉬는 시간(초). 0.1 이면 curl 시간까지 합쳐 초당 7~10개

case "${1:-}" in
  start)
    kubectl -n "$NS" delete pod load --ignore-not-found --wait=true >/dev/null
    # --restart=Never : 한 번 뜨는 Pod (Deployment 아님)
    # curl 이미지 안의 sh 로 무한 반복: 요청 → "현재초 상태코드" 출력 → 잠깐 쉬기
    # -m 2 : 2초 넘게 걸리면 포기하고 000 으로 찍는다
    kubectl -n "$NS" run load --image=curlimages/curl:8.23.0 --restart=Never \
      --labels=app=load --command -- sh -c \
      "while true; do c=\$(curl -s -o /dev/null -m 2 -w '%{http_code}' $URL); echo \"\$(date +%s) \$c\"; sleep $SLEEP; done"
    kubectl -n "$NS" wait --for=condition=Ready pod/load --timeout=60s
    echo "load 시작: $URL"
    ;;
  stop)
    kubectl -n "$NS" delete pod load --ignore-not-found
    ;;
  stats)
    FROM=${2:-0}
    TO=${3:-9999999999}
    kubectl -n "$NS" logs load | awk -v f="$FROM" -v t="$TO" '
      $1 >= f && $1 <= t { n++; if ($2 !~ /^2/) e++ }
      END { printf "requests=%d errors=%d error_pct=%.2f\n", n, e, (n ? 100*e/n : 0) }'
    ;;
  *)
    echo "사용법: $0 start | stop | stats [시작초 [끝초]]" >&2
    exit 1
    ;;
esac
