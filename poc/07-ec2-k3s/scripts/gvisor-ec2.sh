#!/usr/bin/env bash
# (선택) EC2 k3s 위에서 runc vs gVisor 콜드 스타트 비교 (Claude 작성, 완성본). README 8.5절.
# 4단계(poc/04-faas-runtime)의 RuntimeClass·기능 플래그·ksvc·coldstart.sh 를 그대로 다시 쓴다.
# 전제: terraform apply 를 enable_gvisor=true 로 했고, tunnel.sh 가 켜져 있고, KUBECONFIG 가 잡혀 있다.
#
#   ./scripts/gvisor-ec2.sh check                 실행 노드마다 runsc 설치·containerd 등록 확인 (SSM)
#   ./scripts/gvisor-ec2.sh platform [--solution] Knative + Kourier + 기능 플래그 + RuntimeClass
#   ./scripts/gvisor-ec2.sh image                 hello 함수를 amd64 로 빌드해 ttl.sh 에 올림 (24시간 뒤 자동 삭제)
#   ./scripts/gvisor-ec2.sh deploy IMAGE [--solution]   hello-runc / hello-gvisor 배포 (이미지만 바꿔서)
#   ./scripts/gvisor-ec2.sh measure [N]           두 함수 콜드 스타트 N회씩 (기본 10) → results/coldstart-ec2.csv + times.csv
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
REPO=$(cd "$HERE/../.." && pwd)
P04="$REPO/poc/04-faas-runtime"
TF="terraform -chdir=$HERE/terraform/cluster"
KNATIVE_VERSION="${KNATIVE_VERSION:-1.23.0}"   # 4단계와 같게
NS=fn-runtime
CSV="$HERE/results/times.csv"
[ -f "$CSV" ] || echo "date,step,seconds,note" > "$CSV"

src() {   # src 상대경로 [--solution] → 4단계 파일 (Jeong 것 또는 정답본)
  if [ "${2:-}" = "--solution" ]; then echo "$P04/solution/$1"; else echo "$P04/$1"; fi
}
need_no_blanks() {
  if grep -n '___' "$@"; then echo "위 4단계 파일에 빈칸이 남았다. 채우거나 --solution"; exit 1; fi
}

