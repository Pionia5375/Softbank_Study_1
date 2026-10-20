로드맵 위치: 4주차 10/26 / 런북 RB-01 실행 노드 다운 / 본선 연결점: 데모 중 노드가 죽어도 이 순서로 2분 안에 설명·복구

# RB-01 실행 노드 다운 (스팟 회수 포함)

## 언제 이 문서를 여나
- 알림 `FnNodeNotReady` (critical) 또는 `FnReplicasUnavailable` (warning)
- 사용자 증상: 요청 일부가 응답 없음(타임아웃). 전부가 아니라 "절반쯤" 이면 노드 하나를 의심

## 영향 (대역 실측, 방어 전 → 방어 후)
| | 방어 전 (기본값) | 방어 후 (tolerationSeconds 20 + 흩어 놓기 + PDB 1) |
|---|---|---|
| NotReady 판정 (감지) | 평균 46s | 평균 50s (같음, 파드 설정으론 못 줄임) |
| 알림 `FnNodeNotReady` | 53s | 60s |
| 파드 수 복구 | **347s** | **71s** |
| 사용자 에러 / 본 장애 (0.1초 간격 프로브) | 38개 / 46s | 41개 / 49s |
| 예고 있는 spot (drain 후 정지) | 0~3개 | 0~3개. 단 PDB=replicas 면 drain 이 110초 막혀 에러 87개 |

사용자 장애를 줄이는 건 tolerationSeconds 가 아니라 "미리 비우기"(spot drain)와 앞단 재시도다. 원본: `results/s1-node-down.csv`, README 8.1.

## 1분 안에 확인
```bash
kubectl get nodes -L pool
#   STATUS 가 NotReady 인 노드, 그 노드의 pool 확인
kubectl get pods -A -o wide --field-selector spec.nodeName=<노드>
#   그 노드에 있던 파드. Terminating 에 멈춰 있어도 정상 (노드가 없어서 지운 걸 확인해 줄 kubelet 이 없다)
kubectl -n <테넌트 ns> get deploy,rollout
#   READY 가 원하는 수만큼 찼나
kubectl get events -A --field-selector reason=TaintManagerEviction --sort-by=.lastTimestamp | tail
#   tolerationSeconds 가 지나 쫓겨난 파드 기록
```

## 판단
| 보이는 것 | 뜻 | 할 일 |
|---|---|---|
| 노드 NotReady, 다른 노드에서 파드가 다 찼다 | 자동 복구 끝 | 노드만 처리 (아래 3) |
| NotReady 인데 파드가 안 옮겨 간다 (아직 Running 으로 보임) | tolerationSeconds 가 아직 안 지남 (기본 300s) | 기다리거나, 급하면 2 |
| 새 파드가 Pending | 옮겨 갈 자리가 없다: exec 노드가 1대뿐, 쿼터, 또는 topologySpread DoNotSchedule | `kubectl describe pod` Events 확인 → 노드 추가 또는 제약 완화 |
| spot drain 이 안 끝남 | PDB 가 막음 (minAvailable = replicas) | `kubectl get pdb -A` 의 ALLOWED DISRUPTIONS 0 확인 → PDB 고치기 |

## 조치
1. **자동으로 되는 것**: NotReady 후 Service 에서 빠짐(약 50초) → tolerationSeconds 뒤 다른 노드에 재생성.
2. **급할 때 손으로 당기기**: 노드가 안 돌아올 게 확실하면 `kubectl delete node <노드>` → 그 노드 파드가 즉시 정리되고 바로 재생성된다. (노드가 살아 돌아오면 kubelet 이 다시 등록한다)
3. **노드 처리**: kind = `docker unpause <노드>` 또는 `docker restart <노드>`. EC2 = 오토스케일링 그룹이 새 인스턴스를 띄우는지 확인.
4. Argo CD 는 손대지 않는다. 노드 문제는 Git 과 상관이 없어서 Synced 로 보이는 게 정상.

## 복구 확인
```bash
kubectl get nodes                                   # 전부 Ready (또는 죽은 노드가 목록에서 빠짐)
kubectl -n <ns> rollout status deploy/<함수>        # successfully rolled out
```
프로브를 켜 두었다면 에러가 0 으로 돌아왔는지 본다.

## 재발 방지 (이미 넣은 것 / 다음 것)
- 넣은 것: tolerationSeconds 단축, topologySpreadConstraints(ScheduleAnyway), PDB minAvailable 1 → `defenses/`
- 다음 것: (1) exec 노드 2대 이상 + AZ 2개 (EC2, 7단계). (2) 앞단 재시도: 노드가 NotReady 로 판정되기 전 약 50초의 실패는 쿠버네티스 설정으로는 못 줄인다. 게이트웨이(Kourier/Envoy)의 재시도·아웃라이어 감지가 그 구간을 메운다 【추정】 측정 전. (3) 스팟 회수 처리기(AWS Node Termination Handler 또는 Karpenter)로 hard 를 spot 으로 바꾸기.

## 기록할 것
t0(알림 시각에서 역산), 감지(알림) 시각, 파드 복구 시각, 프로브 에러 수 → `results/s1-node-down.csv` 와 같은 열로.
