#!/usr/bin/env bash
# k3d 로 k3s 클러스터를 Docker 안에 띄운다 (k3s 빠른 길). Claude 작성, 완성본. 설명: 01-cluster-boot.md 3절.
# k3d = "k3s in Docker". kind 와 겉모양은 같지만(노드 = 컨테이너) 안에서 도는 쿠버네티스가 k3s 다.
#   사용법: starter-pack/infra-prep/scripts/k3d-boot.sh          만들고 시간 재기
#           starter-pack/infra-prep/scripts/k3d-boot.sh delete   지우기
# 문서: https://k3d.io/stable/usage/commands/k3d_cluster_create/
set -euo pipefail
NAME=prep-k3d

if [ "${1:-}" = "delete" ]; then
  t=$(date +%s); k3d cluster delete "$NAME"; echo "삭제 $(( $(date +%s) - t ))s"; exit 0
fi

command -v k3d >/dev/null || { echo "k3d 없음: brew install k3d"; exit 1; }
START=$(date +%s)

# --servers 1 --agents 2  : k3s 의 server(=컨트롤 플레인+etcd 대신 SQLite) 1대, agent(=워커) 2대
# -p "9899:80@loadbalancer": 맥 9899 → k3d 가 앞에 세우는 작은 로드밸런서 → 노드들의 80 (k3s 기본 Traefik 인그레스)
# --k3s-arg "--disable=traefik@server:0": 드릴과 비교하려고 k3s 기본 Traefik 은 끈다 (@server:0 = 첫 서버 노드에만 이 인자)
#   끄지 않으면 k3s 가 Traefik 인그레스 컨트롤러를 알아서 깐다. 이게 k3s 의 "배터리 포함" 성격이다
k3d cluster create "$NAME" --servers 1 --agents 2 \
  -p "9899:80@loadbalancer" \
  --k3s-arg "--disable=traefik@server:0" \
  --wait
echo "[$(( $(date +%s) - START ))s] 클러스터 생성 끝"

kubectl config use-context "k3d-$NAME" >/dev/null
kubectl wait --for=condition=Ready nodes --all --timeout=120s
echo "[$(( $(date +%s) - START ))s] 노드 3개 Ready"
kubectl get nodes -o wide
echo
echo "k3s 가 기본으로 깔아 둔 것 (kind 엔 없다):"
kubectl -n kube-system get pods
echo
echo "총 $(( $(date +%s) - START ))s. 비교: 드릴 1/5 단계(kind 생성) 시간과 나란히 results/drill.md 에 적기"
echo "지우기: $0 delete   (kind-prep 과 메모리를 나눠 쓰니 비교 끝나면 바로)"
