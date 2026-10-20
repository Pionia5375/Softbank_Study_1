로드맵 위치: 3주차 10/23 / 테넌트 격리 정답본 / 본선 연결점: 막혔을 때 30분 규칙용

# solution/ (정답본)

- 상위 폴더와 같은 구조: `charts/tenant/`, `tenants/`, `gitops/`.
- 한 파일에 30분 넘게 막히면 같은 경로 파일을 본다. 본 다음 "왜 이 값인지" 를 스레드에서 물어본다.
- 정답본 ApplicationSet 을 통째로 붙이고 싶으면: `kubectl apply -f poc/03-tenant-isolation/solution/gitops/tenants-appset.yaml`
  - 이건 `solution/charts/tenant` 와 `solution/tenants/*.yaml` 을 본다.
  - **Jeong 의 `gitops/tenants-appset.yaml` 과 동시에 붙이지 말 것.** 둘 다 tenant-a·tenant-b 라는 Application 과 AppProject 를 만들려고 싸운다. 바꿀 땐 먼저 `kubectl -n argocd delete applicationset tenants`.
- `measure.sh onboard` 를 정답본으로 돌릴 땐 `SOLUTION=1` 을 앞에 붙인다.
- 정답본 결정값: limitsCpu `"2"` (tenant-b `"1"`), LimitRange 기본 CPU `200m`, Pod Security enforce `baseline` / warn `restricted`, secrets 권한 없음, ApplicationSet `applicationsSync: sync`.

## 핵심 결정 3개 (+대안)
상위 README 6절과 같다.

## 셀프 연습 1개
상위 README 9절 (L7 CiliumNetworkPolicy). 정답본은 일부러 두지 않는다.

## 검증 명령과 기대 출력
```bash
cd poc/03-tenant-isolation/solution
helm template tenant-a charts/tenant -f tenants/tenant-a.yaml | grep '^kind:' | sort | uniq -c
# 기대: AppProject 1, LimitRange 1, Namespace 1, NetworkPolicy 3, ResourceQuota 1, Role 1, RoleBinding 1, ServiceAccount 1
```
