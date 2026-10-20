#!/usr/bin/env bash
# 시나리오 2: 함수 폭주 (노이지 네이버) — Claude 작성, 완성본
#
#   ./scripts/s2-noisy-neighbor.sh [폭주 파드 수=30] [회수=1]
#
# 상황: tenant-b 의 함수가 무한 루프에 빠졌고, 오토스케일러가 "바쁘네?" 하고 파드를 30개로 늘렸다.
#       파드 하나가 CPU 0.5코어를 예약(requests)하고 1코어까지 태운다(limits). 피해자 함수와 같은 exec 풀에 뜬다.
# 보는 것 (피해자 = tenant-a 함수)
#   - 응답 지연 p95 가 평소 대비 얼마나 올랐나 (CPU 를 뺏겼나)
#   - 피해자가 파드를 2개 더 늘리려 할 때 몇 초 만에 Ready 되나 (노드 자리를 뺏겼나 = Pending)
#   - 폭주 파드가 실제로 몇 개 떴나 (나머지는 쿼터가 막았나), 막힌 걸 언제 알았나 (이벤트, 알림)
# 3단계 격리(ResourceQuota·LimitRange)가 제대로면: 폭주 파드는 몇 개만 뜨고, 피해자 숫자는 거의 안 변한다.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

BURNERS="${1:-30}"; RUNS="${2:-1}"
ALERT="${ALERT_QUOTA:-TenantQuotaNearLimit}"
BASELINE="${BASELINE:-30}"
HOLD="${HOLD:-60}"             # 폭주 상태를 유지하는 초
SCALE_UP="${SCALE_UP:-2}"      # 폭주 중 피해자가 늘려 보는 파드 수 (0 이면 건너뜀: Knative 처럼 kubectl scale 이 안 먹는 경우)
CSV="$RESULTS/s2-noisy-neighbor.csv"
show_ctx

