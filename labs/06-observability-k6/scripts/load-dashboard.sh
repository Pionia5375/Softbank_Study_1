#!/usr/bin/env bash
# dashboards/hello-dashboard.json 을 ConfigMap 으로 만들어 grafana_dashboard=1 라벨을 붙인다.
# Grafana 옆의 sidecar 컨테이너가 이 라벨을 보고 1분 안에 대시보드를 자동으로 올린다 (화면에서 Import 안 해도 됨).
# JSON 을 고친 뒤 다시 실행하면 덮어쓴다.
set -eu
cd "$(dirname "$0")/.."
# --dry-run=client -o yaml | kubectl apply = "있으면 고치고 없으면 만든다"
kubectl -n monitoring create configmap hello-dashboard \
  --from-file=hello-dashboard.json=dashboards/hello-dashboard.json \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n monitoring label configmap hello-dashboard grafana_dashboard=1 --overwrite
echo "Grafana > Dashboards 에서 'Lab 06 hello' 를 찾는다 (늦으면 1분 기다리기)"
