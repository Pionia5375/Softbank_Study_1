#!/usr/bin/env bash
# 드릴 클러스터의 UI 3개를 맥 포트로 끌어온다. Claude 작성, 완성본. Ctrl-C 로 전부 끝난다.
#   Argo CD    http://localhost:8080   (admin / 아래 출력되는 비밀번호)
#   Grafana    http://localhost:3000   (admin / admin)
#   Prometheus http://localhost:9090   (Alerts 탭, Status → Targets)
# port-forward = "맥의 이 포트로 온 걸 클러스터 안 이 Service 로 넘겨라". 터미널을 닫으면 끊긴다.
set -uo pipefail
CTX="${CTX:-kind-prep}"
kubectl config use-context "$CTX" >/dev/null

echo "Argo CD admin 비밀번호 (초기값, Secret 에 들어 있다):"
echo "  $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
echo

kubectl -n argocd     port-forward svc/argocd-server   8080:80   >/dev/null 2>&1 &
kubectl -n monitoring port-forward svc/kps-grafana     3000:80   >/dev/null 2>&1 &
kubectl -n monitoring port-forward svc/kps-prometheus  9090:9090 >/dev/null 2>&1 &
trap 'kill 0' EXIT INT TERM     # 이 스크립트가 끝나면 자식(port-forward 3개)도 같이 끝낸다

echo "열림: Argo CD http://localhost:8080 · Grafana http://localhost:3000 (admin/admin) · Prometheus http://localhost:9090"
echo "podinfo 는 port-forward 없이 http://localhost:9898 (kind extraPortMappings)"
echo "끝내기: Ctrl-C"
wait
