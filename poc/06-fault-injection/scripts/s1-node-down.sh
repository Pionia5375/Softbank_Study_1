#!/usr/bin/env bash
# 시나리오 1: 실행 노드 다운 (스팟 회수 흉내) — Claude 작성, 완성본
#
#   ./scripts/s1-node-down.sh hard [회수]   예고 없이 노드가 멈춘다 (전원 차단, 커널 패닉, 스팟 회수 처리기 없음)
#   ./scripts/s1-node-down.sh spot [회수]   2분 예고를 받고 비운 뒤 멈춘다 (스팟 회수 처리기가 있는 경우)
#
# 한 회에 하는 일
#   1. 피해자 함수 파드가 떠 있는 exec 노드 하나를 고른다
#   2. 프로브 시작, 20초 동안 평소 상태를 잰다
#   3. t0 = 주입.  hard: docker pause <노드>   spot: cordon + drain(최대 110초) → docker pause
#      docker pause = 노드 컨테이너의 모든 프로세스를 얼린다. kubelet 이 하트비트를 못 보내고, 그 노드 파드로 간 요청은 응답이 없다.
#      docker stop 대신 pause 를 쓰는 이유: kind 노드는 stop/start 하면 IP 가 바뀌어 클러스터가 꼬일 수 있다. unpause 는 깨끗이 돌아온다.
#   4. 1초마다 확인: 노드 NotReady 가 된 시각, 죽은 노드 밖에서 파드 수가 원래대로 찬 시각, (있으면) 알림 firing 시각
#   5. 노드를 되살리고(unpause, uncordon) 프로브 로그를 분석해 results/s1-node-down.csv 에 한 줄
#
# 이 스크립트는 노드 컨테이너를 직접 얼린다 = kind 전용. EC2(7단계)에선 인스턴스를 멈추는 걸로 바꿔야 한다.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
need docker

MODE="${1:-hard}"; RUNS="${2:-1}"
[ "$MODE" = hard ] || [ "$MODE" = spot ] || die "모드는 hard 또는 spot"
ALERT="${ALERT_NODE:-FnNodeNotReady}"
BASELINE="${BASELINE:-20}"     # 주입 전 평소 상태를 재는 초
TIMEOUT="${TIMEOUT:-600}"      # 복구를 이만큼 넘게 기다리면 실패로 기록
CSV="$RESULTS/s1-node-down.csv"
show_ctx

# 피해자 파드 목록: "노드 Ready여부 지우는중" 한 줄씩. 지우는 중(Terminating)인 파드는 셋째 칸에 시각이 찍힌다
pods() {
  kubectl -n "$FN_NS" get pods -l "$FN_SELECTOR" -o jsonpath='{range .items[*]}{.spec.nodeName} {.status.conditions[?(@.type=="Ready")].status} {.metadata.deletionTimestamp}{"\n"}{end}'
}
ready_on_other() {  # 죽인 노드가 아닌 곳에서 Ready 인 피해자 파드 수
  pods | awk -v n="$1" '$1!=n && $2=="True" && $3=="" {c++} END {print c+0}'
}

