#!/usr/bin/env bash
# 시스템 노드에서 k3s 가 만든 kubeconfig(/etc/rancher/k3s/k3s.yaml)를 SSM 으로 가져와 ./kubeconfig 에 저장한다.
# 서버 주소가 https://127.0.0.1:6443 으로 적혀 있어서, tunnel.sh 를 켜 두면 그대로 맞는다.
# k3s 설치가 끝날 때까지(보통 부팅 후 1~2분) 알아서 기다린다.
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
TF="terraform -chdir=$HERE/terraform/cluster"
OUT="$HERE/kubeconfig"

ID=$($TF output -raw server_instance_id)
REGION=$($TF output -raw region)

echo "[kubeconfig] 1/2 SSM 에 노드가 등록되길 기다림 ($ID)"
for i in $(seq 1 60); do
  STATUS=$(aws ssm describe-instance-information --region "$REGION" \
    --filters "Key=InstanceIds,Values=$ID" \
    --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null || true)
  [ "$STATUS" = "Online" ] && break
  sleep 5
done
[ "$STATUS" = "Online" ] || { echo "SSM 등록 안 됨. README 문제 해결 표 참고"; exit 1; }

echo "[kubeconfig] 2/2 k3s.yaml 이 생기길 기다렸다가 읽음"
for i in $(seq 1 40); do
  CMD_ID=$(aws ssm send-command --region "$REGION" --instance-ids "$ID" \
    --document-name AWS-RunShellScript \
    --parameters 'commands=["cat /etc/rancher/k3s/k3s.yaml"]' \
    --query 'Command.CommandId' --output text)
  sleep 3
  STATUS=$(aws ssm get-command-invocation --region "$REGION" --command-id "$CMD_ID" --instance-id "$ID" \
    --query 'Status' --output text 2>/dev/null || true)
  if [ "$STATUS" = "Success" ]; then
    aws ssm get-command-invocation --region "$REGION" --command-id "$CMD_ID" --instance-id "$ID" \
      --query 'StandardOutputContent' --output text > "$OUT"
    chmod 600 "$OUT"
    # k3s 는 클러스터·사용자·컨텍스트 이름을 전부 default 로 만든다 → 알아보기 쉽게
    kubectl --kubeconfig "$OUT" config rename-context default poc07 >/dev/null
    echo "[kubeconfig] 저장: $OUT"
    echo "다음:  export KUBECONFIG=$OUT   (tunnel.sh 가 다른 창에서 켜져 있어야 함)"
    exit 0
  fi
  sleep 5
done
echo "k3s.yaml 을 못 읽음. 노드 안에서 확인: sudo tail -n 50 /var/log/k3s-bootstrap.log"
exit 1
