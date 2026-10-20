로드맵 위치: 4주차 10/26 / 런북 RB-02 함수 폭주(노이지 네이버) / 본선 연결점: "멀티테넌트에서 한 테넌트가 폭주하면?" 질문에 쿼터 실측으로 답

# RB-02 함수 폭주 (노이지 네이버)

## 언제 이 문서를 여나
- 알림 `TenantQuotaNearLimit` (어느 테넌트의 어느 자원이 한도 90% 초과인지 라벨에 있다)
- 다른 테넌트 함수의 지연(p95) 상승, 또는 스케일업한 파드가 Pending
- ReplicaSet 이벤트 `FailedCreate ... exceeded quota`

## 영향 (대역 실측: 쿼터 있음 → 쿼터 없음)
| | 쿼터 있음 | 쿼터 없음 |
|---|---|---|
| 폭주 파드 30개 시도 중 실제로 뜬 수 | 2 | 14 (16개 Pending) |
| 쿼터가 막은 시각 / 알림 | 0.3s / 평균 10s | 없음 / 안 울림 |
| 옆 테넌트 함수 p95 | 3.3 → 7.4ms (약 2배) | 3.9 → 93.9ms (약 24배) |
| 옆 테넌트 함수 2→4개 늘리기 | 1.5~2.4s | 7.9s |

원본: `results/s2-noisy-neighbor.csv`, README 8.2.

## 1분 안에 확인
```bash
kubectl get resourcequota -A
#   USED/HARD 가 꽉 찬 테넌트 = 폭주 중인 쪽
kubectl -n <폭주 ns> get deploy,rs,pods
#   누가 파드를 늘렸나 (replicas, HPA/Knative 가 늘렸는지)
kubectl -n <폭주 ns> get events --field-selector reason=FailedCreate | tail -3
#   쿼터가 막고 있다는 증거
kubectl top pods -n <폭주 ns> --sort-by=cpu | head       # metrics-server 가 있으면
kubectl -n <피해 ns> get pods --field-selector status.phase=Pending
#   피해 테넌트가 자리를 못 잡는지
```

## 판단
| 보이는 것 | 뜻 | 할 일 |
|---|---|---|
| 폭주 ns 가 쿼터에 막혀 있고 피해 ns 는 정상 | 격리가 일한다 | 폭주 테넌트에만 연락·제한 (아래 1) |
| 피해 ns 파드가 Pending (`Insufficient cpu`) | 노드 자리가 찼다. 쿼터 합이 노드 용량보다 크다 (과다 할당) | 1 + 쿼터 합 재계산 |
| Pending 은 없는데 피해 ns p95 상승 | CPU 를 뺏겼다 (limits 가 없거나 너무 큼) | 1 + LimitRange 확인 |

## 조치
1. 폭주 함수를 멈춘다: `kubectl -n <폭주 ns> scale deploy <함수> --replicas=0` (Knative 면 `autoscaling.knative.dev/max-scale` 을 낮춤). GitOps 로 관리되면 selfHeal 이 되돌리므로 Git 에서 바꾸거나 Application 의 자동 동기화를 잠깐 끈다.
2. 피해 테넌트 스케일업이 막혀 있었다면 폭주를 멈춘 뒤 Pending 이 풀리는지 본다.
3. 원인(무한 루프, 재시도 폭주)을 테넌트에게 전달. 플랫폼이 할 일은 "한 테넌트의 버그가 다른 테넌트로 번지지 않게" 까지.

## 복구 확인
```bash
kubectl get resourcequota -A                         # 폭주 ns 사용량 내려옴
kubectl -n <피해 ns> get pods                         # Pending 없음
```

## 재발 방지
- 테넌트마다 ResourceQuota(requests/limits/pods) + LimitRange(기본값, 최대치) — 3단계
- **쿼터 합 ≤ 노드 풀 용량** 을 지킨다 (안 지키면 "쿼터 안에서" 노드 자리를 다 가져갈 수 있다). 대역: 테넌트 2개 × requests.cpu 1 = 2코어 ≤ exec 2대
- PriorityClass: 플랫폼 부품(게이트웨이, 컨트롤러)은 테넌트 함수보다 우선 → 자리가 없으면 함수부터 밀려나게
- 비용 관점: 쿼터 = 테넌트별 과금 상한과 같은 숫자로 맞추면 설계 문서에서 한 줄로 설명된다

## 기록할 것
폭주 시작 시각, 쿼터가 막은 시각(이벤트), 알림 시각, 피해 테넌트 p95 전/중 → `results/s2-noisy-neighbor.csv`
