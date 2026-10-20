#!/usr/bin/env bash
# 합성 프로브 (Claude 작성): 클러스터 안에 curl 파드를 하나 띄워 0.1초마다 함수를 부르고,
# "응답코드 걸린초" 를 한 줄씩 로그로 남긴다. 장애 중 사용자가 본 것 = 이 로그.
#
#   ./scripts/probe.sh start <이름> <네임스페이스> <URL>   프로브 시작
#   ./scripts/probe.sh stop  <이름> <네임스페이스>         로그를 results/<이름>.probe.log 로 받고 파드 삭제
#
# 왜 클러스터 안에서?  맥에서 port-forward 로 부르면 port-forward 자체가 끊겨서 장애와 구분이 안 된다.
# 왜 피해자와 같은 네임스페이스?  3단계 NetworkPolicy 가 다른 ns 에서 오는 걸 막기 때문.
# 로그 줄 앞의 시각은 kubectl logs --timestamps 가 붙인다 (노드 시계 기준).
set -euo pipefail
. "$(dirname "$0")/lib.sh"

CMD="${1:-}"; NAME="${2:-}"; NS="${3:-}"; URL="${4:-}"
[ -n "$CMD" ] && [ -n "$NAME" ] && [ -n "$NS" ] || die "사용법: probe.sh start|stop <이름> <ns> [URL]"
POD="probe-$NAME"

case "$CMD" in
start)
  [ -n "$URL" ] || die "start 에는 URL 이 필요"
  kubectl -n "$NS" delete pod "$POD" --ignore-not-found --now >/dev/null 2>&1 || true
  # 프로브는 control-plane 이 아닌 노드 중 "장애를 넣지 않을" 쪽에 둔다: exec 풀이 아닌 노드를 선호
  kubectl apply -f - >/dev/null <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: $POD
  namespace: $NS
  labels: { app: chaos-probe }
spec:
  restartPolicy: Always
  terminationGracePeriodSeconds: 0
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          preference:
            matchExpressions: [{ key: ${EXEC_LABEL%%=*}, operator: NotIn, values: [${EXEC_LABEL#*=}] }]
  securityContext:
    runAsNonRoot: true
    runAsUser: 100
    seccompProfile: { type: RuntimeDefault }
  containers:
    - name: probe
      image: curlimages/curl:8.16.0
      command: [sh, -c]
      # --max-time 1: 1초 안에 못 받으면 000 으로 기록 (죽은 파드로 간 요청)
      args:
        - |
          while true; do
            curl -s -o /dev/null -w '%{http_code} %{time_total}\n' --max-time 1 "$URL" || true
            sleep 0.1
          done
      resources:
        requests: { cpu: 20m, memory: 16Mi }
        limits: { cpu: 200m, memory: 32Mi }
      securityContext:
        allowPrivilegeEscalation: false
        capabilities: { drop: [ALL] }
YAML
  kubectl -n "$NS" wait --for=condition=Ready pod/"$POD" --timeout=60s >/dev/null
  log "프로브 시작: $NS/$POD → $URL (노드 $(kubectl -n "$NS" get pod "$POD" -o jsonpath='{.spec.nodeName}'))"
  ;;
stop)
  OUT="$RESULTS/$NAME.probe.log"
  kubectl -n "$NS" logs "$POD" --timestamps > "$OUT"
  kubectl -n "$NS" delete pod "$POD" --now >/dev/null
  log "프로브 종료: $(wc -l < "$OUT" | tr -d ' ') 줄 → $OUT"
  ;;
*) die "start 또는 stop" ;;
esac