for i in $(seq 1 "$RUNS"); do
  DESIRED=$(kubectl -n "$FN_NS" get deploy "$FN_NAME" -o jsonpath='{.spec.replicas}')
  # 지난 회차의 Terminating 파드가 남아 있으면 엉뚱한 노드를 고르니, 다 사라질 때까지 기다린다
  for s in $(seq 1 60); do [ "$(pods | awk '$3!=""' | wc -l | tr -d ' ')" = 0 ] && break; sleep 2; done
  # 살아 있는(Ready, 지우는 중 아님) 피해자 파드가 있는 노드 하나
  NODE=$(pods | awk '$2=="True" && $3=="" {print $1; exit}')
  [ -n "$NODE" ] || die "$FN_NS 에 Ready 인 $FN_SELECTOR 파드가 없다"
  ELIGIBLE=$(kubectl get nodes -l "$EXEC_LABEL" --no-headers | grep -c ' Ready' || true)
  ONNODE=$(pods | awk -v n="$NODE" '$1==n && $2=="True" && $3=="" {c++} END {print c+0}')
  log "[$i/$RUNS] 모드 $MODE / 대상 노드 $NODE (그 노드의 피해자 파드 $ONNODE/$DESIRED, $EXEC_LABEL 노드 $ELIGIBLE 대)"
  [ "$ELIGIBLE" -ge 2 ] || log "  주의: $EXEC_LABEL 노드가 1대뿐이다 → 옮겨 갈 곳이 없어 '전면 장애 + 노드가 돌아올 때까지 복구 불가' 가 정답인 실험이 된다"

  probe_name="s1-$MODE-$i"
  "$(dirname "$0")/probe.sh" start "$probe_name" "$FN_NS" "$FN_URL"
  log "  평소 상태 ${BASELINE}초 재는 중"; sleep "$BASELINE"

  T0=$(now); DRAIN_S=""
  if [ "$MODE" = spot ]; then
    log "  t0: 스팟 회수 예고 → cordon + drain (PDB 를 지키며 비운다, 최대 110초)"
    kubectl cordon "$NODE" >/dev/null
    if kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --timeout=110s >/dev/null 2>&1; then
      DRAIN_S=$(since "$T0" "$(now)")
      log "  drain 완료 ${DRAIN_S}s"
    else
      DRAIN_S="timeout"
      log "  drain 이 110초 안에 안 끝났다 (PDB 가 막았거나 옮길 곳이 없음). 예고 시간이 끝났으니 그대로 멈춘다"
    fi
  else
    log "  t0: 예고 없이 노드 정지 (docker pause $NODE)"
  fi
  docker pause "$NODE" >/dev/null
  T_PAUSE=$(now)

  T_NOTREADY=""; T_REPLACED=""; T_ALERT=""
  while :; do
    T=$(now)
    if [ -z "$T_NOTREADY" ]; then
      st=$(kubectl get node "$NODE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
      [ "$st" != "True" ] && T_NOTREADY=$(since "$T0" "$T") && log "  노드 NotReady (status=$st): +${T_NOTREADY}s"
    fi
    if [ -z "$T_REPLACED" ] && [ "$(ready_on_other "$NODE")" -ge "$DESIRED" ]; then
      T_REPLACED=$(since "$T0" "$T"); log "  다른 노드에서 파드 $DESIRED 개 Ready: +${T_REPLACED}s"
    fi
    if [ -z "$T_ALERT" ]; then
      a=$(alert_firing "$ALERT")
      if [ "$a" = "1" ]; then T_ALERT=$(since "$T0" "$T"); log "  알림 $ALERT firing: +${T_ALERT}s"
      elif [ "$a" = "-1" ]; then T_ALERT="n/a"; fi
    fi
    if [ -n "$T_NOTREADY" ] && [ -n "$T_REPLACED" ] && [ -n "$T_ALERT" ]; then break; fi
    if [ "$(perl -e "print int($T - $T0)")" -ge "$TIMEOUT" ]; then
      log "  ${TIMEOUT}초 안에 복구 안 됨 → timeout 으로 기록"
      T_NOTREADY="${T_NOTREADY:-timeout}"; T_REPLACED="${T_REPLACED:-timeout}"; T_ALERT="${T_ALERT:-timeout}"; break
    fi
    sleep 1
  done
  sleep 10   # 복구 뒤 10초는 더 지켜본다

  "$(dirname "$0")/probe.sh" stop "$probe_name" "$FN_NS"
  log "  노드 되살리는 중 (docker unpause, uncordon)"
  docker unpause "$NODE" >/dev/null
  kubectl uncordon "$NODE" >/dev/null
  kubectl wait --for=condition=Ready node/"$NODE" --timeout=120s >/dev/null
  # 다음 회차를 위해 파드를 다시 고르게 퍼뜨린다 (안 하면 다음 회차엔 한 노드에 몰려 있다)
  kubectl -n "$FN_NS" rollout restart deploy/"$FN_NAME" >/dev/null
  kubectl -n "$FN_NS" rollout status deploy/"$FN_NAME" --timeout=120s >/dev/null

  python3 "$(dirname "$0")/analyze.py" --log "$RESULTS/$probe_name.probe.log" --t0 "$T0" --window 120 --csv "$CSV" \
    --extra "label=$LABEL,mode=$MODE,run=$i,node=$NODE,pods_on_node=$ONNODE/$DESIRED,exec_nodes=$ELIGIBLE,drain_s=$DRAIN_S,t_notready_s=$T_NOTREADY,t_replaced_s=$T_REPLACED,t_alert_s=$T_ALERT"
done
