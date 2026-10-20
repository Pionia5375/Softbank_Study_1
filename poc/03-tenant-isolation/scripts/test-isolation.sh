#!/usr/bin/env bash
# 테넌트 격리 실험 (Claude 작성, 완성본).
# "A 테넌트가 B 를 못 부르고, CPU 를 다 못 먹고, B 로그를 못 본다" 를 하나씩 확인하고 표로 남긴다.
#
# 전제: tenant-a, tenant-b namespace 가 울타리(Quota·LimitRange·NetworkPolicy·RBAC·AppProject)와 함께 이미 있다.
# 사용법:
#   scripts/test-isolation.sh            # 전부
#   scripts/test-isolation.sh net        # 1) 네트워크만
#   scripts/test-isolation.sh cpu        # 2) CPU·Quota 만
#   scripts/test-isolation.sh rbac       # 3) 권한·로그만
#   scripts/test-isolation.sh argocd     # 4) Argo CD Project 만
#   KEEP=1 scripts/test-isolation.sh     # 끝나고 실험용 파드를 지우지 않음 (Hubble 로 더 보고 싶을 때)
# 결과: results/isolation-<시각>.csv  (test,expected,actual,pass,ms)
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
FIX="$HERE/fixtures"
RESULTS="$HERE/../results"
mkdir -p "$RESULTS"
CSV="$RESULTS/isolation-$(date +%Y%m%d-%H%M%S).csv"
echo "test,expected,actual,pass,ms" > "$CSV"

A=tenant-a
B=tenant-b
ONLY="${1:-all}"
PASS=0
FAIL=0

# 밀리초 시각. 맥의 date 는 %N 을 몰라서 perl 로 (맥·리눅스 둘 다 기본 설치)
now_ms() { perl -MTime::HiRes=time -e 'printf "%d\n", time*1000'; }

# 결과 한 줄 기록: record <이름> <기대> <실제> <걸린 ms>
record() {
  local name="$1" expected="$2" actual="$3" ms="$4" ok
  if [ "$expected" = "$actual" ]; then ok=PASS; PASS=$((PASS+1)); else ok=FAIL; FAIL=$((FAIL+1)); fi
  printf '  %-4s  %-48s 기대=%-8s 실제=%-8s %6sms\n' "$ok" "$name" "$expected" "$actual" "$ms"
  echo "$name,$expected,$actual,$ok,$ms" >> "$CSV"
}

need_ns() {
  for ns in "$@"; do
    kubectl get ns "$ns" >/dev/null 2>&1 || { echo "namespace $ns 가 없다. 테넌트(ApplicationSet)부터 Sync 할 것"; exit 1; }
  done
}

cleanup() {
  [ "${KEEP:-0}" = "1" ] && { echo "(KEEP=1: 실험용 파드를 남겨 둠. 지우기: kubectl delete all,pod -l poc03=fixture -n $A; 같은 걸 -n $B, -n fn-demo)"; return; }
  for ns in $A $B fn-demo; do
    kubectl -n "$ns" delete deploy,svc,pod -l poc03=fixture --ignore-not-found --wait=false >/dev/null 2>&1
  done
  kubectl -n argocd delete application iso-cross-tenant --ignore-not-found >/dev/null 2>&1
}
trap cleanup EXIT

need_ns $A $B

# ---------------------------------------------------------------------------
# 1) 네트워크: A 가 B 를 못 부른다
# ---------------------------------------------------------------------------
# curl 결과를 OK / BLOCKED 로 바꾼다. 3초 안에 응답이 없으면 BLOCKED (NetworkPolicy 는 거절이 아니라 "버림"이라 타임아웃으로 보인다)
probe() {
  local from_ns="$1" url="$2"
  if kubectl -n "$from_ns" exec iso-client -- curl -s -o /dev/null --max-time 3 "$url" >/dev/null 2>&1; then
    echo OK
  else
    echo BLOCKED
  fi
}

