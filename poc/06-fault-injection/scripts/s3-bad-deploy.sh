#!/usr/bin/env bash
# 시나리오 3: 나쁜 버전 배포 → Argo Rollouts 자동 롤백 — Claude 작성, 완성본
#
#   ./scripts/s3-bad-deploy.sh kubectl [회수]   스크립트가 Rollout 을 직접 고쳐서 나쁜 버전을 넣는다 (Argo CD 가 안 붙은 대역 대상용)
#   ./scripts/s3-bad-deploy.sh git              Jeong 이 나쁜 값으로 커밋+push 하고 엔터 → 그때부터 잰다 (진짜 GitOps 경로)
#
# 잰 것 (t0 = 나쁜 버전을 넣은 순간, git 모드는 push 직후 엔터 친 순간)
#   t_canary_s   : 나쁜 버전 파드가 처음 생긴 시각  (git 모드면 Argo CD 가 알아채는 시간 포함)
#   t_failed_s   : AnalysisRun 이 Failed 가 된 시각  (= 감지)
#   t_abort_s    : Rollout 이 abort 한 시각 (status.abort=true, 나쁜 파드에 트래픽 끊김) (= 복구 시작)
#   t_stable_s   : 나쁜 파드가 다 사라지고 안정 버전만 남은 시각 (= 복구 끝)
#   t_alert_s    : (Prometheus 있으면) RolloutAborted 알림 firing
#   errors       : 그 사이 프로브(사용자)가 받은 5xx·타임아웃 수
#
# 왜 git 모드가 따로 있나: Argo CD 가 selfHeal 로 Rollout 을 지키고 있으면 kubectl 로 고친 값은 몇 초 만에 Git 값으로 되돌려진다.
#   그러면 "Rollouts 가 롤백했다" 가 아니라 "Argo CD 가 되돌렸다" 를 재게 된다. 진짜 클러스터에선 git 모드로.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

MODE="${1:-kubectl}"; RUNS="${2:-1}"
ALERT="${ALERT_ROLLOUT:-RolloutAborted}"
# kubectl 모드에서 넣을 나쁜 버전 / 되돌릴 좋은 버전 (대역 대상 = http-echo 의 args). 대상이 다르면 덮어쓴다
# 나쁜 버전 문자열에 BADTAG(회차마다 다른 값)를 넣는 이유: 매번 다른 파드 템플릿 해시가 되게.
#   같은 해시로 다시 넣으면 Rollouts 가 지난번 실패한 분석 결과를 재사용해서 감지 시간이 0초처럼 찍힌다 (실제로 밟았다)
BAD_ARGS_TMPL="${BAD_ARGS:-[\"-text=api v2-bad BADTAG\",\"-status-code=500\",\"-listen=:5678\"]}"
GOOD_ARGS="${GOOD_ARGS:-[\"-text=api v1\",\"-status-code=200\",\"-listen=:5678\"]}"
BASELINE="${BASELINE:-15}"
TIMEOUT="${TIMEOUT:-600}"
CSV="$RESULTS/s3-bad-deploy.csv"
show_ctx

R() { kubectl -n "$ROLLOUT_NS" get rollout "$ROLLOUT" -o jsonpath="$1" 2>/dev/null; }
set_args() {
  kubectl -n "$ROLLOUT_NS" patch rollout "$ROLLOUT" --type json \
    -p "[{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/args\",\"value\":$1}]" >/dev/null
}

[ "$(R '{.status.phase}')" = "Healthy" ] || die "Rollout $ROLLOUT_NS/$ROLLOUT 가 Healthy 가 아니다 ($(R '{.status.phase}')). 먼저 정상으로"
if [ "$MODE" = kubectl ] && [ -n "$(R '{.metadata.annotations.argocd\.argoproj\.io/tracking-id}')$(R '{.metadata.labels.app\.kubernetes\.io/instance}')" ] && [ -z "${FORCE:-}" ]; then
  die "이 Rollout 은 Argo CD 가 관리한다 → selfHeal 이 kubectl 수정을 되돌린다. git 모드로 돌리거나, 알고 하는 거면 FORCE=1"
fi
[ "$MODE" = git ] && RUNS=1

