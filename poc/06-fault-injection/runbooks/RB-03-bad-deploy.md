로드맵 위치: 4주차 10/26 / 런북 RB-03 나쁜 버전 배포 / 본선 연결점: 라이브 데모의 "나쁜 버전 push → 자동 롤백" 장면 대본

# RB-03 나쁜 버전 배포 → 자동 롤백 후 정리

## 언제 이 문서를 여나
- 알림 `RolloutAborted`
- Argo CD 화면에서 Application 이 Degraded (Synced 인데 Degraded = Git 대로 적용했지만 Rollouts 가 거부)
- `kubectl argo rollouts get rollout <이름>` 에 `Degraded` / `RolloutAborted`

## 영향 (대역 실측)
| | 분석 정상 (3회) | 분석이 안정 버전을 봄 (실수) |
|---|---|---|
| 감지 = abort | 평균 17.0s | 못 잡음, 나쁜 버전 59초 만에 100% |
| 나쁜 파드 0개 | 평균 18.1s | 되돌릴 때까지 계속 |
| 알림 `RolloutAborted` | 평균 39s | 안 울림 |
| 사용자 에러 (카나리 25%) | 평균 29개 / 16s | 60초에 195개 (29.6%) |

분석이 틀린 상태에서 좋은 버전으로 되돌리면 **그 좋은 버전이 abort 된다** (분석이 지금 안정 버전 = 나쁜 버전을 봄). 분석 고치고 retry (아래 3). 원본: `results/s3-bad-deploy.csv`, README 8.3.

## 1분 안에 확인
```bash
kubectl -n <ns> get rollout <이름>
#   PHASE Degraded, 그리고 STATUS 메시지에 "RolloutAborted"
kubectl -n <ns> get analysisrun --sort-by=.metadata.creationTimestamp | tail -3
#   맨 아래 Failed 가 이번 것
kubectl -n <ns> describe analysisrun <이름> | grep -A5 'Metric Results'
#   어느 지표가 몇 번 실패했나 (job 이면 실패한 Job 의 로그: kubectl -n <ns> logs job/<이름>)
kubectl -n <ns> get rs -l rollouts-pod-template-hash --show-labels
#   나쁜 버전 ReplicaSet 이 0 으로 줄었는지
```

## 판단
| 보이는 것 | 뜻 | 할 일 |
|---|---|---|
| abort, 나쁜 파드 0, 안정 버전 다 Ready | 자동 롤백 끝. 사용자 영향 끝 | Git 정리 (아래 1) |
| 분석 Failed 인데 원인이 앱이 아니라 분석 쪽 (Prometheus 응답 없음, Job 이 이미지를 못 받음) | 거짓 롤백 | 분석 고치고 retry (아래 3) |
| abort 없이 100% 승격 | 분석이 못 잡았다 | 즉시 1 로 되돌리고 분석 기준 재검토 (README 6 깨뜨리기와 같은 상황) |

## 조치
1. **Git 을 좋은 버전으로**: Rollouts 의 롤백은 클러스터 안에서만이다. Git 은 아직 나쁜 버전이다.
   ```bash
   git log --oneline -5                  # 나쁜 버전을 넣은 커밋 찾기
   git revert <커밋>                     # 그 커밋을 거꾸로 하는 새 커밋 (히스토리를 지우지 않는다)
   git push origin main
   ```
   Argo CD 가 되돌린 값을 적용하면 Rollout 의 spec 이 안정 버전과 같아져서 바로 Healthy 로 돌아온다 (새 배포가 아니라 "원래 것").
2. 고친 버전을 다시 낼 땐 새 커밋으로. 같은 나쁜 커밋을 다시 push 하지 않는다.
3. 거짓 롤백이었다면: 분석을 고친 뒤 `kubectl argo rollouts retry rollout <이름> -n <ns>`.
4. **하지 말 것**: abort 상태에서 `kubectl argo rollouts promote --full` — 분석을 건너뛰고 나쁜 버전을 100% 로 만든다.

## 복구 확인
```bash
kubectl -n <ns> get rollout <이름>      # Healthy
kubectl -n argocd get application <앱>  # Synced / Healthy
```

## 재발 방지
- 분석 기준 = "몇 초 만에, 몇 번 실패를 보고 결정할지". 간격·count·failureLimit 를 줄일수록 사용자 에러는 줄고 거짓 롤백은 늘어난다. 결정 표에 숫자로
- 카나리 첫 단계를 더 작게(25% → 10%): 같은 감지 시간에 피해 요청이 줄어든다
- CI 에서 컨테이너 기동 시 스모크 테스트: 아예 500 을 내는 버전은 카나리까지 오기 전에 막는다

## 기록할 것
push 시각, 카나리 시작, 분석 실패, abort, 나쁜 파드 0, 프로브 에러 수, git revert 커밋 → `results/s3-bad-deploy.csv`
