# 6단계 스크립트 공통 설정 (Claude 작성). 모든 s*.sh 가 맨 앞에서 읽는다.
# 대상 이름이 3·4단계와 다르면 여기 기본값을 고치지 말고, 실행할 때 앞에 붙여서 덮어쓴다:
#   FN_NS=fn-demo FN_NAME=hello-fn FN_SELECTOR=app=hello-fn ./scripts/s1-node-down.sh hard
# (기본값 = standin/ 대역 대상)

# 테넌트 두 개: A = 피해자, B = 나쁜 이웃
TENANT_A="${TENANT_A:-tenant-a}"
TENANT_B="${TENANT_B:-tenant-b}"

# 시나리오 1·2 의 피해자 함수 (Deployment)
FN_NS="${FN_NS:-$TENANT_A}"
FN_NAME="${FN_NAME:-hello}"
FN_SELECTOR="${FN_SELECTOR:-app=hello}"
FN_URL="${FN_URL:-http://$FN_NAME.$FN_NS.svc/}"

# 시나리오 3 의 카나리 대상 (Argo Rollout)
ROLLOUT_NS="${ROLLOUT_NS:-$TENANT_A}"
ROLLOUT="${ROLLOUT:-api}"
ROLLOUT_URL="${ROLLOUT_URL:-http://$ROLLOUT.$ROLLOUT_NS.svc/}"

# 함수가 뜨는 노드 풀 라벨 (3단계 kind 설정의 labels)
EXEC_LABEL="${EXEC_LABEL:-pool=exec}"

# Prometheus (없으면 알림 시간 칸만 비고 나머지는 그대로 돈다). 형식: 네임스페이스/서비스:포트
PROM_SVC="${PROM_SVC:-monitoring/prometheus-server:80}"   # 2단계 차트가 만드는 Service

# 결과 CSV 와 프로브 로그가 쌓이는 곳
RESULTS="${RESULTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/results}"

# 이번 측정의 이름표. CSV 맨 앞 열에 들어간다. 방어 전/후를 구분하려고 쓴다
#   LABEL=방어전 ./scripts/s1-node-down.sh hard 1
LABEL="${LABEL:-}"
