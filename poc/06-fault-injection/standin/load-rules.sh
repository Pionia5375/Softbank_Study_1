#!/usr/bin/env bash
# 대역 Prometheus(Helm 없이 띄운 것)에 알림 규칙을 넣는다 (Claude 작성).
# defenses/prometheus-alerts-values.yaml 의 serverFiles.alerting_rules.yml 아래(groups:)가 Prometheus 규칙 파일 형식과
# 똑같다는 점을 이용해 그 부분만 잘라 ConfigMap 으로 만든다.
#   ./standin/load-rules.sh defenses/prometheus-alerts-values.yaml
# 진짜 클러스터(2단계 Prometheus 차트)에선 이 스크립트 대신 helm upgrade -f 로 같은 파일을 넣는다 (README 3절).
set -euo pipefail
F="${1:-defenses/prometheus-alerts-values.yaml}"
TMP=$(mktemp)
# "  alerting_rules.yml:" 다음 줄부터, 들여쓰기가 4칸보다 얕아지기 전까지. 앞의 4칸을 뺀다
awk 'f && $0 !~ /^ *$/ && $0 !~ /^ *#/ { match($0, /^ */); if (RLENGTH < 4) f = 0 }
     f { sub(/^    /, ""); print }
     /^  alerting_rules\.yml:/ { f = 1 }' "$F" > "$TMP"
grep -q '___' "$TMP" && { echo "빈칸(___)이 남아 있다. 다 채우고 다시"; rm -f "$TMP"; exit 1; }
kubectl -n monitoring create configmap prometheus-rules --from-file=fault-injection.yaml="$TMP" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
# ConfigMap 이 파드 안 파일로 바뀌는 데 최대 1분쯤 걸린다 → 파일 내용이 같아질 때까지 기다렸다가 Prometheus 에 다시 읽으라고 한다
echo "규칙 ConfigMap 갱신. 파드 안 파일에 반영되길 기다리는 중 (최대 120초)"
WANT=$(cksum < "$TMP"); rm -f "$TMP"
for i in $(seq 1 120); do
  GOT=$( (kubectl -n monitoring exec deploy/prometheus -- cat /etc/prometheus/rules/fault-injection.yaml 2>/dev/null || true) | cksum)
  [ "$GOT" = "$WANT" ] && break
  sleep 1
done
[ "$GOT" = "$WANT" ] || { echo "120초 안에 파일이 안 바뀌었다"; exit 1; }
kubectl -n monitoring exec deploy/prometheus -- wget -qO- --post-data='' http://localhost:9090/-/reload >/dev/null
sleep 2
n=$(kubectl get --raw /api/v1/namespaces/monitoring/services/prometheus-server:80/proxy/api/v1/rules \
    | python3 -c 'import json,sys; print(sum(len(g["rules"]) for g in json.load(sys.stdin)["data"]["groups"]))')
want=$(grep -c '^ *- alert:' "$F")
if [ "$n" = "$want" ]; then echo "Prometheus 에 규칙 ${n}개 올라감"; else echo "규칙이 ${n}개뿐이다 (기대 $want). kubectl -n monitoring logs deploy/prometheus | tail 로 문법 에러 확인"; exit 1; fi
