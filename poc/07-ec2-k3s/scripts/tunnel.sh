#!/usr/bin/env bash
# 맥의 localhost:6443 을 시스템 노드(k3s server)의 localhost:6443 으로 잇는다. SSM Session Manager 사용.
# 6443 포트를 인터넷에 열지 않고도 kubectl 이 된다. 이 터미널 창은 켜 둔 채로, 다른 창에서 kubectl 을 쓴다.
# 필요: aws CLI v2 + session-manager-plugin (README 0절)
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
TF="terraform -chdir=$HERE/terraform/cluster"

ID=$($TF output -raw server_instance_id)
REGION=$($TF output -raw region)
LOCAL_PORT=${LOCAL_PORT:-6443}

echo "[tunnel] localhost:$LOCAL_PORT -> $ID:6443 ($REGION). Ctrl+C 로 끊는다"
aws ssm start-session --region "$REGION" --target "$ID" \
  --document-name AWS-StartPortForwardingSession \
  --parameters "{\"portNumber\":[\"6443\"],\"localPortNumber\":[\"$LOCAL_PORT\"]}"
