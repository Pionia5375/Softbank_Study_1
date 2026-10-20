#!/usr/bin/env bash
# 셋업 드릴: 빈 맥에서 "함수 배포 직전" 까지 한 번에 (Claude 작성, 완성본).
# = 3단계 rebuild-cluster.sh 와 같은 순서인데, kind 설정만 이 단계 것(노드 풀 taint + 8081 포트)으로 바꾸고
#   마지막에 이 단계 setup.sh(레지스트리·Knative·Kourier·gVisor)를 붙였다.
# 단계마다 [N초] 를 찍는다. 마지막 줄의 총 시간을 README 측정표에 적는다.
#
# 미리 깔 것 (맥): brew install kind kubectl helm cilium-cli
# 사용법 (레포 루트에서): poc/04-faas-runtime/scripts/rebuild-cluster.sh
#   3단계를 안 하고 kindnet 으로 갈 때: NO_CILIUM=1 poc/04-faas-runtime/scripts/rebuild-cluster.sh
#     (그때는 cluster/kind-config.yaml 의 disableDefaultCNI 를 false 로)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
CILIUM_VERSION="${CILIUM_VERSION:-1.20.3}"          # 3단계와 같은 값
ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-10.10.5}"   # 1단계와 같은 값

START=$(date +%s)
step() { echo "[$(( $(date +%s) - START ))s] $*"; }

step "1/6 옛 클러스터 faas 삭제"
kind delete cluster --name faas

step "2/6 새 클러스터 (노드 풀 라벨 + taint)"
kind create cluster --config "$ROOT/poc/04-faas-runtime/cluster/kind-config.yaml"
kubectl get nodes -L pool

if [ "${NO_CILIUM:-0}" != "1" ]; then
  step "3/6 Cilium + Hubble (3단계와 같음)"
  cilium install --version "$CILIUM_VERSION"
  cilium status --wait --wait-duration 5m
  cilium hubble enable --ui
  cilium status --wait --wait-duration 5m
else
  step "3/6 Cilium 건너뜀 (kindnet)"
fi
kubectl wait --for=condition=Ready nodes --all --timeout=180s

step "4/6 Argo CD (1단계와 같은 차트·values) → system 풀에 뜬다"
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update argo >/dev/null
helm install argocd argo/argo-cd --version "$ARGOCD_CHART_VERSION" -n argocd --create-namespace \
  -f "$ROOT/poc/01-argocd/platform/argocd/values.yaml" --wait
kubectl apply -f "$ROOT/poc/01-argocd/gitops/root.yaml"

step "5/6 레지스트리 + Knative + Kourier + gVisor (이 단계 setup.sh)"
"$ROOT/poc/04-faas-runtime/scripts/setup.sh"

step "6/6 Jeong 이 쓴 설정 3개 (기능 플래그, RuntimeClass, 함수 Application)"
kubectl -n knative-serving patch configmap config-features --type merge \
  --patch-file "$ROOT/poc/04-faas-runtime/platform/knative/config-features-patch.yaml"
kubectl apply -f "$ROOT/poc/04-faas-runtime/platform/runtimeclass-gvisor.yaml"
"$ROOT/poc/04-faas-runtime/scripts/build.sh" v1
kubectl apply -f "$ROOT/poc/04-faas-runtime/gitops/faas-functions.yaml"

step "총 $(( $(date +%s) - START ))초"
