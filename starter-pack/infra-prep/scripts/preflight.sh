#!/usr/bin/env bash
# 도구·버전·Docker 자원 점검. 아무것도 만들지 않는다 (읽기만). Claude 작성, 완성본.
# 사용법 (레포 루트 또는 아무 데서나): starter-pack/infra-prep/scripts/preflight.sh
# 출력 맨 마지막 줄이 "준비 완료" 면 드릴을 시작해도 된다.
set -uo pipefail

miss=0
ok()   { printf '  ok   %-10s %s\n' "$1" "$2"; }
no()   { printf '  없음 %-10s → %s\n' "$1" "$2"; miss=1; }
opt()  { printf '  (선택) %-8s %s\n' "$1" "$2"; }

echo "== 필수 도구 (없으면 brew bundle --file=starter-pack/infra-prep/Brewfile)"
command -v docker  >/dev/null && ok docker  "$(docker --version 2>/dev/null | cut -d, -f1)"         || no docker  "Docker Desktop 설치 후 실행"
command -v kind    >/dev/null && ok kind    "$(kind --version 2>/dev/null)"                          || no kind    "brew install kind"
command -v kubectl >/dev/null && ok kubectl "$(kubectl version --client 2>/dev/null | head -1)"      || no kubectl "brew install kubernetes-cli"
command -v helm    >/dev/null && ok helm    "$(helm version --short 2>/dev/null)"                    || no helm    "brew install helm"
command -v curl    >/dev/null && ok curl    "$(curl --version | head -1 | cut -d' ' -f1-2)"          || no curl    "맥 기본. 이상함"
command -v git     >/dev/null && ok git     "$(git --version)"                                       || no git     "xcode-select --install"

echo "== 선택 도구 (해당 문서에서만 필요)"
command -v k3d       >/dev/null && ok k3d       "$(k3d version 2>/dev/null | head -1)"             || opt k3d       "없음. 01-cluster-boot.md 3절(k3d) 할 때 brew install k3d"
command -v multipass >/dev/null && ok multipass "$(multipass version 2>/dev/null | head -1)"       || opt multipass "없음. 01-cluster-boot.md 4절(k3s VM) 할 때 brew install --cask multipass"
command -v kubectx   >/dev/null && ok kubectx   "있음"                                             || opt kubectx   "없음. 클러스터 여럿일 때 편함: brew install kubectx"
command -v hey       >/dev/null && ok hey       "있음"                                             || opt hey       "없음. 알림 실험 때 편함: brew install hey (없으면 curl 반복으로 대체)"
command -v argocd    >/dev/null && ok argocd    "$(argocd version --client --short 2>/dev/null)"   || opt argocd    "없음. UI 로 충분. CLI 쓰려면 brew install argocd"

echo "== Docker"
if docker info >/dev/null 2>&1; then
  cpu=$(docker info --format '{{.NCPU}}'); mem=$(docker info --format '{{.MemTotal}}')
  gb=$(( mem / 1000000000 ))
  echo "  CPU ${cpu}개, 메모리 ${gb}GB"
  if [ "$mem" -lt 8000000000 ]; then
    echo "  경고: 8GB 미만. 드릴(kind + Argo CD + Prometheus/Grafana)은 6GB 정도 쓴다. Docker Desktop → Settings → Resources 에서 10GB 권장"
  fi
  # 지금 떠 있는 kind/k3d 컨테이너 (메모리를 같이 먹는다)
  running=$(docker ps --format '{{.Names}}' | grep -E 'control-plane|worker|k3d-' || true)
  if [ -n "$running" ]; then
    echo "  지금 떠 있는 클러스터 노드 컨테이너:"; echo "$running" | sed 's/^/    /'
    echo "  → 드릴 전에 안 쓰는 건 지운다: kind delete cluster --name <이름> / k3d cluster delete <이름>"
  else
    echo "  떠 있는 클러스터 없음 (깨끗함)"
  fi
  # 이미지·캐시가 디스크를 얼마나 먹나
  docker system df --format '  디스크: 이미지 {{.Size}} ({{.Reclaimable}} 회수 가능)' 2>/dev/null | head -1
else
  echo "  Docker 데몬에 못 붙음. Docker Desktop 을 켜고 다시"; miss=1
fi

echo "== kubectl 컨텍스트"
kubectl config get-contexts 2>/dev/null | sed 's/^/  /' || echo "  (아직 없음. 정상)"

echo "== 포트 9898 (드릴이 podinfo 에 쓴다)"
if lsof -nP -iTCP:9898 -sTCP:LISTEN >/dev/null 2>&1; then
  echo "  경고: 9898 을 누가 쓰고 있다 → lsof -nP -iTCP:9898 -sTCP:LISTEN 으로 확인"
else
  echo "  비어 있음"
fi

echo
[ "$miss" = 0 ] && echo "준비 완료. 다음: starter-pack/infra-prep/02-drill-30min.md" || echo "위 '없음' 을 먼저 해결"
