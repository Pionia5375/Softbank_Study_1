#!/usr/bin/env bash
# 10/27 측정 기록기. 결과는 results/times.csv 에 한 줄씩 쌓인다 (날짜, 단계, 초, 메모).
#   ./scripts/measure.sh up [terraform 추가 인자]   terraform apply 시간
#   ./scripts/measure.sh ready [노드 수, 기본 4]    apply 끝 → 노드 전부 Ready 까지 (apply 직후 바로 실행)
#   ./scripts/measure.sh argo                       root 적용 → 모든 Application Synced+Healthy 까지
#   ./scripts/measure.sh spot [함수 URL]             FIS 로 스팟 1대 회수 → cordon / 파드 이동 / 교체 노드 Ready 시간 + 실패 요청 수
#   ./scripts/measure.sh down                       terraform destroy 시간
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
TF_DIR="$HERE/terraform/cluster"
CSV="$HERE/results/times.csv"
[ -f "$CSV" ] || echo "date,step,seconds,note" > "$CSV"

now() { date +%s; }
record() { echo "$(date +%Y-%m-%dT%H:%M:%S),$1,$2,$3" | tee -a "$CSV"; }
ready_count() { kubectl get nodes --no-headers 2>/dev/null | awk '$2=="Ready"' | wc -l | tr -d ' '; }

case "${1:-}" in
  up)
    shift
    t0=$(now)
    terraform -chdir="$TF_DIR" apply -auto-approve "$@"
    record apply $(( $(now) - t0 )) "terraform apply"
    ;;

  ready)
    want=${2:-4}   # 시스템 1 + 실행 2 + 빌드 1
    t0=$(now)
    until [ "$(ready_count)" -ge "$want" ]; do
      [ $(( $(now) - t0 )) -gt 900 ] && { echo "15분 넘음. 노드 로그 확인"; exit 1; }
      sleep 5
    done
    record nodes_ready $(( $(now) - t0 )) "$want nodes Ready ($(kubectl version -o json | jq -r .serverVersion.gitVersion))"
    ;;

  argo)
    t0=$(now)
    until kubectl -n argocd get applications -o json 2>/dev/null | jq -e '
        (.items | length) >= 3 and
        all(.items[]; .status.sync.status == "Synced" and .status.health.status == "Healthy")' >/dev/null; do
      [ $(( $(now) - t0 )) -gt 900 ] && { kubectl -n argocd get applications; exit 1; }
      sleep 5
    done
    record argo_synced $(( $(now) - t0 )) "$(kubectl -n argocd get applications --no-headers | wc -l | tr -d ' ') apps Synced+Healthy"
    ;;

  spot)
    URL=${2:-}
    TEMPLATE=$(terraform -chdir="$TF_DIR" output -raw fis_template_id)
    REGION=$(terraform -chdir="$TF_DIR" output -raw region)
    [ -n "$TEMPLATE" ] || { echo "enable_fis=false 로 만들어졌다"; exit 1; }
    exec_before=$(kubectl get nodes -l pool=exec --no-headers | awk '$2=="Ready"' | wc -l | tr -d ' ')

    # 함수 URL 을 주면 0.5초마다 호출해서 실패 수를 센다
    if [ -n "$URL" ]; then
      ( ok=0; fail=0; end=$(( $(now) + 600 ))
        while [ "$(now)" -lt "$end" ] && [ ! -f "$HERE/results/.stop" ]; do
          if curl -sf -m 2 -o /dev/null "$URL"; then ok=$((ok+1)); else fail=$((fail+1)); fi
          sleep 0.5
        done
        echo "$ok $fail" > "$HERE/results/.curl" ) &
      CURL_PID=$!
    fi

    t0=$(now)
    EXP=$(aws fis start-experiment --region "$REGION" --experiment-template-id "$TEMPLATE" \
      --query 'experiment.id' --output text)
    echo "[spot] 실험 $EXP 시작. 2분 경고 → NTH drain → 회수 → ASG 교체 순서로 진행"

    until kubectl get nodes -l pool=exec --no-headers | grep -q SchedulingDisabled; do
      [ $(( $(now) - t0 )) -gt 300 ] && { echo "5분 동안 cordon 이 안 됨. NTH 파드 로그 확인"; break; }
      sleep 2
    done
    record spot_cordon $(( $(now) - t0 )) "경고 → 노드 cordon (NTH)"
    VICTIM=$(kubectl get nodes -l pool=exec --no-headers | awk '/SchedulingDisabled/{print $1; exit}')
    echo "[spot] 회수 대상 노드: ${VICTIM:-알 수 없음}"

    # k3s 에는 AWS 클라우드 컨트롤러가 없어서, 꺼진 노드 오브젝트가 NotReady 로 계속 남는다.
    # 그래서 "노드가 사라짐" 이 아니라 "fn-sample 파드 2개가 회수 대상이 아닌 노드에서 Ready" 를 본다.
    until [ "$(kubectl -n placement-check get deploy fn-sample -o jsonpath='{.status.readyReplicas}')" = "2" ] &&
          ! kubectl -n placement-check get pods -l app=fn-sample -o jsonpath='{.items[*].spec.nodeName}' | grep -qw "${VICTIM:-none}"; do
      [ $(( $(now) - t0 )) -gt 900 ] && break
      sleep 2
    done
    record spot_pods_moved $(( $(now) - t0 )) "fn-sample 2개가 다른 노드에서 Ready"

    until [ "$(kubectl get nodes -l pool=exec --no-headers | awk '$2=="Ready"' | wc -l | tr -d ' ')" -ge "$exec_before" ]; do
      [ $(( $(now) - t0 )) -gt 900 ] && break
      sleep 5
    done
    record spot_replaced $(( $(now) - t0 )) "실행 노드 수 $exec_before 대 복구 (ASG 교체)"

    if [ -n "${CURL_PID:-}" ]; then
      touch "$HERE/results/.stop"; wait "$CURL_PID" || true; rm -f "$HERE/results/.stop"
      read -r ok fail < "$HERE/results/.curl"; rm -f "$HERE/results/.curl"
      record spot_requests "$fail" "실패 요청 수 (성공 $ok)"
    fi
    echo "죽은 노드 정리: kubectl get nodes 에서 NotReady 로 남은 이름을 kubectl delete node <이름>"
    ;;

  down)
    t0=$(now)
    terraform -chdir="$TF_DIR" destroy -auto-approve
    record destroy $(( $(now) - t0 )) "terraform destroy"
    ;;

  *)
    sed -n '2,8p' "$0"; exit 1 ;;
esac
