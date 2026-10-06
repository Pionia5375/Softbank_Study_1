#!/usr/bin/env bash
# 부하 만들기. 클러스터 안에 busybox Pod 를 N개 띄워, 각자 쉬지 않고 http://hello/hello 를 부른다.
# 쓰는 법: scripts/load.sh start [N]   (기본 4)
#          scripts/load.sh stop
set -eu
case "${1:-}" in
  start)
    n=${2:-4}
    kubectl create deployment load --image=busybox:1.37 --replicas="$n" \
      -- sh -c 'while true; do wget -q -O /dev/null http://hello/hello; done'
    ;;
  stop)
    kubectl delete deployment load
    ;;
  *)
    echo "usage: $0 start [N] | stop"; exit 1 ;;
esac
