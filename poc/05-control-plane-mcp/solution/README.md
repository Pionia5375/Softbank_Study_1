# solution: 5단계 정답본

- 원래 자리(`poc/05-control-plane-mcp/` 아래)와 **경로가 같다**. 같은 경로 파일끼리 비교하면 된다:
  `diff -r poc/05-control-plane-mcp/k8s poc/05-control-plane-mcp/solution/k8s`
- 들어 있는 것: Jeong 이 채우는 파일 10개만 (배포 엔드포인트, 템플릿 2, scale 도구, 매니페스트 6). 나머지는 원래 자리가 이미 완성본이다.
- 쓰는 때: 한 파일에 30분 넘게 막혔을 때, 또는 다 채운 뒤 비교할 때. 막혀서 쓸 땐 그 파일만 원래 자리에 복사한다.
  예: `cp poc/05-control-plane-mcp/solution/k8s/platform/ops-agent/rbac.yaml poc/05-control-plane-mcp/k8s/platform/ops-agent/`
- Argo CD 는 `solution/` 이 아니라 **원래 자리**(`k8s/platform`)를 읽는다.
- 결정 값(backoffLimit 0, max-scale 5, faas-build 는 baseline)은 "하나의 답" 이다. 다르게 골랐으면 이유와 측정값으로 설명하면 된다.
- 검증: `scripts/check-solution.sh` 가 임시 폴더에 정답본을 덮어써서 `./mvnw test`(8개)와 `pytest`(19개)를 돌린다. 10/20 Claude 컨테이너에서 둘 다 통과. 매니페스트는 kubeconform 스키마 검사 통과. 진짜 kind 클러스터 실행은 【미검증】 (README 마지막 표).
