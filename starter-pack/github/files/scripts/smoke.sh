#!/usr/bin/env bash
# 배포가 실제로 응답하는지 확인한다. CI(kind-smoke)와 로컬에서 같은 스크립트를 쓴다.
# 성공: "OK" 출력 + exit 0. 실패: 상태 덤프 + exit 1.
set -euo pipefail

NS="${NS:-hello}"
DEPLOY="${DEPLOY:-hello}"
SVC="${SVC:-hello}"
PORT="${PORT:-18080}"

# Deployment의 모든 파드가 Ready 될 때까지 최대 180초 대기
kubectl -n "$NS" rollout status "deployment/$DEPLOY" --timeout=180s

# 서비스 포트를 로컬 PORT로 터널링 (백그라운드), 스크립트가 끝나면 끊는다
kubectl -n "$NS" port-forward "svc/$SVC" "$PORT:80" >/dev/null 2>&1 &
PF=$!
trap 'kill $PF 2>/dev/null || true' EXIT

# 터널이 열릴 때까지 최대 20초 동안 1초마다 curl
for _ in $(seq 1 20); do
  if curl -fsS "http://127.0.0.1:$PORT/" >/dev/null; then
    echo "OK: $SVC responds on :$PORT"
    exit 0
  fi
  sleep 1
done

echo "FAIL: no response from $SVC" >&2
kubectl -n "$NS" get pods -o wide >&2
exit 1
