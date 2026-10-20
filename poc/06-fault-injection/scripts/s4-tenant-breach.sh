#!/usr/bin/env bash
# 시나리오 4: 테넌트 간 침범 시도 — Claude 작성, 완성본
#
#   ./scripts/s4-tenant-breach.sh
#
# tenant-b 안에 "공격자" 파드를 하나 띄우고(테넌트 함수와 같은 권한), 옆 테넌트(tenant-a)를 건드려 본다.
# 시도마다 기대 결과(막혀야 함)와 실제 결과를 표로 찍고, 하나라도 뚫리면 종료 코드 1.
#
#   N1 네트워크: 공격자 → tenant-a Service (DNS 이름)           NetworkPolicy 가 막아야
#   N2 네트워크: 공격자 → tenant-a 파드 IP 직접 (Service 우회)   NetworkPolicy 가 막아야
#   N3 네트워크: 공격자 → 쿠버네티스 API 서버                   egress 정책이 막아야 (함수가 API 를 부를 일은 없다)
#   N4 네트워크: 공격자 → 169.254.169.254 (클라우드 메타데이터)  EC2(7단계)에선 여기서 노드 IAM 자격증명이 샌다
#   R1 권한   : tenant-b 함수 계정(default)으로 tenant-a Secret 읽기   RBAC 가 403 으로 막아야
#   R2 권한   : tenant-b 함수 계정으로 tenant-b 에 파드 만들기   RBAC 가 막아야 (함수가 파드를 만들 일은 없다)
#   P1 파드보안: tenant-b 에 privileged + hostPath / 파드 만들기  Pod Security(restricted)가 막아야
#   Q1 한도   : tenant-b 에 CPU 4코어짜리 파드 만들기           LimitRange max / ResourceQuota 가 막아야
#
# 감지: 시도가 끝나면 Prometheus 에서 403·PSA 거부 수를 읽고(있으면), Cilium 이면 hubble 로 DROPPED 흐름을 보여 준다.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

ATTACK_SA="${ATTACK_SA:-default}"     # 함수 파드가 실제로 쓰는 계정. 3단계 차트도 함수엔 default 를 쓴다
VICTIM_SVC="${VICTIM_SVC:-http://$FN_NAME.$TENANT_A.svc/}"
CSV="$RESULTS/s4-tenant-breach.csv"
AS="system:serviceaccount:$TENANT_B:$ATTACK_SA"
show_ctx

kubectl -n "$TENANT_B" get sa "$ATTACK_SA" >/dev/null 2>&1 || die "$TENANT_B 에 ServiceAccount $ATTACK_SA 가 없다 (ATTACK_SA=... 로 바꾸기)"

log "공격자 파드 띄우는 중 ($TENANT_B, 계정 $ATTACK_SA)"
kubectl -n "$TENANT_B" delete pod attacker --ignore-not-found --now >/dev/null 2>&1 || true
kubectl apply -f - >/dev/null <<YAML
apiVersion: v1
kind: Pod
metadata: { name: attacker, namespace: $TENANT_B, labels: { app: attacker } }
spec:
  serviceAccountName: $ATTACK_SA
  terminationGracePeriodSeconds: 0
  securityContext:
    runAsNonRoot: true
    runAsUser: 100
    seccompProfile: { type: RuntimeDefault }
  containers:
    - name: sh
      image: curlimages/curl:8.16.0
      command: [sleep, "3600"]
      resources:
        requests: { cpu: 10m, memory: 16Mi }
        limits: { cpu: 100m, memory: 32Mi }
      securityContext:
        allowPrivilegeEscalation: false
        capabilities: { drop: [ALL] }
YAML
kubectl -n "$TENANT_B" wait --for=condition=Ready pod/attacker --timeout=60s >/dev/null

VICTIM_IP=$(kubectl -n "$TENANT_A" get pods -l "$FN_SELECTOR" -o jsonpath='{.items[0].status.podIP}')
VICTIM_PORT=$(kubectl -n "$TENANT_A" get pods -l "$FN_SELECTOR" -o jsonpath='{.items[0].spec.containers[0].ports[0].containerPort}')
NEW="date,id,attempt,expected,actual,verdict,seconds"
[ -f "$CSV" ] || echo "$NEW" > "$CSV"
FAILS=0

row() {  # id 설명 기대 실제 판정 초
  printf '  %-3s %-44s 기대:%-8s 실제:%-28s %s (%ss)\n' "$1" "$2" "$3" "$4" "$5" "$6"
  echo "$(date +%F),$1,\"$2\",$3,\"$4\",$5,$6" >> "$CSV"
  [ "$5" = PASS ] || FAILS=$((FAILS + 1))
}

# 파드 안에서 curl. 응답 코드(연결 실패면 000)만 돌려준다
net_try() {
  kubectl -n "$TENANT_B" exec attacker -- sh -c "curl -s -o /dev/null -w '%{http_code}' --max-time 3 $1 || true" 2>/dev/null
}

echo
log "침범 시도 (PASS = 막혔다)"
T=$(now); c=$(net_try "$VICTIM_SVC")
[ "$c" = "000" ] && v=PASS || v=FAIL; row N1 "tenant-a Service ($VICTIM_SVC)" blocked "http $c" $v "$(since "$T" "$(now)")"

