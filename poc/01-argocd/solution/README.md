# solution: 1단계 정답본

- 원래 자리(`poc/01-argocd/` 아래)와 **폴더 구조가 같다**. 같은 경로 파일끼리 비교하면 된다:
  `diff -r poc/01-argocd/functions poc/01-argocd/solution/functions`
- 쓰는 때: 한 파일에 30분 넘게 막혔을 때, 또는 다 채운 뒤 비교할 때. 먼저 보면 오늘 실습의 의미가 없다.
- 막혀서 쓸 땐 그 파일만 원래 자리에 복사한다. 예: `cp poc/01-argocd/solution/gitops/apps/hello-fn.yaml poc/01-argocd/gitops/apps/`
- Argo CD 는 `solution/` 이 아니라 **원래 자리**(`poc/01-argocd/functions/hello-fn`, `poc/01-argocd/gitops/apps`)를 읽는다. solution 의 Application 도 원래 자리를 가리킨다.
- 결정 값(reconciliation 60s+0s, prune·selfHeal 둘 다 true, replicaCount 2)은 "하나의 답"일 뿐이다. 다르게 골랐으면 이유와 측정값으로 설명하면 된다.
- 검증: `helm lint solution/functions/hello-fn` 통과, Argo CD values 는 차트 10.10.5 로 `helm template` 렌더 확인 (Deployment 4 + StatefulSet 1).
