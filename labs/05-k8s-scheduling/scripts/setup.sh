#!/usr/bin/env bash
# 셋업 드릴: 클러스터 생성부터 hello 응답까지 한 번에. 단계별 시간과 총 시간을 찍는다.
# 쓰는 법: scripts/setup.sh            (labs/05-k8s-scheduling 에서)
# 전제: Docker Desktop 켜짐, lab01-hello:multi 이미지가 맥에 있음, helm repo traefik / metrics-server 추가돼 있음
set -eu
t0=$(date +%s)
lap() { echo "[$(( $(date +%s) - t0 ))s] $*"; }

lap "1/5 kind 클러스터 생성 (노드 3개)"
kind create cluster --config kind-config.yaml

lap "2/5 앱 이미지 넣기"
kind load docker-image lab01-hello:multi --name lab05

lap "3/5 Traefik (Ingress 컨트롤러, NodePort 30080)"
helm upgrade --install traefik traefik/traefik -n traefik --create-namespace -f traefik-values.yaml --wait

lap "4/5 metrics-server (kubectl top, HPA 용)"
helm upgrade --install metrics-server metrics-server/metrics-server -n kube-system \
  --set 'args={--kubelet-insecure-tls}' --wait

lap "5/5 hello 앱"
kubectl apply -f k8s/priorityclasses.yaml
helm upgrade --install hello chart/hello -f chart/hello/values-demo.yaml --wait

until curl -sf localhost:8088/hello >/dev/null; do sleep 1; done
lap "완료: curl localhost:8088/hello 응답"
curl -s localhost:8088/hello; echo
kubectl get nodes -L tier
kubectl get pods -o wide
