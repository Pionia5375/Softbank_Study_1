#!/usr/bin/env bash
# Dockerfile A/B 의 이미지 크기, 빌드 시간(콜드/캐시), 기동 → /health 200 까지 시간을 잰다.
#
# 사용법 (labs/01-docker-basics 에서):
#   scripts/measure.sh single
#   scripts/measure.sh multi                                  # RUNTIME_IMAGE 기본값을 채운 뒤
#   RUNTIME_IMAGE=<이미지:태그> scripts/measure.sh multi       # 기본값 없이 임시로
#
# 결과는 results/<variant>-<시각>.log 에 저장되고 마지막 요약 줄을 README 표에 옮겨 적는다.

set -euo pipefail

variant="${1:?usage: measure.sh single|multi}"
case "$variant" in
  single|multi) ;;
  *) echo "variant 는 single 또는 multi" >&2; exit 1 ;;
esac

cd "$(dirname "$0")/.."
tag="lab01-hello:${variant}"
port=18080
mkdir -p results
log="results/${variant}-$(date +%Y%m%d-%H%M%S).log"

build_args=()
if [[ -n "${RUNTIME_IMAGE:-}" ]]; then
  build_args+=(--build-arg "RUNTIME_IMAGE=${RUNTIME_IMAGE}")
fi

now_ms() { python3 -c 'import time; print(int(time.time()*1000))'; }

build() {
  local start end
  start=$(now_ms)
  docker build "$@" ${build_args[@]+"${build_args[@]}"} -f "app/Dockerfile.${variant}" -t "$tag" app >>"$log" 2>&1
  end=$(now_ms)
  echo $((end - start))
}

echo "[1/4] 콜드 빌드 (--no-cache)"
cold_ms=$(build --no-cache)

echo "[2/4] 캐시 빌드 (변경 없음)"
cached_ms=$(build)

echo "[3/4] src 만 바꾼 뒤 재빌드 (레이어 캐시 효과 확인)"
touch app/src/main/java/com/example/hello/HelloController.java
src_change_ms=$(build)

size_mb=$(docker image inspect "$tag" --format '{{.Size}}' | awk '{printf "%.1f", $1/1024/1024}')

echo "[4/4] 기동 → /health 200 까지"
docker rm -f lab01-measure >/dev/null 2>&1 || true
start=$(now_ms)
docker run -d --name lab01-measure -p "${port}:8080" "$tag" >/dev/null
until curl -sf "http://localhost:${port}/health" >/dev/null; do
  if (( $(now_ms) - start > 60000 )); then
    echo "60초 안에 /health 가 200 을 주지 않음" >&2
    docker logs lab01-measure >>"$log" 2>&1
    docker rm -f lab01-measure >/dev/null
    exit 1
  fi
  sleep 0.1
done
startup_ms=$(( $(now_ms) - start ))
docker rm -f lab01-measure >/dev/null

summary="| ${variant} | ${size_mb} MB | ${cold_ms} ms | ${cached_ms} ms | ${src_change_ms} ms | ${startup_ms} ms |"
echo "$summary" | tee -a "$log"
echo "로그: $log"