test_net() {
  echo "== 1) 네트워크 =="
  for ns in $A $B; do kubectl -n "$ns" apply -f "$FIX/iso-echo.yaml" >/dev/null; done
  kubectl get ns fn-demo >/dev/null 2>&1 || kubectl create ns fn-demo >/dev/null
  for ns in $A fn-demo; do kubectl -n "$ns" apply -f "$FIX/iso-client.yaml" >/dev/null; done
  for ns in $A $B; do kubectl -n "$ns" rollout status deploy/iso-echo --timeout=120s >/dev/null; done
  for ns in $A fn-demo; do kubectl -n "$ns" wait --for=condition=Ready pod/iso-client --timeout=120s >/dev/null; done

  local t0 r
  t0=$(now_ms); r=$(probe $A "http://iso-echo.$A.svc.cluster.local");      record "net: a -> a (같은 테넌트)" OK "$r" $(( $(now_ms)-t0 ))
  t0=$(now_ms); r=$(probe $A "http://iso-echo.$B.svc.cluster.local");      record "net: a -> b (다른 테넌트)" BLOCKED "$r" $(( $(now_ms)-t0 ))
  t0=$(now_ms); r=$(probe fn-demo "http://iso-echo.$B.svc.cluster.local"); record "net: fn-demo(울타리 없음) -> b" BLOCKED "$r" $(( $(now_ms)-t0 ))
  t0=$(now_ms); r=$(probe $A "https://example.com");                       record "net: a -> 인터넷(example.com)" BLOCKED "$r" $(( $(now_ms)-t0 ))
  t0=$(now_ms); r=$(probe fn-demo "http://iso-echo.$A.svc.cluster.local"); record "net: fn-demo -> a" BLOCKED "$r" $(( $(now_ms)-t0 ))

  # Hubble 로 "실제로 버려진 패킷" 을 본다. 각 노드의 Cilium 에이전트가 자기 노드 흐름만 알아서, 에이전트마다 물어본다
  echo "  -- Hubble: tenant-b 로 가다 버려진 흐름 (최근 5개씩) --"
  for p in $(kubectl -n kube-system get pods -l k8s-app=cilium -o name); do
    kubectl -n kube-system exec "$p" -c cilium-agent -- \
      hubble observe --namespace $B --verdict DROPPED --last 5 2>/dev/null | sed 's/^/  /'
  done
}

# ---------------------------------------------------------------------------
# 2) CPU·Quota: A 가 CPU 를 다 못 먹는다
# ---------------------------------------------------------------------------
# 컨테이너 안에서 cgroup 의 CPU 사용 누적값을 두 번 읽어 그 사이 평균 사용량(밀리코어)을 낸다.
# cgroup v2(최신 Docker Desktop) 와 v1 둘 다 처리. metrics-server 가 없어도 된다.
cpu_millicores() {
  local ns="$1" pod="$2" secs="${3:-10}"
  kubectl -n "$ns" exec "$pod" -- sh -c '
    read_us() {
      if [ -f /sys/fs/cgroup/cpu.stat ]; then awk "/^usage_usec/{print \$2}" /sys/fs/cgroup/cpu.stat
      elif [ -f /sys/fs/cgroup/cpuacct/cpuacct.usage ]; then echo $(( $(cat /sys/fs/cgroup/cpuacct/cpuacct.usage) / 1000 ))
      else echo $(( $(cat /sys/fs/cgroup/cpu,cpuacct/cpuacct.usage) / 1000 )); fi
    }
    a=$(read_us); sleep '"$secs"'; b=$(read_us)
    echo $(( (b - a) / '"$secs"' / 1000 ))'
}

