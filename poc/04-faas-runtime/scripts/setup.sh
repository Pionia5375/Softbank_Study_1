#!/usr/bin/env bash
# 4단계 플랫폼 설치 (Claude 작성, 완성본). 단계별 [N초] 와 총 시간을 찍는다 → 셋업 드릴 기록용.
# 전제: kind 클러스터 faas 가 cluster/kind-config.yaml 로 떠 있고 노드가 Ready (3단계 Cilium 까지 끝)
# 쓰는 법: poc/04-faas-runtime 폴더에서 scripts/setup.sh
#
# 설치하는 것
#   1. kind-registry : 클러스터 밖 이미지 저장소 (Docker 컨테이너). Kaniko 가 여기에 올리고 노드가 여기서 받는다
#   2. Knative Serving : 함수를 0↔N 으로 늘였다 줄이는 플랫폼 (CRD + 컨트롤러)
#   3. Kourier : Knative 앞의 입구(Ingress). 맥 8081 → 노드 31080 → Kourier → 함수
#   4. Knative 설정 3개 : 도메인, 레지스트리 태그 해석 건너뛰기
#   5. gVisor : exec 풀 노드에만 (install-gvisor.sh)
set -euo pipefail
source "$(dirname "$0")/lib.sh"
KNATIVE_VERSION="${KNATIVE_VERSION:-1.23.0}"   # Serving 과 Kourier 버전을 같이 맞춘다
# 받는 주소. GitHub 가 막힌 곳(대회장 네트워크 등)에선 미리 받아 둔 폴더를 가리키게 바꿀 수 있다
REL="${KNATIVE_REL_URL:-https://github.com/knative/serving/releases/download/knative-v$KNATIVE_VERSION}"
KOURIER="${KOURIER_URL:-https://github.com/knative-extensions/net-kourier/releases/download/knative-v$KNATIVE_VERSION/kourier.yaml}"
t0=$(date +%s)
lap() { echo "[$(( $(date +%s) - t0 ))s] $*"; }

lap "0/5 노드 풀 라벨 확인"
kubectl get nodes -L pool
for p in system build exec; do
  [ -n "$(kubectl get nodes -l pool=$p -o name)" ] || { echo "pool=$p 노드가 없다. cluster/kind-config.yaml 의 labels 를 확인"; exit 1; }
done

lap "1/5 kind-registry (클러스터 밖 이미지 저장소)"
if [ "$(docker inspect -f '{{.State.Running}}' kind-registry 2>/dev/null || true)" != "true" ]; then
  # -p 127.0.0.1:5001:5000 : 맥에서도 localhost:5001 로 볼 수 있게 (curl localhost:5001/v2/_catalog)
  docker run -d --restart=always -p 127.0.0.1:5001:5000 --network bridge --name kind-registry registry:2
fi
# kind 노드들과 같은 Docker 네트워크에 붙인다 → 노드·Pod 가 "kind-registry" 라는 이름으로 찾는다
docker network connect kind kind-registry 2>/dev/null || true
# 노드마다 "이 레지스트리 이름은 TLS 없는 http://kind-registry:5000 으로 받아라" 를 containerd 에 알려 준다.
#   kind-registry:5000 : 4단계 ksvc 가 쓰는 이름 (Kaniko 가 올리는 이름과 같다)
#   localhost:5001     : kind 공식 문서·5단계가 쓰는 이름. 둘 다 같은 저장소를 가리키게 해 둔다
for n in $(kind get nodes --name "$CLUSTER"); do
  for r in kind-registry:5000 localhost:5001; do
    docker exec "$n" mkdir -p "/etc/containerd/certs.d/$r"
    printf '[host."http://kind-registry:5000"]\n  capabilities = ["pull", "resolve"]\n' |
      docker exec -i "$n" cp /dev/stdin "/etc/containerd/certs.d/$r/hosts.toml"
  done
done

lap "2/5 Knative Serving v$KNATIVE_VERSION (CRD → 본체)"
kubectl apply -f "$REL/serving-crds.yaml"
kubectl wait --for=condition=Established crd --all --timeout=60s >/dev/null
kubectl apply -f "$REL/serving-core.yaml"
kubectl -n knative-serving rollout status deploy --timeout=300s

lap "3/5 Kourier (입구) + NodePort 31080"
kubectl apply -f "$KOURIER"
kubectl -n kourier-system rollout status deploy --timeout=300s
kubectl -n knative-serving rollout status deploy net-kourier-controller --timeout=300s
# Knative 에게 "입구는 Kourier 다"
kubectl -n knative-serving patch configmap config-network --type merge \
  -p '{"data":{"ingress-class":"kourier.ingress.networking.knative.dev"}}'
# Kourier 입구 Service 를 LoadBalancer → NodePort 31080 으로 (kind 엔 LoadBalancer 가 없다)
kubectl -n kourier-system patch service kourier --type merge \
  -p '{"spec":{"type":"NodePort","ports":[{"name":"http2","port":80,"protocol":"TCP","targetPort":8080,"nodePort":31080}]}}'

lap "4/5 Knative 설정 (도메인, 레지스트리)"
# 함수 주소 = <함수>.<namespace>.faas.local. 진짜 DNS 는 없고 curl -H "Host: ..." 로 고른다
kubectl -n knative-serving patch configmap config-domain --type merge -p "{\"data\":{\"$DOMAIN\":\"\"}}"
# Knative 는 배포할 때 이미지 태그(:v1)를 다이제스트(@sha256)로 바꿔 고정하려고 레지스트리에 https 로 묻는다.
# kind-registry 는 http 라서 실패한다 → 이 레지스트리는 건너뛰게 한다 (대가: 같은 태그를 덮어쓰면 새 Pod 가 다른 이미지를 받을 수 있다 → 태그를 매번 새로)
kubectl -n knative-serving patch configmap config-deployment --type merge \
  -p '{"data":{"registries-skipping-tag-resolving":"kind.local,ko.local,dev.local,kind-registry:5000,localhost:5001"}}'

lap "5/5 gVisor (exec 풀만)"
"$(dirname "$0")/install-gvisor.sh"

kubectl create namespace "$BUILD_NS" --dry-run=client -o yaml | kubectl apply -f -
lap "완료"
kubectl get pods -n knative-serving -o wide
kubectl get pods -n kourier-system -o wide
echo
echo "다음: (Jeong) platform/knative/config-features-patch.yaml → platform/runtimeclass-gvisor.yaml → build/kaniko-job.yaml"
