#!/usr/bin/env bash
# 로컬에 kind 클러스터를 만들고(이미 있으면 재사용) dev overlay를 적용한다.
# 필요한 것: docker, kind, kubectl.  설치: https://kind.sigs.k8s.io/docs/user/quick-start/
set -euo pipefail

CLUSTER="${CLUSTER:-finals}"   # 환경변수 CLUSTER로 이름 변경 가능

# kind get clusters 출력에 이름이 없으면 새로 만든다 (약 40초)
if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  kind create cluster --name "$CLUSTER"
fi

# kubectl이 이 클러스터를 보게 한다
kubectl config use-context "kind-$CLUSTER" >/dev/null

# kustomize로 조립한 매니페스트를 적용 (-k = kustomization.yaml이 있는 폴더)
kubectl apply -k "$(dirname "$0")/../manifests/overlays/dev"

echo "applied. next: bash scripts/smoke.sh"