test_cpu() {
  echo "== 2) CPU·Quota =="
  local t0 out r

  # 2-1) 컨테이너 하나가 2코어 요청 → LimitRange max(1코어)에 걸려 거절. dry-run 이라 실제로는 아무것도 안 생긴다
  t0=$(now_ms)
  out=$(kubectl -n $A apply --dry-run=server -f "$FIX/too-big.yaml" 2>&1)
  if echo "$out" | grep -qi "maximum cpu"; then r=REJECTED; else r=ACCEPTED; fi
  record "cpu: 컨테이너 1개가 2코어 요청" REJECTED "$r" $(( $(now_ms)-t0 ))
  echo "$out" | sed 's/^/    /' | head -2

  # 2-2) 30개 복제를 요청 → Quota(pods·limits.cpu) 만큼만 생긴다
  t0=$(now_ms)
  kubectl -n $A create deployment iso-burst --image=busybox:1.36 --replicas=30 -- sleep 3600 >/dev/null
  kubectl -n $A label deployment iso-burst poc03=fixture >/dev/null
  # 파드 템플릿에 보안 설정 추가 (baseline 은 없어도 통과하지만 restricted 경고를 줄이려고)
  kubectl -n $A patch deployment iso-burst --type=json -p='[
    {"op":"add","path":"/spec/template/spec/securityContext","value":{"runAsNonRoot":true,"runAsUser":65532,"seccompProfile":{"type":"RuntimeDefault"}}},
    {"op":"add","path":"/spec/template/spec/containers/0/securityContext","value":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}}}
  ]' >/dev/null
  sleep 20
  local created
  created=$(kubectl -n $A get pods -l app=iso-burst --no-headers 2>/dev/null | wc -l | tr -d ' ')
  if [ "$created" -lt 30 ]; then r=CAPPED; else r=UNCAPPED; fi
  record "quota: 30개 요청 → 생성 ${created}개" CAPPED "$r" $(( $(now_ms)-t0 ))
  kubectl -n $A get events --field-selector reason=FailedCreate -o custom-columns=MSG:.message --no-headers 2>/dev/null \
    | grep -m1 "exceeded quota" | cut -c1-160 | sed 's/^/    /'
  kubectl -n $A describe resourcequota tenant-quota | sed -n '/Resource/,$p' | sed 's/^/    /'
  kubectl -n $A delete deployment iso-burst --wait=true >/dev/null

  # 2-3) 무한 루프 파드 → LimitRange 기본 limits(200m)로 묶여서 1코어 넘게 못 쓴다
  kubectl -n $A apply -f "$FIX/iso-hog.yaml" >/dev/null
  kubectl -n $A wait --for=condition=Ready pod/iso-hog --timeout=120s >/dev/null
  local lim used
  lim=$(kubectl -n $A get pod iso-hog -o jsonpath='{.spec.containers[0].resources.limits.cpu}')
  echo "    iso-hog 에 자동으로 붙은 limits.cpu = $lim"
  t0=$(now_ms)
  used=$(cpu_millicores $A iso-hog 10)
  echo "    iso-hog 실제 사용량(10초 평균) = ${used}m"
  echo "hog_cpu_millicores,,$used,,," >> "$CSV"
  # limits 의 120% 미만이면 묶인 것으로 본다 (측정 오차 여유)
  local lim_m=${lim%m}; [ "$lim_m" = "$lim" ] && lim_m=$((lim*1000))
  if [ "$used" -lt $(( lim_m * 12 / 10 )) ]; then r=THROTTLED; else r=FREE; fi
  record "cpu: 무한 루프가 limits 안에 묶임" THROTTLED "$r" $(( $(now_ms)-t0 ))
  kubectl -n $A delete pod iso-hog --wait=false >/dev/null
}

# ---------------------------------------------------------------------------
# 3) 권한: A 사람·봇이 B 로그를 못 본다
# ---------------------------------------------------------------------------
# --as / --as-group = "관리자인 내가 이 사람인 척" (impersonation). 실제 로그인 없이 권한만 시험한다
can() { kubectl auth can-i "$@" 2>/dev/null | head -1; }