T=$(now); c=$(net_try "http://$VICTIM_IP:$VICTIM_PORT/")
[ "$c" = "000" ] && v=PASS || v=FAIL; row N2 "tenant-a 파드 IP 직접 ($VICTIM_IP:$VICTIM_PORT)" blocked "http $c" $v "$(since "$T" "$(now)")"

T=$(now); c=$(net_try "-k https://kubernetes.default.svc/api")
[ "$c" = "000" ] && v=PASS || v=FAIL; row N3 "API 서버 (kubernetes.default.svc)" blocked "http $c" $v "$(since "$T" "$(now)")"

T=$(now); c=$(net_try "http://169.254.169.254/latest/meta-data/")
[ "$c" = "000" ] && v=PASS || v=FAIL; row N4 "메타데이터 169.254.169.254" blocked "http $c" $v "$(since "$T" "$(now)")"

T=$(now); out=$(kubectl --as="$AS" -n "$TENANT_A" get secrets 2>&1 || true)
echo "$out" | grep -q Forbidden && v=PASS || v=FAIL; row R1 "SA 로 tenant-a Secret 목록" forbidden "$(echo "$out" | grep -o 'Forbidden' | head -1)" $v "$(since "$T" "$(now)")"

T=$(now); out=$(kubectl --as="$AS" -n "$TENANT_B" run r2 --image=busybox:1.37 --restart=Never --dry-run=server 2>&1 || true)
echo "$out" | grep -q Forbidden && v=PASS || v=FAIL; row R2 "SA 로 자기 ns 에 파드 생성" forbidden "$(echo "$out" | grep -o 'Forbidden' | head -1)" $v "$(since "$T" "$(now)")"

T=$(now); T_P1=$T
out=$(kubectl apply --dry-run=server -f - 2>&1 <<YAML || true
apiVersion: v1
kind: Pod
metadata: { name: p1-escape, namespace: $TENANT_B }
spec:
  containers:
    - name: x
      image: busybox:1.37
      command: [sleep, "60"]
      securityContext: { privileged: true }
      volumeMounts: [{ name: host, mountPath: /host }]
  volumes: [{ name: host, hostPath: { path: / } }]
YAML
)
echo "$out" | grep -q 'violates PodSecurity' && v=PASS || v=FAIL; row P1 "privileged + hostPath:/ 파드 (관리자 권한으로도)" forbidden "$(echo "$out" | grep -o 'violates PodSecurity "[a-z]*:[a-z]*"' | head -1)" $v "$(since "$T" "$(now)")"

T=$(now)
out=$(kubectl apply --dry-run=server -f - 2>&1 <<YAML || true
apiVersion: v1
kind: Pod
metadata: { name: q1-hog, namespace: $TENANT_B }
spec:
  securityContext: { runAsNonRoot: true, runAsUser: 100, seccompProfile: { type: RuntimeDefault } }
  containers:
    - name: x
      image: busybox:1.37
      command: [sleep, "60"]
      resources: { requests: { cpu: "4" }, limits: { cpu: "4" } }
      securityContext: { allowPrivilegeEscalation: false, capabilities: { drop: [ALL] } }
YAML
)
echo "$out" | grep -qE 'forbidden|exceeded quota|maximum cpu' && v=PASS || v=FAIL
row Q1 "CPU 4코어 파드" forbidden "$(echo "$out" | grep -oE 'exceeded quota|maximum cpu usage per Container' | head -1)" $v "$(since "$T" "$(now)")"

echo
log "감지 신호"
if prom_ok; then
  # P1(특권 파드 시도) 시각부터 알림이 firing 될 때까지 = 이 시나리오의 감지 시간. 긁기·평가 주기 때문에 수십 초 걸린다
  T_ALERT="none"
  for s in $(seq 1 45); do
    if [ "$(alert_firing TenantPolicyDenied)" = 1 ]; then T_ALERT=$(since "$T_P1" "$(now)"); break; fi
    sleep 2
  done
  log "  알림 TenantPolicyDenied: P1 시도 후 ${T_ALERT}s 에 firing (none = 90초 안에 안 옴)"
  log "  Prometheus: 최근 5분 403 응답 시계열 $(prom_count 'increase(apiserver_request_total{code="403"}[5m]) > 0') 개, PSA 거부 시계열 $(prom_count 'increase(pod_security_evaluations_total{decision="deny"}[5m]) > 0') 개"
  echo "$(date +%F),D1,\"TenantPolicyDenied 알림 (P1 후)\",firing,\"${T_ALERT}s\",$([ "$T_ALERT" = none ] && echo FAIL || echo PASS),$T_ALERT" >> "$CSV"
else
  log "  Prometheus 없음 → 지표 감지는 건너뜀"
fi
if command -v hubble >/dev/null 2>&1; then
  log "  Cilium Hubble: tenant-b 에서 나간 DROPPED 흐름 (최근 20개)"
  hubble observe --verdict DROPPED --from-namespace "$TENANT_B" --last 20 || true
else
  log "  hubble CLI 없음 (Cilium 이 아니거나 미설치) → 네트워크 차단은 위 표의 000(타임아웃)으로만 확인"
fi

kubectl -n "$TENANT_B" delete pod attacker --now >/dev/null
echo
[ "$FAILS" -eq 0 ] && log "결과: 전부 막힘 (8/8 PASS) → $CSV" || { log "결과: 뚫린 시도 $FAILS 개 → RB-04 런북"; exit 1; }