burner() {
  kubectl apply -f - >/dev/null <<YAML
apiVersion: apps/v1
kind: Deployment
metadata: { name: noisy, namespace: $TENANT_B, labels: { app: noisy, chaos: s2 } }
spec:
  replicas: $1
  selector: { matchLabels: { app: noisy } }
  template:
    metadata: { labels: { app: noisy } }
    spec:
      nodeSelector: { ${EXEC_LABEL%%=*}: ${EXEC_LABEL#*=} }
      terminationGracePeriodSeconds: 0
      securityContext:
        runAsNonRoot: true
        runAsUser: 65532
        seccompProfile: { type: RuntimeDefault }
      containers:
        - name: burn
          image: busybox:1.37
          # 아무 일도 안 하고 CPU 만 태우는 무한 루프 = "버그 난 함수"
          command: [sh, -c, "while :; do :; done"]
          resources:
            requests: { cpu: 500m, memory: 16Mi }
            limits: { cpu: "1", memory: 32Mi }
          securityContext:
            allowPrivilegeEscalation: false
            capabilities: { drop: [ALL] }
YAML
}

for i in $(seq 1 "$RUNS"); do
  ORIG=$(kubectl -n "$FN_NS" get deploy "$FN_NAME" -o jsonpath='{.spec.replicas}')
  QUOTA=$(kubectl -n "$TENANT_B" get resourcequota --no-headers 2>/dev/null | wc -l | tr -d ' ')
  log "[$i/$RUNS] 폭주 파드 $BURNERS 개 시도 / $TENANT_B 쿼터 ${QUOTA}개 / 피해자 $FN_NS/$FN_NAME ($ORIG 개)"
  probe_name="s2-$i"
  "$(dirname "$0")/probe.sh" start "$probe_name" "$FN_NS" "$FN_URL"
  log "  평소 상태 ${BASELINE}초 재는 중"; sleep "$BASELINE"

  T0=$(now); T0_ISO=$(perl -MPOSIX -e 'print strftime("%Y-%m-%dT%H:%M:%SZ", gmtime(int($ARGV[0])))' "$T0")
  log "  t0: $TENANT_B 에 폭주 Deployment 적용"
  burner "$BURNERS"

  # 쿼터에 막혔다는 신호(ReplicaSet 의 FailedCreate 이벤트)가 처음 보인 시각, 알림 시각
  T_BLOCKED=""; T_ALERT=""
  for s in $(seq 1 30); do
    # 이벤트는 1시간 남아 있어서, 지난 회차 것과 섞이지 않게 t0 이후 시각(lastTimestamp)인 것만 본다 (ISO 문자열은 크기 비교가 곧 시각 비교)
    if [ -z "$T_BLOCKED" ] && kubectl -n "$TENANT_B" get events --field-selector reason=FailedCreate \
         -o jsonpath='{range .items[*]}{.lastTimestamp} {.message}{"\n"}{end}' 2>/dev/null \
         | awk -v t="$T0_ISO" '$1 >= t' | grep -q 'exceeded quota'; then
      T_BLOCKED=$(since "$T0" "$(now)"); log "  쿼터가 막음 (FailedCreate exceeded quota): +${T_BLOCKED}s"
    fi
    if [ -z "$T_ALERT" ]; then
      a=$(alert_firing "$ALERT")
      if [ "$a" = "1" ]; then T_ALERT=$(since "$T0" "$(now)"); log "  알림 $ALERT firing: +${T_ALERT}s"
      elif [ "$a" = "-1" ]; then T_ALERT="n/a"; fi
    fi
    [ -n "$T_BLOCKED" ] && [ -n "$T_ALERT" ] && break
    [ "$QUOTA" = 0 ] && [ "$s" -ge 10 ] && break    # 쿼터가 없으면 막힘도 쿼터 알림도 안 온다. 20초만 보고 넘어간다
    sleep 2
  done
  sleep 10
  RUNNING=$(kubectl -n "$TENANT_B" get pods -l app=noisy --field-selector status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')
  PENDING=$(kubectl -n "$TENANT_B" get pods -l app=noisy --field-selector status.phase=Pending --no-headers 2>/dev/null | wc -l | tr -d ' ')
  log "  폭주 파드: Running $RUNNING / Pending $PENDING / 시도 $BURNERS"

  # 폭주 중에 피해자가 파드를 늘릴 수 있나
  T_SCALE=""
  if [ "$SCALE_UP" -gt 0 ]; then
    TS=$(now)
    kubectl -n "$FN_NS" scale deploy "$FN_NAME" --replicas=$((ORIG + SCALE_UP)) >/dev/null
    if kubectl -n "$FN_NS" rollout status deploy/"$FN_NAME" --timeout=60s >/dev/null 2>&1; then
      T_SCALE=$(since "$TS" "$(now)")
    else
      T_SCALE="timeout"
    fi
    log "  피해자 $ORIG → $((ORIG + SCALE_UP)) 개 늘리기: ${T_SCALE}s"
  fi

  REMAIN=$(perl -e "my \$r = $HOLD - int($(now) - $T0); print \$r > 0 ? \$r : 0")
  log "  폭주 유지 ${REMAIN}초 더"; sleep "$REMAIN"

  log "  복구: 폭주 Deployment 삭제, 피해자 원래 개수로"
  T_FIX=$(now)
  kubectl -n "$TENANT_B" delete deploy noisy --wait=false >/dev/null
  kubectl -n "$FN_NS" scale deploy "$FN_NAME" --replicas="$ORIG" >/dev/null
  sleep 15
  "$(dirname "$0")/probe.sh" stop "$probe_name" "$FN_NS"
  kubectl -n "$TENANT_B" wait --for=delete pod -l app=noisy --timeout=60s >/dev/null 2>&1 || true

  python3 "$(dirname "$0")/analyze.py" --log "$RESULTS/$probe_name.probe.log" --t0 "$T0" --window "$HOLD" --csv "$CSV" \
    --extra "label=$LABEL,run=$i,quota_objects=$QUOTA,burners_wanted=$BURNERS,burners_running=$RUNNING,burners_pending=$PENDING,t_blocked_s=$T_BLOCKED,t_alert_s=$T_ALERT,victim_scaleup_s=$T_SCALE,fix_at_s=$(since "$T0" "$T_FIX")"
done