test_rbac() {
  echo "== 3) 권한·로그 =="
  local ALICE=(--as=alice --as-group=tenant-a-developers)
  local BOT=("--as=system:serviceaccount:$A:deployer")
  local t0
  t0=$(now_ms); record "rbac: alice 가 a 로그 보기"        yes "$(can get pods/log -n $A "${ALICE[@]}")" $(( $(now_ms)-t0 ))
  t0=$(now_ms); record "rbac: alice 가 b 로그 보기"        no  "$(can get pods/log -n $B "${ALICE[@]}")" $(( $(now_ms)-t0 ))
  t0=$(now_ms); record "rbac: alice 가 b 파드 목록"        no  "$(can list pods -n $B "${ALICE[@]}")" $(( $(now_ms)-t0 ))
  t0=$(now_ms); record "rbac: alice 가 a Quota 수정"       no  "$(can update resourcequotas -n $A "${ALICE[@]}")" $(( $(now_ms)-t0 ))
  t0=$(now_ms); record "rbac: alice 가 a NetworkPolicy 삭제" no "$(can delete networkpolicies -n $A "${ALICE[@]}")" $(( $(now_ms)-t0 ))
  t0=$(now_ms); record "rbac: alice 가 a secrets 읽기"     no  "$(can get secrets -n $A "${ALICE[@]}")" $(( $(now_ms)-t0 ))
  t0=$(now_ms); record "rbac: 봇(a:deployer)이 a 배포"     yes "$(can create deployments -n $A "${BOT[@]}")" $(( $(now_ms)-t0 ))
  t0=$(now_ms); record "rbac: 봇(a:deployer)이 b 로그"     no  "$(can get pods/log -n $B "${BOT[@]}")" $(( $(now_ms)-t0 ))

  # 실제 kubectl logs 도 한 번 시도해서 에러 문구를 보여 준다
  if kubectl -n $B get deploy iso-echo >/dev/null 2>&1; then
    echo "    실제 시도: kubectl logs -n $B deploy/iso-echo --as=alice --as-group=tenant-a-developers"
    kubectl logs -n $B deploy/iso-echo "${ALICE[@]}" 2>&1 | head -1 | cut -c1-160 | sed 's/^/    /'
  fi
}

# ---------------------------------------------------------------------------
# 4) Argo CD: tenant-a Project 로는 tenant-b 에 배포 못 한다
# ---------------------------------------------------------------------------
test_argocd() {
  echo "== 4) Argo CD Project =="
  kubectl -n argocd get appproject $A >/dev/null 2>&1 || { echo "  AppProject $A 가 없다. 건너뜀"; return; }
  local t0 msg r
  t0=$(now_ms)
  kubectl apply -f "$FIX/cross-tenant-app.yaml" >/dev/null
  msg=""
  for _ in $(seq 1 30); do
    msg=$(kubectl -n argocd get application iso-cross-tenant -o jsonpath='{.status.conditions[*].message}' 2>/dev/null)
    [ -n "$msg" ] && break
    sleep 1
  done
  if echo "$msg" | grep -qi "not permitted"; then r=DENIED; else r=ALLOWED; fi
  record "argocd: tenant-a Project → tenant-b 배포" DENIED "$r" $(( $(now_ms)-t0 ))
  echo "    $msg" | cut -c1-200
}

case "$ONLY" in
  net) test_net ;;
  cpu) test_cpu ;;
  rbac) kubectl -n $B apply -f "$FIX/iso-echo.yaml" >/dev/null; kubectl -n $B rollout status deploy/iso-echo --timeout=120s >/dev/null; test_rbac ;;
  argocd) test_argocd ;;
  all) test_net; test_cpu; test_rbac; test_argocd ;;
  *) echo "사용법: $0 [all|net|cpu|rbac|argocd]"; exit 2 ;;
esac

echo
echo "합계: PASS $PASS / FAIL $FAIL   →  $CSV"
[ "$FAIL" -eq 0 ]
