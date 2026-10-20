#!/usr/bin/env bash
# EC2 k3s 위에 Argo CD 를 깔고 root-ec2 Application 하나를 넣는다. 나머지는 Git 에서 따라온다.
#   ./scripts/bootstrap-argocd.sh             Jeong 이 채운 파일로
#   ./scripts/bootstrap-argocd.sh --solution  정답본으로
# 1단계와 같은 차트·버전·values 를 쓰고, EC2 에서 다른 점(노드 배치)만 argocd-values-k3s.yaml 로 덧씌운다.
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
REPO=$(cd "$HERE/../.." && pwd)
CHART_VERSION=${CHART_VERSION:-10.10.5}   # 1단계와 같게 (poc/01-argocd/README 9절)

if [ "${1:-}" = "--solution" ]; then
  BASE="$REPO/poc/01-argocd/solution/platform/argocd/values.yaml"
  K3S="$HERE/solution/gitops/bootstrap/argocd-values-k3s.yaml"
  ROOT="$HERE/solution/gitops/bootstrap/root-app.yaml"
else
  BASE="$REPO/poc/01-argocd/platform/argocd/values.yaml"
  K3S="$HERE/gitops/bootstrap/argocd-values-k3s.yaml"
  ROOT="$HERE/gitops/bootstrap/root-app.yaml"
fi

# 빈칸이 남아 있으면 멈춘다
if grep -n '___' "$BASE" "$K3S" "$ROOT"; then
  echo "위 파일에 빈칸(___)이 남아 있다. 채우거나 --solution 으로 실행"; exit 1
fi

kubectl get nodes >/dev/null || { echo "kubectl 이 클러스터에 안 붙는다. tunnel.sh 와 KUBECONFIG 확인"; exit 1; }

helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update argo >/dev/null

echo "[argocd] helm install (차트 $CHART_VERSION)"
helm upgrade --install argocd argo/argo-cd --version "$CHART_VERSION" \
  -n argocd --create-namespace \
  -f "$BASE" -f "$K3S" \
  --wait --timeout 10m

echo "[argocd] root Application 적용: $ROOT"
kubectl apply -f "$ROOT"
echo "확인: kubectl -n argocd get applications -w"
