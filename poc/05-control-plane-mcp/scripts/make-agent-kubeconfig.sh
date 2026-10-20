#!/usr/bin/env bash
# MCP 서버가 쓸 kubeconfig 를 만든다 (Claude 작성, 완성본).
# 관리자 kubeconfig 를 에이전트에게 주지 않으려고, ops-agent ServiceAccount 토큰만 든 파일을 따로 만든다.
#   사용: scripts/make-agent-kubeconfig.sh [tenant] [유효시간]   (기본 tenant-a, 8h)
#   결과: ~/.ops-mcp/kubeconfig-<tenant>
set -euo pipefail
TENANT=${1:-tenant-a}
DURATION=${2:-8h}
OUT="$HOME/.ops-mcp/kubeconfig-$TENANT"
mkdir -p "$(dirname "$OUT")"

# 지금 kubectl 이 보는 클러스터 주소와 CA 인증서 (kind-faas)
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CA=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
# 짧게 사는 토큰 발급 (TokenRequest API). 시간이 지나면 저절로 무효
TOKEN=$(kubectl -n "$TENANT" create token ops-agent --duration="$DURATION")

cat > "$OUT" <<YAML
apiVersion: v1
kind: Config
clusters:
  - name: faas
    cluster:
      server: $SERVER
      certificate-authority-data: $CA
users:
  - name: ops-agent
    user:
      token: $TOKEN
contexts:
  - name: ops-agent@$TENANT
    context:
      cluster: faas
      user: ops-agent
      namespace: $TENANT
current-context: ops-agent@$TENANT
YAML
chmod 600 "$OUT"
echo "만듦: $OUT  (유효 $DURATION)"
echo "확인: kubectl --kubeconfig $OUT auth can-i --list -n $TENANT"
