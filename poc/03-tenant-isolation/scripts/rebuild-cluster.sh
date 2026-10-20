#!/usr/bin/env bash
# 클러스터 재생성 + Cilium + Hubble + Argo CD 재설치 (Claude 작성, 완성본).
# 왜 다시 만드나: CNI(파드 네트워크 플러그인)는 클러스터를 만들 때만 고를 수 있다. kindnet → Cilium 으로 바꾸려면 통째로 새로.
# 단계마다 [N초] 를 찍는다 = 셋업 드릴 기록. 마지막 줄의 총 시간을 README 측정표에 적는다.
#
# 미리 깔 것 (맥): brew install kind kubectl helm cilium-cli    (hubble CLI 는 선택: brew install hubble)
# 사용법 (레포 루트에서): poc/03-tenant-isolation/scripts/rebuild-cluster.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
CILIUM_VERSION="${CILIUM_VERSION:-1.20.3}"
ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-10.10.5}"

START=$(date +%s)
step() { echo "[$(( $(date +%s) - START ))s] $*"; }

step "1/6 옛 클러스터 faas 삭제 (없으면 그냥 넘어감)"
kind delete cluster --name faas

step "2/6 새 클러스터 생성 (kindnet 없음, 워커 3대)"
kind create cluster --config "$ROOT/poc/03-tenant-isolation/cluster/kind-config.yaml"
# 이 시점에 노드는 NotReady 가 정상 (파드 네트워크가 아직 없다)
kubectl get nodes

step "3/6 Cilium 설치 (cilium CLI 가 kind 인 걸 알아보고 맞는 설정을 고른다)"
cilium install --version "$CILIUM_VERSION"
cilium status --wait --wait-duration 5m

step "4/6 Hubble 켜기 (relay + UI). 노드마다 흩어진 흐름 기록을 한곳에 모아 보여 준다"
cilium hubble enable --ui
cilium status --wait --wait-duration 5m

step "5/6 Argo CD 재설치 (01 단계와 같은 차트·values)"
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update argo >/dev/null
helm install argocd argo/argo-cd --version "$ARGOCD_CHART_VERSION" -n argocd --create-namespace \
  -f "$ROOT/poc/01-argocd/platform/argocd/values.yaml" --wait

step "6/6 App of Apps 의 root 붙이기 → hello-fn 등은 Git 에서 자동으로 돌아온다"
kubectl apply -f "$ROOT/poc/01-argocd/gitops/root.yaml"

step "끝. 노드 상태:"
kubectl get nodes -L pool
echo "총 $(( $(date +%s) - START ))초"
