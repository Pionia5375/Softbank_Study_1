#!/usr/bin/env bash
# k3s 를 "진짜 노드 2대" 에 손으로 세우는 것을 스크립트로. Claude 작성, 완성본. 설명: 01-cluster-boot.md 4절.
# multipass = 맥에서 Ubuntu VM 을 한 줄로 띄우는 도구 (brew install --cask multipass).
# VM 2대 = EC2 2대라고 생각하면 된다. 여기서 치는 명령이 poc/07-ec2-k3s/k3s/install.sh.tftpl(user_data) 가 EC2 안에서 치는 것과 같다.
#
#   사용법: starter-pack/infra-prep/scripts/k3s-multipass.sh          server 1 + agent 1 만들고 묶고 시간 재기
#           starter-pack/infra-prep/scripts/k3s-multipass.sh delete   VM 2대 삭제
#   처음엔 이 스크립트를 돌리지 말고, 01-cluster-boot.md 4절의 순서대로 한 줄씩 직접 친다. 두 번째부터 스크립트.
# 문서: https://docs.k3s.io/quick-start , https://docs.k3s.io/installation/configuration
set -euo pipefail
SERVER=k3s-server
AGENT=k3s-agent
KCFG="$HOME/.kube/k3s-multipass.yaml"

if [ "${1:-}" = "delete" ]; then
  t=$(date +%s)
  multipass delete --purge "$SERVER" "$AGENT" 2>/dev/null || true
  rm -f "$KCFG"
  echo "삭제 $(( $(date +%s) - t ))s"; exit 0
fi

command -v multipass >/dev/null || { echo "multipass 없음: brew install --cask multipass"; exit 1; }
START=$(date +%s)
step() { echo "[$(( $(date +%s) - START ))s] $*"; }

step "1/6 VM 2대 생성 (Ubuntu 24.04, 2 CPU, 2GB, 10GB 디스크씩). 첫 실행은 이미지 다운로드로 길다"
multipass launch 24.04 --name "$SERVER" --cpus 2 --memory 2G --disk 10G
multipass launch 24.04 --name "$AGENT"  --cpus 2 --memory 2G --disk 10G
multipass list

step "2/6 server 에 k3s 설치 (공식 설치 스크립트: 바이너리 받기 + systemd 서비스 k3s 등록 + 시작)"
# sh -s - server ... : 설치 스크립트에 "server 로 설치하라" 와 k3s 옵션을 넘긴다
#   --write-kubeconfig-mode 644 : /etc/rancher/k3s/k3s.yaml 을 root 아닌 사용자도 읽게 (실습 편의. poc/07 은 0600)
#   --node-label pool=system    : 노드 라벨. poc/07 server-config.yaml 과 같은 의미
multipass exec "$SERVER" -- bash -c \
  'curl -sfL https://get.k3s.io | sh -s - server --write-kubeconfig-mode 644 --node-label pool=system'

step "3/6 server 의 토큰과 IP 읽기 (agent 가 붙을 때 이 둘이 필요하다)"
TOKEN=$(multipass exec "$SERVER" -- sudo cat /var/lib/rancher/k3s/server/node-token)
IP=$(multipass info "$SERVER" | awk '/IPv4/{print $2; exit}')
echo "  server IP $IP, 토큰 ${TOKEN:0:12}... (뒤는 생략)"

step "4/6 agent 에 k3s 설치 + server 에 붙이기 (K3S_URL 과 K3S_TOKEN 두 환경변수가 'agent 모드' 를 뜻한다)"
multipass exec "$AGENT" -- bash -c \
  "curl -sfL https://get.k3s.io | K3S_URL=https://$IP:6443 K3S_TOKEN=$TOKEN sh -s - agent --node-label pool=exec"

step "5/6 kubeconfig 를 맥으로 가져오기 (server 의 127.0.0.1 을 VM IP 로 바꿔야 맥에서 닿는다)"
mkdir -p "$HOME/.kube"
multipass exec "$SERVER" -- cat /etc/rancher/k3s/k3s.yaml | sed "s/127.0.0.1/$IP/" > "$KCFG"
chmod 600 "$KCFG"

step "6/6 확인: 노드 2대 Ready"
export KUBECONFIG="$KCFG"
for i in $(seq 1 30); do
  n=$(kubectl get nodes --no-headers 2>/dev/null | grep -c ' Ready' || true)
  [ "$n" -ge 2 ] && break; sleep 3
done
kubectl get nodes -o wide -L pool
echo
echo "k3s 가 기본으로 깔아 둔 것 (coredns, traefik, metrics-server, local-path, servicelb):"
kubectl -n kube-system get pods
echo
echo "총 $(( $(date +%s) - START ))s. results/drill.md 의 k3s 칸에 적기"
echo "이 클러스터를 쓰려면:  export KUBECONFIG=$KCFG"
echo "원래대로(kind 등):     unset KUBECONFIG"
echo "지우기:                $0 delete"
