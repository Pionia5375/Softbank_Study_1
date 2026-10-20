#!/usr/bin/env bash
# 함수 이미지를 클러스터 안에서 빌드한다 (Claude 작성, 완성본). 걸린 시간을 results/build.csv 에 남긴다.
# 쓰는 법:
#   scripts/build.sh v1                 → build 풀에서, 캐시 사용, 태그 v1
#   NOCACHE=1 scripts/build.sh v2       → 캐시 없이 (처음 빌드와 같은 조건)
#   POOL=exec scripts/build.sh v3       → 일부러 exec 풀(함수 옆)에서 빌드 (build-noise.sh 가 쓴다)
# 하는 일
#   1. functions/hello-src 폴더(소스 3개)를 tar.gz 로 묶어 ConfigMap hello-src 로 올린다 = Kaniko 의 빌드 재료
#   2. build/kaniko-job.yaml (Jeong 작성) 을 읽어 이름·태그·풀만 바꿔 Job 을 만든다 (파일 자체는 안 바뀜)
#   3. Job 이 끝날 때까지 기다리고 초를 잰다
set -euo pipefail
source "$(dirname "$0")/lib.sh"
TAG="${1:-v1}"
POOL="${POOL:-build}"
NOCACHE="${NOCACHE:-0}"
JOB_FILE="${JOB_FILE:-$POC_DIR/build/kaniko-job.yaml}"
name="build-hello-$(echo "$TAG" | tr '._' '--' | tr 'A-Z' 'a-z')-$(date +%s)"

kubectl create namespace "$BUILD_NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
# 소스 폴더를 tar.gz 하나로 묶어 ConfigMap 에 넣는다 (ConfigMap 한 개 최대 1MiB → 큰 소스는 Git context 나 S3 로)
ctx=$(mktemp -d)
tar -czf "$ctx/context.tar.gz" -C "$POC_DIR/functions/hello-src" .
kubectl -n "$BUILD_NS" create configmap hello-src --from-file="$ctx/context.tar.gz" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null
rm -rf "$ctx"

# JSON Patch: 파일의 특정 칸만 바꾼다. /env/0 = IMAGE_TAG, /tolerations/0 = 풀 taint 통과
patch='[
 {"op":"replace","path":"/metadata/name","value":"'"$name"'"},
 {"op":"replace","path":"/spec/template/spec/containers/0/env/0/value","value":"'"$TAG"'"},
 {"op":"replace","path":"/spec/template/spec/nodeSelector/pool","value":"'"$POOL"'"},
 {"op":"replace","path":"/spec/template/spec/tolerations/0/value","value":"'"$POOL"'"}'
[ "$NOCACHE" = "1" ] && patch="$patch"',
 {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--cache=false"}'
patch="$patch]"

t0=$(now_ms)
kubectl patch --local -f "$JOB_FILE" --type=json -p "$patch" -o yaml | kubectl create -f - >/dev/null
echo "Job $BUILD_NS/$name 생성 (pool=$POOL, nocache=$NOCACHE, 태그 $TAG)"

result=timeout
for _ in $(seq 1 600); do
  s=$(kubectl -n "$BUILD_NS" get job "$name" -o jsonpath='{.status.succeeded}/{.status.failed}')
  case "$s" in
    1/*) result=ok; break ;;
    */1) result=failed; break ;;
  esac
  sleep 1
done
t1=$(now_ms)
secs=$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.1f", (b-a)/1000}')
node=$(kubectl -n "$BUILD_NS" get pod -l job-name="$name" -o jsonpath='{.items[0].spec.nodeName}')

[ -f "$RESULTS/build.csv" ] || echo "time,tag,pool,nocache,seconds,node,result" > "$RESULTS/build.csv"
echo "$(date +%FT%T),$TAG,$POOL,$NOCACHE,$secs,$node,$result" >> "$RESULTS/build.csv"
echo "결과: $result, ${secs}s, 노드 $node"
if [ "$result" != ok ]; then
  kubectl -n "$BUILD_NS" logs "job/$name" --tail=30 || true
  exit 1
fi
echo "이미지: kind-registry:5000/fn/hello:$TAG  (맥에서 확인: curl -s localhost:5001/v2/fn/hello/tags/list)"