for i in $(seq 1 "$RUNS"); do
  STABLE=$(R '{.status.stableRS}'); DESIRED=$(R '{.spec.replicas}')
  log "[$i/$RUNS] 모드 $MODE / $ROLLOUT_NS/$ROLLOUT 안정 버전 해시 $STABLE, 파드 $DESIRED 개"
  probe_name="s3-$MODE-$i"
  "$(dirname "$0")/probe.sh" start "$probe_name" "$ROLLOUT_NS" "$ROLLOUT_URL"
  log "  평소 상태 ${BASELINE}초 재는 중"; sleep "$BASELINE"

  # 지난 회차의 AnalysisRun 은 "이번 것" 으로 세지 않게 이름을 적어 둔다
  OLD_AR=" $(kubectl -n "$ROLLOUT_NS" get analysisrun -o jsonpath='{.items[*].metadata.name}' 2>/dev/null) "
  if [ "$MODE" = kubectl ]; then
    BAD_ARGS=$(echo "$BAD_ARGS_TMPL" | sed "s/BADTAG/$(date +%H%M%S)/")
    T0=$(now); log "  t0: 나쁜 버전 넣음 (args → $BAD_ARGS)"
    set_args "$BAD_ARGS"
  else
    echo
    echo "  지금 다른 터미널에서 나쁜 버전을 커밋하고 push 해. push 가 끝나면 여기서 엔터."
    read -r _
    T0=$(now); log "  t0: push 완료"
    [ -n "${APP:-}" ] && kubectl -n argocd annotate application "$APP" argocd.argoproj.io/refresh=normal --overwrite >/dev/null && log "  Argo CD Application $APP 강제 새로고침"
  fi

  T_CANARY=""; T_FAILED=""; T_ABORT=""; T_STABLE=""; T_ALERT=""; BADHASH=""
  while :; do
    T=$(now)
    cur=$(R '{.status.currentPodHash}')
    if [ -z "$T_CANARY" ] && [ -n "$cur" ] && [ "$cur" != "$STABLE" ]; then
      BADHASH="$cur"; T_CANARY=$(since "$T0" "$T"); log "  나쁜 버전 파드 생성 시작 (해시 $BADHASH): +${T_CANARY}s"
    fi
    if [ -n "$BADHASH" ] && [ -z "$T_FAILED" ]; then
      ph=$(kubectl -n "$ROLLOUT_NS" get analysisrun -l rollouts-pod-template-hash="$BADHASH" \
             -o jsonpath='{range .items[*]}{.metadata.name} {.status.phase}{"\n"}{end}' 2>/dev/null \
           | while read -r n p; do case "$OLD_AR" in *" $n "*) ;; *) echo "$p";; esac; done | tr '\n' ' ')
      case "$ph" in *Failed*|*Error*) T_FAILED=$(since "$T0" "$T"); log "  분석 실패 ($ph) = 감지: +${T_FAILED}s";; esac
    fi
    if [ -z "$T_ABORT" ] && [ "$(R '{.status.abort}')" = "true" ]; then
      T_ABORT=$(since "$T0" "$T"); log "  Rollout abort (자동 롤백 시작): +${T_ABORT}s"
    fi
    if [ -n "$T_ABORT" ] && [ -z "$T_STABLE" ]; then
      badready=$(kubectl -n "$ROLLOUT_NS" get rs -l rollouts-pod-template-hash="$BADHASH" -o jsonpath='{.items[0].status.replicas}' 2>/dev/null || echo 0)
      avail=$(R '{.status.availableReplicas}')
      if [ "${badready:-0}" = "0" ] && [ "${avail:-0}" -ge "$DESIRED" ]; then
        T_STABLE=$(since "$T0" "$T"); log "  나쁜 파드 0개, 안정 버전 $avail 개: +${T_STABLE}s"
      fi
    fi
    if [ -z "$T_ALERT" ]; then
      a=$(alert_firing "$ALERT")
      if [ "$a" = "1" ]; then T_ALERT=$(since "$T0" "$T"); log "  알림 $ALERT firing: +${T_ALERT}s"
      elif [ "$a" = "-1" ]; then T_ALERT="n/a"; fi
    fi
    [ -n "$T_STABLE" ] && [ -n "$T_ALERT" ] && break
    # 복구가 끝났는데 알림이 90초 넘게 안 오면 "안 옴" 으로 기록하고 끝낸다 (규칙 expr 이 틀렸을 가능성 → README 3절)
    if [ -n "$T_STABLE" ] && [ -z "$T_ALERT" ] && [ "$(perl -e "print int($T - $T0 - $T_STABLE)")" -ge 90 ]; then
      T_ALERT="none"; log "  알림 $ALERT 이 복구 후 90초 안에 안 왔다 (규칙 확인)"; break
    fi
    if [ "$(R '{.status.phase}')" = "Healthy" ] && [ -n "$BADHASH" ] && [ "$(R '{.status.stableRS}')" = "$BADHASH" ]; then
      log "  !! 나쁜 버전이 100% 승격됐다 (분석이 못 잡음)"; T_FAILED="${T_FAILED:-missed}"; T_ABORT="${T_ABORT:-missed}"; T_STABLE="promoted-bad"; T_ALERT="${T_ALERT:-}"; break
    fi
    if [ "$(perl -e "print int($T - $T0)")" -ge "$TIMEOUT" ]; then
      log "  ${TIMEOUT}초 초과"; T_CANARY="${T_CANARY:-timeout}"; T_FAILED="${T_FAILED:-timeout}"; T_ABORT="${T_ABORT:-timeout}"; T_STABLE="${T_STABLE:-timeout}"; T_ALERT="${T_ALERT:-timeout}"; break
    fi
    sleep 1
  done
  sleep 5
  "$(dirname "$0")/probe.sh" stop "$probe_name" "$ROLLOUT_NS"

  if [ "$MODE" = kubectl ]; then
    log "  정리: 좋은 버전으로 되돌림 (Git 에 커밋을 되돌리는 것과 같은 일)"
    set_args "$GOOD_ARGS"
    for s in $(seq 1 60); do [ "$(R '{.status.phase}')" = "Healthy" ] && break; sleep 2; done
    log "  Rollout phase: $(R '{.status.phase}')"
  else
    log "  정리: git revert <나쁜 커밋> && git push 로 Git 을 좋은 버전으로 되돌려야 Argo CD 가 Synced 로 돌아온다 (RB-03 참고)"
  fi

  python3 "$(dirname "$0")/analyze.py" --log "$RESULTS/$probe_name.probe.log" --t0 "$T0" --window 60 --csv "$CSV" \
    --extra "label=$LABEL,mode=$MODE,run=$i,replicas=$DESIRED,t_canary_s=$T_CANARY,t_failed_s=$T_FAILED,t_abort_s=$T_ABORT,t_stable_s=$T_STABLE,t_alert_s=$T_ALERT"
  sleep 5
done