case "${1:-}" in
  check)
    REGION=$($TF output -raw region)
    IDS=$(aws ec2 describe-instances --region "$REGION" \
      --filters Name=tag:Pool,Values=exec Name=instance-state-name,Values=running \
      --query 'Reservations[].Instances[].InstanceId' --output text)
    [ -n "$IDS" ] || { echo "실행 노드가 없다"; exit 1; }
    # shellcheck disable=SC2086
    CMD=$(aws ssm send-command --region "$REGION" --instance-ids $IDS --document-name AWS-RunShellScript \
      --parameters 'commands=["runsc --version | head -1","k3s crictl info | grep -c runsc","grep gvisor /var/log/k3s-bootstrap.log | tail -3"]' \
      --query 'Command.CommandId' --output text)
    sleep 5
    for id in $IDS; do
      echo "== $id"
      aws ssm get-command-invocation --region "$REGION" --command-id "$CMD" --instance-id "$id" \
        --query 'StandardOutputContent' --output text
    done
    echo "기대: runsc version ... / 1 이상 / [gvisor] done"
    ;;

  platform)
    FEAT=$(src platform/knative/config-features-patch.yaml "${2:-}")
    RC=$(src platform/runtimeclass-gvisor.yaml "${2:-}")
    need_no_blanks "$FEAT" "$RC"
    REL="https://github.com/knative/serving/releases/download/knative-v$KNATIVE_VERSION"
    t0=$(date +%s)
    kubectl apply -f "$REL/serving-crds.yaml"
    kubectl wait --for=condition=Established crd --all --timeout=60s >/dev/null
    kubectl apply -f "$REL/serving-core.yaml"
    kubectl apply -f "https://github.com/knative-extensions/net-kourier/releases/download/knative-v$KNATIVE_VERSION/kourier.yaml"
    # Kourier 입구를 ClusterIP 로. LoadBalancer 로 두면 k3s ServiceLB 가 노드 80 번을 잡으려다 Traefik 과 부딪힌다.
    # 맥에서는 kubectl port-forward 로 들어간다 (measure 가 알아서 켬)
    kubectl -n kourier-system patch service kourier --type merge -p '{"spec":{"type":"ClusterIP"}}'
    kubectl -n knative-serving patch configmap config-network --type merge \
      -p '{"data":{"ingress-class":"kourier.ingress.networking.knative.dev"}}'
    kubectl -n knative-serving patch configmap config-domain --type merge -p '{"data":{"faas.local":""}}'
    kubectl -n knative-serving patch configmap config-features --type merge --patch-file "$FEAT"
    kubectl apply -f "$RC"
    kubectl -n knative-serving rollout status deploy --timeout=300s
    kubectl -n kourier-system rollout status deploy --timeout=300s
    echo "$(date +%Y-%m-%dT%H:%M:%S),knative_setup,$(( $(date +%s) - t0 )),Knative $KNATIVE_VERSION + Kourier + RuntimeClass" | tee -a "$CSV"
    kubectl get runtimeclass
    ;;

  image)
    # 맥(애플 실리콘)은 arm64 로 빌드된다. t3 노드는 x86_64 → --platform linux/amd64 필수
    # ttl.sh = 로그인 없는 공개 임시 레지스트리. 태그의 :24h 가 보관 기간. 이름은 겹치지 않게 무작위
    IMG="ttl.sh/poc07-hello-$(LC_ALL=C tr -dc a-z0-9 </dev/urandom | head -c 8):24h"
    docker buildx build --platform linux/amd64 -t "$IMG" --push "$P04/functions/hello-src"
    echo "$IMG"
    echo "다음: ./scripts/gvisor-ec2.sh deploy $IMG"
    ;;

  deploy)
    IMG=${2:?이미지 (image 단계 출력)}
    kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
    for fn in hello-runc hello-gvisor; do
      F=$(src "functions/ksvc/$fn.yaml" "${3:-}")
      need_no_blanks "$F"
      # 4단계 ksvc 에서 이미지 주소만 바꿔 넣는다 (kind-registry 는 EC2 에 없음). GitOps 가 아니라 측정용 1회 적용
      sed "s#image: kind-registry:5000/fn/hello:[^[:space:]]*#image: $IMG#" "$F" | kubectl apply -f -
    done
    kubectl -n "$NS" wait ksvc --all --for=condition=Ready --timeout=300s
    kubectl -n "$NS" get ksvc
    ;;

  measure)
    N=${2:-10}
    kubectl -n kourier-system port-forward svc/kourier 8081:80 >/dev/null 2>&1 &
    PF=$!; trap 'kill $PF 2>/dev/null || true' EXIT
    sleep 3
    OUT="$HERE/results/coldstart-ec2.csv"
    for fn in hello-runc hello-gvisor; do
      before=$( [ -f "$P04/results/coldstart.csv" ] && wc -l < "$P04/results/coldstart.csv" || echo 1)
      GATEWAY=http://localhost:8081 "$P04/scripts/coldstart.sh" "$fn" "$N" | tee "$HERE/results/.last"
      # 4단계 스크립트는 4단계 results 에 쓴다 → 이번 줄만 7단계로 옮겨 적는다
      [ -f "$OUT" ] || head -1 "$P04/results/coldstart.csv" > "$OUT"
      tail -n +"$((before + 1))" "$P04/results/coldstart.csv" >> "$OUT"
      summary=$(grep '요약' "$HERE/results/.last" | sed 's/.*): //')
      echo "$(date +%Y-%m-%dT%H:%M:%S),coldstart_$fn,,$summary (EC2 t3, port-forward 경유)" | tee -a "$CSV"
    done
    rm -f "$HERE/results/.last"
    echo "주의: SSM 터널 + port-forward 를 거쳐서 절대값엔 수십 ms 가 더해진다 【추정】. 두 런타임에 똑같이 더해지니 차이(gVisor − runc)를 본다"
    ;;

  *)
    sed -n '2,11p' "$0"; exit 1 ;;
esac
