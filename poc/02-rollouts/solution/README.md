# solution: 2단계 정답본

- 원래 자리(`poc/02-rollouts/` 아래)와 **폴더 구조가 같다**. 같은 경로끼리 비교: `diff -r poc/02-rollouts/app poc/02-rollouts/solution/app`
- 쓰는 때: 한 파일에 30분 넘게 막혔을 때, 또는 다 채운 뒤 비교할 때.
- 막혀서 쓸 땐 그 파일만 원래 자리에 복사한다. 예: `cp poc/02-rollouts/solution/app/rollout.yaml poc/02-rollouts/app/`
- Argo CD 는 `solution/` 이 아니라 **원래 자리**(`poc/02-rollouts/app`)를 읽는다. solution 의 Application 도 원래 자리를 가리킨다.
- 결정 값(컨트롤러 1개, steps 20%→60s→60%→60s, scrape 10s, 합격선 0.95 / failureLimit 1)은 "하나의 답"일 뿐이다. 다르게 골랐으면 이유와 측정값으로 설명하면 된다.
- 검증 범위는 README 6절. 요약: Helm 렌더, CRD 스키마(server dry-run), PromQL, 실제 Rollouts 컨트롤러의 AnalysisRun 판정까지 확인. kind 위 전체 흐름은 【미검증】.
