#!/usr/bin/env bash
# exec 풀 노드에만 gVisor(runsc)를 설치한다 (Claude 작성, 완성본).
# 쓰는 법: scripts/install-gvisor.sh            → pool=exec 라벨이 붙은 노드 전부
#          scripts/install-gvisor.sh faas-worker3 → 이름으로 지정
#
# 하는 일 (노드마다)
#   1. 노드 CPU 종류(x86_64 / aarch64)에 맞는 gVisor 묶음을 맥으로 받는다 (+ sha512 확인)
#   2. 풀어서 노드 컨테이너의 /usr/local/bin 에 복사: runsc, containerd-shim-runsc-v1, gvisor-bin/
#      (2026-07 부터 gVisor 는 runsc 하나가 아니라 gvisor-bin/ 폴더도 같이 있어야 돈다 【사실】 gvisor install.md)
#   3. 노드의 containerd 설정에 "runsc 라는 이름의 런타임" 을 추가하고 containerd 재시작
#   4. 노드가 다시 Ready 인지 확인
# 문서: https://gvisor.dev/docs/user_guide/install/
#       https://gvisor.dev/docs/user_guide/containerd/quick_start/
set -euo pipefail
source "$(dirname "$0")/lib.sh"
GVISOR_VERSION="${GVISOR_VERSION:-20261012.0}"   # 버전 고정. latest 를 쓰면 팀원마다 다른 게 깔린다
CACHE="$POC_DIR/.cache/gvisor-$GVISOR_VERSION"

nodes=("$@")
if [ ${#nodes[@]} -eq 0 ]; then
  read -r -a nodes <<<"$(kubectl get nodes -l pool=exec -o jsonpath='{.items[*].metadata.name}')"
fi
[ ${#nodes[@]} -gt 0 ] || { echo "pool=exec 노드가 없다. kind-config 의 labels 를 확인"; exit 1; }

for n in "${nodes[@]}"; do
  arch=$(docker exec "$n" uname -m)              # x86_64 (인텔) 또는 aarch64 (애플 실리콘)
  dir="$CACHE/$arch"
  if [ ! -x "$dir/runsc" ]; then
    mkdir -p "$dir"
    url="https://storage.googleapis.com/gvisor/releases/release/$GVISOR_VERSION/$arch"
    echo "[$n] 다운로드 $url/gvisor.tar.bz2"
    curl -fsSL -o "$dir/gvisor.tar.bz2" "$url/gvisor.tar.bz2"
    curl -fsSL -o "$dir/gvisor.tar.bz2.sha512" "$url/gvisor.tar.bz2.sha512"
    # sha512 파일 첫 칸 = 기대 해시. 받은 파일 해시와 같아야 한다 (중간에 바뀐 파일을 노드에 넣지 않으려고)
    want=$(awk '{print $1}' "$dir/gvisor.tar.bz2.sha512")
    got=$( (sha512sum "$dir/gvisor.tar.bz2" 2>/dev/null || shasum -a 512 "$dir/gvisor.tar.bz2") | awk '{print $1}')
    [ "$want" = "$got" ] || { echo "sha512 불일치"; exit 1; }
    tar -xjf "$dir/gvisor.tar.bz2" -C "$dir"
  fi

  echo "[$n] 바이너리 복사"
  docker cp "$dir/runsc" "$n:/usr/local/bin/runsc"
  docker cp "$dir/containerd-shim-runsc-v1" "$n:/usr/local/bin/containerd-shim-runsc-v1"
  docker cp "$dir/gvisor-bin" "$n:/usr/local/bin/"
  docker exec "$n" runsc --version | head -1

  if ! docker exec "$n" grep -q 'runtimes.runsc]' /etc/containerd/config.toml; then
    echo "[$n] containerd 에 runsc 런타임 등록"
    # kind 노드의 containerd 설정은 version = 2 형식 → 플러그인 이름이 io.containerd.grpc.v1.cri
    docker exec "$n" sh -c 'cat >> /etc/containerd/config.toml <<TOML

# gVisor (scripts/install-gvisor.sh)
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
  runtime_type = "io.containerd.runsc.v1"
TOML'
    docker exec "$n" systemctl restart containerd
  fi
done

kubectl wait --for=condition=Ready node "${nodes[@]}" --timeout=120s
echo "완료. 다음: kubectl apply -f platform/runtimeclass-gvisor.yaml"
