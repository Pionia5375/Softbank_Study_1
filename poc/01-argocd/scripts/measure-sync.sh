#!/usr/bin/env bash
# git push → 새 파드가 Ready 될 때까지 걸린 시간을 잰다. (Claude 작성)
#
# 하는 일 (1회당):
#   1. functions/hello-fn/values.yaml 의 message 줄을 "hello run-<시각>" 으로 바꾼다
#   2. 그 파일만 커밋하고 main 에 push 한다           ← 레포에 측정용 커밋이 회당 1개 생긴다
#   3. [refresh 모드만] Argo CD 에 "지금 Git 다시 봐" 표시를 붙인다
#   4. Deployment 의 args 에 새 문자열이 들어갈 때까지 1초마다 확인  → t_detect (Argo CD 가 알아채고 적용까지)
#   5. kubectl rollout status 로 새 파드가 다 Ready 될 때까지 대기  → t_ready (쿠버네티스가 파드 교체까지)
#   6. results/sync-times.csv 에 한 줄 추가
#
# 사용법 (레포 루트에서):
#   ./poc/01-argocd/scripts/measure-sync.sh poll 3      # 기다리기만 (timeout.reconciliation 효과)
#   ./poc/01-argocd/scripts/measure-sync.sh refresh 3   # push 직후 강제 새로고침 (webhook 을 흉내)
set -euo pipefail

MODE="${1:-poll}"            # poll | refresh
RUNS="${2:-3}"
NS="${NS:-fn-demo}"          # Application 의 destination.namespace 와 같아야 한다
APP="${APP:-hello-fn}"
VALUES="poc/01-argocd/functions/hello-fn/values.yaml"
OUT="poc/01-argocd/results/sync-times.csv"
TIMEOUT=600                  # 한 회에 10분 넘으면 실패로 본다

now() { perl -MTime::HiRes=time -e 'printf "%.1f\n", time'; }   # 맥 date 는 소수점 초를 못 줘서 perl 사용

[[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]] || { echo "main 브랜치에서 실행해야 한다"; exit 1; }
[[ -f "$OUT" ]] || echo "date,mode,run,reconciliation,t_detect_s,t_ready_s,t_total_s" > "$OUT"
RECON="$(kubectl -n argocd get cm argocd-cm -o jsonpath='{.data.timeout\.reconciliation}')+$(kubectl -n argocd get cm argocd-cm -o jsonpath='{.data.timeout\.reconciliation\.jitter}')"

for i in $(seq 1 "$RUNS"); do
  MSG="hello run-$(date +%H%M%S)"
  perl -pi -e "s/^message: .*/message: \"$MSG\"/" "$VALUES"
  git add "$VALUES"
  git commit -q -m "poc/01-argocd: measure-sync $MODE $i/$RUNS ($MSG)"
  git push -q origin main
  T0=$(now)
  echo "[$i/$RUNS] push 완료: $MSG"

  if [[ "$MODE" == "refresh" ]]; then
    kubectl -n argocd annotate application "$APP" argocd.argoproj.io/refresh=normal --overwrite >/dev/null
  fi

  # Argo CD 가 새 문자열을 Deployment 에 적용할 때까지
  until kubectl -n "$NS" get deploy "$APP" -o jsonpath='{.spec.template.spec.containers[0].args}' 2>/dev/null | grep -q "$MSG"; do
    sleep 1
    (( $(perl -e "print int($(now) - $T0)") < TIMEOUT )) || { echo "시간 초과 (감지 단계)"; exit 1; }
  done
  T1=$(now)

  # 새 파드가 전부 Ready 될 때까지
  kubectl -n "$NS" rollout status deploy/"$APP" --timeout="${TIMEOUT}s" >/dev/null
  T2=$(now)

  D=$(perl -e "printf '%.1f', $T1-$T0"); R=$(perl -e "printf '%.1f', $T2-$T1"); TOT=$(perl -e "printf '%.1f', $T2-$T0")
  echo "  감지+적용 ${D}s / 파드 교체 ${R}s / 합계 ${TOT}s"
  echo "$(date +%F),$MODE,$i,$RECON,$D,$R,$TOT" >> "$OUT"
done

echo "결과: $OUT"
{ head -1 "$OUT"; tail -n "$RUNS" "$OUT"; } | column -s, -t
