#!/usr/bin/env bash
# 노드의 남은 CPU 자리를 low 우선순위 Pod 로 거의 다 채운다 (실제로 CPU 를 쓰지는 않음. sleep 만 한다).
# 스케줄러는 실제 사용량이 아니라 requests 합계로 자리를 계산하기 때문에, 이렇게 "예약" 만으로 노드를 꽉 채울 수 있다.
# 쓰는 법: scripts/fill-node.sh <노드이름>      예) scripts/fill-node.sh lab05-worker
#          scripts/fill-node.sh delete
set -eu
if [ "${1:-}" = "delete" ]; then kubectl delete deployment filler; exit 0; fi
node=${1:?노드 이름}

to_m() { case "$1" in *m) echo "${1%m}";; *) echo $(( $1 * 1000 ));; esac; }
alloc=$(to_m "$(kubectl get node "$node" -o jsonpath='{.status.allocatable.cpu}')")
used=$(to_m "$(kubectl describe node "$node" | awk '/Allocated resources/{f=1} f && $1=="cpu"{print $2; exit}')")
free=$(( alloc - used ))
req=$(( free - 50 ))                     # 50m 만 남긴다 → hello Pod(100m) 하나도 못 들어온다
echo "$node: allocatable ${alloc}m, 이미 예약 ${used}m, 남음 ${free}m → filler 가 ${req}m 예약"

kubectl apply -f - <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: filler
spec:
  replicas: 1
  selector: { matchLabels: { app: filler } }
  template:
    metadata: { labels: { app: filler } }
    spec:
      priorityClassName: low
      nodeSelector: { kubernetes.io/hostname: $node }
      containers:
        - name: sleep
          image: busybox:1.37
          command: ["sleep", "infinity"]
          resources:
            requests: { cpu: ${req}m, memory: 16Mi }
YAML
kubectl rollout status deployment/filler
