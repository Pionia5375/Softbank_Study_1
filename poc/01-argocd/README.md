로드맵 위치: 3주차 10/21 (수) / Argo CD + App of Apps / 본선 연결점: 본선 첫날 팀 환경을 "git push 하면 클러스터가 따라오는" 상태로 통일하고, 10/22 자동 롤백·10/23 테넌트·10/27 EC2 이전이 전부 이 위에 올라간다

# PoC 1단계: Argo CD 로 함수 하나 GitOps 배포하기

오늘 끝나면 되는 것 3개
1. `git push` 한 번에 함수(hello-fn)가 바뀌고, 그게 몇 초 걸리는지 숫자가 있다 (polling 3회, 강제 새로고침 3회)
2. 누가 kubectl 로 손대면 Argo CD 가 되돌리는 장면을 직접 봤다 (selfHeal)
3. root Application 하나만 apply 하면 나머지가 따라오는 App of Apps 구조가 있다

진행 방식
- 개념(1절) → 파일 지도(2절) → 단계마다: 파일 주석을 위에서 아래로 읽기 → 빈칸 채우기 → 명령(한 줄씩 설명 있음) → 확인 질문 → 출력 붙여 주기.
- 빈칸은 밑줄 세 개(`___`)와 `TODO(human)` 주석으로 표시. 공식 문서 링크는 각 파일 맨 위에 있다.
- 한 파일에 30분 넘게 막히면 `solution/` 의 같은 경로 파일을 본다 (`solution/README.md` 참고). 그다음 왜 그 값인지 스레드에서 한 줄씩 설명받는다.
- 다음 단계(02 Rollouts ~ 07 EC2)는 이 단계가 끝난 상태(9절)에서 시작한다.

---

## 1. 개념 (0부터)

### 1.1 지금까지 한 배포의 문제

Lab 02~04, 07 에서는 내 맥에서 `helm install`, `kubectl apply`, `terraform apply` 를 직접 쳤다. 이 방식을 **push 방식**이라 부른다. 밖(내 맥, CI)에서 클러스터 안으로 밀어 넣는다.

문제 셋
- 클러스터에 지금 뭐가 깔려 있는지의 정답이 "마지막으로 명령 친 사람의 기억"에 있다.
- 누가 `kubectl edit` 로 손대면 Git 에 적힌 것과 실제가 달라진다(드리프트). 아무도 모른다.
- 팀원 4명이 각자 맥에서 배포하면 순서가 꼬인다. 클러스터 접속 권한(kubeconfig)도 4명에게 다 줘야 한다.

### 1.2 GitOps

- 클러스터가 어떤 상태여야 하는지를 **Git 에 YAML 로 적는다**. Git 이 유일한 정답(single source of truth).
- **클러스터 안에서 도는 프로그램**이 Git 을 계속 읽어서, 실제 상태와 비교하고, 다르면 Git 쪽으로 맞춘다. 밖에서 미는 게 아니라 안에서 끌어오니까 **pull 방식**.
- 결과: 배포 = `git push`. 롤백 = `git revert`. 누가 언제 뭘 바꿨나 = `git log`. 사람은 클러스터 접속 권한이 없어도 된다.
- 이 "계속 비교하고 맞추는 반복"을 **reconcile(조정) 루프**라고 부른다. 쿠버네티스 Deployment 컨트롤러가 "파드 3개여야 하는데 2개네 → 하나 더"를 하는 것과 같은 구조를 Git ↔ 클러스터 사이에 한 겹 더 씌운 것.

### 1.3 Argo CD 안에 뭐가 있나

오늘 설치하면 파드가 5개 뜬다 (dex, notifications 를 끄면).

| 컴포넌트 | 하는 일 |
|---|---|
| `argocd-repo-server` | Git 레포를 받아서(clone) YAML 을 만든다. 폴더에 `Chart.yaml` 이 있으면 `helm template` 을 돌려 Helm 차트를 평범한 YAML 로 펼친다 |
| `argocd-application-controller` | 핵심. repo-server 가 만든 YAML(원하는 상태)과 클러스터 실제 상태를 비교하고, 다르면 적용(sync)한다. StatefulSet 으로 뜬다 |
| `argocd-server` | 웹 UI 와 API. 사람이 보는 화면 |
| `argocd-redis` | 위 셋이 같이 쓰는 캐시 (Git 에서 만든 YAML, 클러스터 상태) |
| `argocd-applicationset-controller` | Application 을 틀로 찍어 내는 기능. 10/23 테넌트마다 Application 을 만들 때 쓴다 |

### 1.4 Application 과 두 가지 상태

**Application** 은 Argo CD 가 새로 들여온 쿠버네티스 리소스 종류(CRD)다. 한 장에 세 가지를 적는다.
- source: 어느 Git 레포, 어느 브랜치, 어느 폴더
- destination: 어느 클러스터, 어느 namespace
- syncPolicy: 다를 때 자동으로 맞출지, 어디까지 맞출지

Application 마다 상태가 두 개 붙는다. 헷갈리기 쉬우니 따로 기억할 것.
- **Sync 상태**: Git 과 클러스터가 같은가. `Synced` / `OutOfSync`
- **Health 상태**: 깔린 것들이 잘 돌고 있나. `Healthy` / `Progressing` / `Degraded` / `Missing`
- 예: Git 대로 다 깔았는데 이미지 이름이 틀려서 파드가 안 뜬다 → `Synced` + `Degraded`.

### 1.5 Argo CD 는 Git 이 바뀐 걸 어떻게 아나

| 방법 | 어떻게 | 반영까지 | 비용 |
|---|---|---|---|
| polling (기본) | `timeout.reconciliation` 마다 Git 에 새 커밋 있나 묻는다 (+ 무작위 jitter) | 0 ~ (간격 + jitter) 초. 기본 120s + 최대 60s | 간격이 짧을수록 Git 서버·repo-server 부담 |
| 강제 새로고침 | UI 의 Refresh 버튼, 또는 Application 에 `argocd.argoproj.io/refresh` 어노테이션 | 몇 초 | 사람이나 CI 가 눌러야 함 |
| webhook | GitHub 이 push 순간 Argo CD 주소로 알림을 쏜다 | 몇 초 | Argo CD 가 인터넷에서 보이는 주소가 있어야 함. 맥 안 kind 는 터널 필요 |

오늘 polling 과 강제 새로고침을 둘 다 재서 숫자로 비교한다. 강제 새로고침 숫자 ≈ webhook 을 붙였을 때 숫자라고 보면 된다.

반대로 **클러스터 쪽 변화**(누가 kubectl 로 손댐)는 polling 이 아니라 쿠버네티스 이벤트로 바로 안다. 그래서 selfHeal 은 몇 초 안에 일어난다. 5단계에서 확인.

### 1.6 prune 과 selfHeal

`syncPolicy.automated` 를 켜면 Git 이 바뀔 때 자동으로 적용한다. 거기에 두 스위치가 더 있다.
- `prune`: Git 에서 파일을 지우면 클러스터에서도 지울까. 끄면 "지워야 함" 표시만 하고 남겨 둔다.
- `selfHeal`: 클러스터를 손으로 바꾸면 Git 대로 되돌릴까. 끄면 `OutOfSync` 표시만 한다.

둘 다 켜면 "Git 과 정확히 같게"가 보장되지만, 장애 중에 손으로 급히 고친 것도 되돌려진다. 이게 오늘 TODO(human) 결정이다.

### 1.7 App of Apps

Application 도 결국 YAML 이니까 Git 에 넣고 **다른 Application 이 그걸 깔게** 할 수 있다.
- `gitops/root.yaml` (root) → `gitops/apps/` 폴더를 본다 → 그 안의 `hello-fn.yaml` 같은 Application 들을 만든다 → 각 Application 이 함수를 깐다.
- 사람이 손으로 apply 하는 건 root 하나. 새 함수 추가 = `gitops/apps/` 에 파일 하나 + push.
- 본선 의미: 클러스터를 새로 만들면 "Argo CD 설치 + root apply" 두 줄로 전체 복구. 10/23 클러스터 재생성 때 이 시간을 잰다.

### 확인 질문 (답을 스레드에 한 줄로)

> Argo CD 를 `selfHeal: true` 로 켜 둔 상태에서, 장애 대응 중에 누가 `kubectl scale --replicas=10` 으로 급히 늘렸다. 무슨 일이 생기고, 그게 왜 위험할 수 있나?

---

## 2. 파일 지도

```
poc/01-argocd/
  cluster/kind-config.yaml          ← 1단계 (Claude, 완성)
  platform/argocd/values.yaml       ← 2단계 (Jeong, 빈칸 5개)
  functions/hello-fn/               ← 3단계 (Jeong, 빈칸 9개)
    Chart.yaml                         완성
    values.yaml                        빈칸 1
    templates/deployment.yaml          빈칸 5
    templates/service.yaml             빈칸 3
  gitops/apps/hello-fn.yaml         ← 4단계 (Jeong, 빈칸 6개)
  gitops/root.yaml                  ← 7단계 (Jeong, 빈칸 6개)
  scripts/measure-sync.sh           ← 6단계 (Claude, 완성)
  results/                          ← 6단계 측정 CSV
  solution/                         ← 정답본. 위와 같은 구조 (막혔을 때만)
```

모든 파일에 줄마다 주석이 있다. **각 단계에서 파일을 열고 주석을 먼저 위에서 아래로 읽은 다음** 빈칸을 채운다.

---

## 3. 단계

### 0단계: 준비

```bash
cd /Users/ijeong/softbank_study_1/Softbank_Study_1
git switch main          # main 브랜치로 (10/6 에 다른 브랜치에 있었던 적 있음)
git pull origin main     # 오늘 뼈대 받기
kind version             # kind 가 설치돼 있나, 버전
helm version --short     # helm 버전
kubectl version --client # kubectl 버전
docker info --format '{{.MemTotal}}'   # Docker Desktop 에 준 메모리 (바이트). 6GB 이상이면 넉넉
```

- 이전 실습 클러스터가 떠 있으면 메모리가 모자랄 수 있다. `kind get clusters` 로 보고, 안 쓰는 건 `kind delete cluster --name <이름>`.

붙여 줄 것: 위 명령 출력 전부

### 1단계: 클러스터 만들기

파일: `poc/01-argocd/cluster/kind-config.yaml` (주석 읽기). 요점은 노드 2개(컨트롤 플레인 + 워커), 기본 CNI 사용, 이름 `faas`.

```bash
kind create cluster --config poc/01-argocd/cluster/kind-config.yaml
#   설정 파일대로 노드 컨테이너 2개를 띄우고 쿠버네티스를 설치한다. kubectl 대상도 kind-faas 로 바꿔 준다
kubectl get nodes
#   노드 2개가 Ready 인지
```

확인 질문: 왜 오늘은 `disableDefaultCNI: false` 로 두고, 10/23 에 클러스터를 새로 만들기로 했을까? (파일 주석에 답이 있다)

붙여 줄 것: `kubectl get nodes` 출력

### 2단계: Argo CD 설치 (Helm values 직접 작성)

파일: `poc/01-argocd/platform/argocd/values.yaml`. 빈칸 5개.
- `dex.enabled`, `notifications.enabled`: 1.3 표 보고 오늘 필요한지 판단
- `server.insecure`: 파일 주석 참고
- `timeout.reconciliation` 과 `jitter`: **오늘의 결정 1**. 1.5 표 보고 고르고 이유를 한 줄 적어 둔다 (8절 결정 표)

채운 뒤

```bash
grep -n ___ poc/01-argocd/platform/argocd/values.yaml
#   빈칸 남았나. 출력이 없어야 한다

helm repo add argo https://argoproj.github.io/argo-helm
#   Argo 팀이 차트를 올려 두는 저장소를 "argo" 라는 이름으로 등록
helm repo update
#   저장소 목록(어떤 차트·버전이 있나)을 새로 받기

helm install argocd argo/argo-cd \
  --version 10.10.5 \
  --namespace argocd --create-namespace \
  -f poc/01-argocd/platform/argocd/values.yaml \
  --wait --timeout 5m
#   install argocd   : 설치 이름(release)을 argocd 로
#   argo/argo-cd     : argo 저장소의 argo-cd 차트
#   --version 10.10.5: 차트 버전 고정 (Argo CD v3.5.5). 안 적으면 그날 최신이 깔려서 팀원마다 달라진다
#   --namespace ... --create-namespace : argocd namespace 에, 없으면 만들어서
#   -f ...           : 내가 쓴 values 로 기본값 덮어쓰기
#   --wait           : 파드가 다 Ready 될 때까지 기다렸다가 끝내기

kubectl -n argocd get pods
#   5개가 Running 이어야 한다 (dex·notifications 를 껐다면)
```

UI 열기 (터미널 하나 따로)

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:80
#   맥의 8080 포트 → argocd-server Service 의 80 포트로 터널. 이 터미널은 켜 둔다
```

다른 터미널에서 초기 비밀번호

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
#   설치 때 무작위로 만든 admin 비밀번호. Secret 에는 base64 로 들어 있어서 base64 -d 로 풀어 본다
```

브라우저 http://localhost:8080 → `admin` / 위 비밀번호. 아직 Application 이 없어서 빈 화면이 정상.

확인 질문: `server.insecure` 를 false 로 두면 위 port-forward 에서 무슨 일이 생길까? (궁금하면 실제로 바꿔 `helm upgrade` 해 봐도 된다)

붙여 줄 것: `kubectl -n argocd get pods` 출력, 고른 reconciliation 값과 이유 한 줄

### 3단계: 함수 Helm 차트 (직접 작성)

파일: `poc/01-argocd/functions/hello-fn/` 4개. `Chart.yaml` → `values.yaml` → `templates/deployment.yaml` → `templates/service.yaml` 순서로 주석을 읽고 빈칸을 채운다. Lab 04 의 `labs/04-k8s-rollout-hpa/chart/hello/templates/` 를 옆에 열어 둬도 된다.

- `replicaCount`: 1 vs 2 를 골라 둔다. 6단계 측정에서 차이가 보인다
- Service 의 `targetPort` 는 숫자(5678)도 되고 포트 이름(`http`)도 된다. 이름을 쓰면 컨테이너 포트가 바뀌어도 Service 를 안 고쳐도 된다

로컬에서 먼저 검사 (클러스터에 아무것도 안 깐다)

```bash
grep -rn ___ poc/01-argocd/functions/hello-fn
#   빈칸 남았나

helm lint poc/01-argocd/functions/hello-fn
#   차트 문법 검사. "0 chart(s) failed" 가 나와야 한다

helm template hello-fn poc/01-argocd/functions/hello-fn
#   Argo CD 의 repo-server 가 할 일을 내 맥에서 미리 해 본다: 템플릿 + values → 완성된 YAML 출력
#   Deployment 와 Service 두 개가 나오고, 빈 값이나 null 이 없는지 눈으로 본다
```

Argo CD 는 **내 맥이 아니라 GitHub 에서** 읽는다. 그래서 push 해야 한다.

```bash
git add poc/01-argocd/functions poc/01-argocd/platform
git commit -m "poc/01-argocd: hello-fn chart and argocd values"
git push origin main
```

확인 질문: `helm template` 출력에서 Deployment 의 `selector.matchLabels.app` 과 Service 의 `selector.app` 이 같은 값인가? 다르면 어떤 증상이 날까?

붙여 줄 것: `helm lint` 결과, `helm template` 출력

### 4단계: Application 작성 → 첫 동기화

파일: `poc/01-argocd/gitops/apps/hello-fn.yaml`. 빈칸 6개.
- `repoURL`: `https://github.com/Pionia5375/Softbank_Study_1`. 레포가 public 이라 비밀번호 없이 읽힌다. private 이면 Argo CD 에 토큰이나 SSH 키를 따로 등록해야 한다
- `prune` / `selfHeal`: **오늘의 결정 2**. 1.6 을 보고 고르고 이유를 적는다

```bash
grep -n ___ poc/01-argocd/gitops/apps/hello-fn.yaml

git add poc/01-argocd/gitops/apps/hello-fn.yaml
git commit -m "poc/01-argocd: hello-fn Application"
git push origin main
#   Application 파일도 Git 에 둔다 (7단계 App of Apps 가 여기서 읽는다)

kubectl apply -f poc/01-argocd/gitops/apps/hello-fn.yaml
#   오늘만 손으로 한 번 넣는다. 7단계부터는 root 가 대신 넣는다

kubectl -n argocd get applications
#   SYNC STATUS = Synced, HEALTH STATUS = Healthy 가 될 때까지 몇 번 다시 쳐 본다
kubectl -n fn-demo get deploy,svc,pods
#   Argo CD 가 만든 것들 (namespace 를 다른 이름으로 했으면 그 이름으로)
```

함수 불러 보기 (터미널 하나 더)

```bash
kubectl -n fn-demo port-forward svc/hello-fn 9090:80
# 다른 터미널에서
curl -s localhost:9090
#   기대: hello v1
```

UI 에서 hello-fn 카드를 눌러 Application → Service → Deployment → ReplicaSet → Pod 트리를 본다.

확인 질문: 지금 `Synced` 와 `Healthy` 는 각각 무엇을 확인한 결과인가? (1.4)

붙여 줄 것: `kubectl -n argocd get applications`, `curl` 결과

### 5단계: 깨뜨렸다 고치기

**5-1. 드리프트와 selfHeal**

```bash
kubectl -n fn-demo scale deploy hello-fn --replicas=5
#   Git 을 안 거치고 클러스터를 직접 바꾼다 (드리프트)
kubectl -n fn-demo get deploy hello-fn -w
#   -w = 바뀔 때마다 새 줄로 보여 주기. READY 숫자가 어떻게 변하는지 본다. Ctrl+C 로 끝
```

- selfHeal 을 켰다면: 몇 초 안에 원래 숫자로 돌아온다. **몇 초 걸렸나** 적는다.
- 껐다면: 5개 그대로, UI 에 `OutOfSync`. 이번엔 Application 의 `selfHeal` 을 반대로 바꿔 push → `kubectl apply -f` 로 다시 넣고 같은 실험을 한다.

**5-2. 라벨 불일치 (Git 쪽 실수)**

- `templates/deployment.yaml` 의 `template.metadata.labels.app` 만 일부러 다른 값(예: `hello-fn-x`)으로 바꾸고 push.
- UI 에서 Sync 실패 메시지를 찾아 그대로 복사한다. (polling 이라 늦으면 UI 의 Refresh 버튼)
- `git revert HEAD` → push 로 되돌리고, 다시 Synced 가 되는지 본다. **이게 GitOps 의 롤백**이다.

**5-3. (시간 남으면) prune**

- `templates/service.yaml` 을 Git 에서 지우고 push. prune 설정에 따라 Service 가 어떻게 되는지 본다. 끝나면 revert.

붙여 줄 것: 5-1 걸린 초, 5-2 에러 메시지 원문

### 6단계: 측정 (push → 반영)

스크립트 `poc/01-argocd/scripts/measure-sync.sh` 는 Claude 가 썼다. 하는 일은 파일 맨 위 주석 1~6번. 요점
- `values.yaml` 의 `message` 를 바꿔 **main 에 커밋·push 한다** (회당 커밋 1개가 레포에 남는다)
- "Argo CD 가 알아채고 적용"과 "파드 교체"를 나눠서 잰다
- 결과는 `poc/01-argocd/results/sync-times.csv`

```bash
./poc/01-argocd/scripts/measure-sync.sh poll 3
#   기다리기만 해서 3회. 2단계에서 고른 reconciliation 값의 효과
./poc/01-argocd/scripts/measure-sync.sh refresh 3
#   push 직후 강제 새로고침해서 3회. webhook 을 붙였을 때와 비슷한 숫자
git add poc/01-argocd/results && git commit -m "poc/01-argocd: sync time results" && git push origin main
```

확인 질문: poll 의 "감지+적용" 숫자가 회마다 크게 다를 텐데, 왜 그럴까? (1.5 의 jitter 와 "마지막으로 Git 을 본 시각")

붙여 줄 것: 스크립트 마지막 표 출력

### 7단계: App of Apps

파일: `poc/01-argocd/gitops/root.yaml`. 빈칸 6개. `path` 는 Application 들이 든 폴더, `destination.namespace` 는 Application 오브젝트가 만들어질 곳.

```bash
git add poc/01-argocd/gitops/root.yaml && git commit -m "poc/01-argocd: root app" && git push origin main
kubectl apply -f poc/01-argocd/gitops/root.yaml
kubectl -n argocd get applications
#   root 와 hello-fn 두 줄. root 가 이미 있던 hello-fn 을 "내가 관리하는 것"으로 넘겨받는다
```

복구 실험

```bash
kubectl -n argocd delete application hello-fn
#   함수 Application 을 지운다. finalizer 때문에 Deployment·Service 도 같이 지워진다
kubectl -n argocd get applications -w
#   root 가 selfHeal 이면 hello-fn 이 다시 생긴다. 지운 순간부터 다시 Healthy 까지 몇 초인지 잰다
```

붙여 줄 것: 복구까지 걸린 초

---

## 8. 오늘의 결정 표 (Jeong 이 채움 → Claude 가 `decisions/2026-10-21.md` 로 옮김)

| 결정 | 선택 | 대안 | 이유 | 측정값 | 심사 항목 |
|---|---|---|---|---|---|
| Git 변경 감지 | polling ___s + jitter ___s | webhook (터널 필요) / 기본 120s+60s | | poll 평균 ___s, refresh 평균 ___s | 완성도·데모 (데모 중 push 후 기다리는 시간) |
| 자동 동기화 범위 | prune ___ / selfHeal ___ | 수동 Sync 버튼 | | selfHeal 복구 ___s | 클라우드 활용, 장애 대응 |
| replicaCount | ___ | 1 / 2 / 3 | | 파드 교체 ___s | 완성도 |

---

## 9. 이 단계가 끝난 상태 (다음 단계들이 이걸 전제로 시작)

| 항목 | 값 |
|---|---|
| 클러스터 | kind `faas` (kubectl 컨텍스트 `kind-faas`), 컨트롤 플레인 1 + 워커 1, kindnet CNI, `kindest/node:v1.37.0` |
| Argo CD | Helm release `argocd`, namespace `argocd`, 차트 `argo/argo-cd` 10.10.5 (v3.5.5), values = `poc/01-argocd/platform/argocd/values.yaml`. UI = `kubectl -n argocd port-forward svc/argocd-server 8080:80` |
| Git | `https://github.com/Pionia5375/Softbank_Study_1` (public, 인증 없음), 브랜치 `main` |
| App of Apps | `root` Application 이 `poc/01-argocd/gitops/apps/` 를 본다 (prune·selfHeal). **새 Application 은 이 폴더에 YAML 하나 추가 + push 하면 자동으로 생긴다** |
| 샘플 함수 | `hello-fn` (namespace `fn-demo`, http-echo, 차트 `poc/01-argocd/functions/hello-fn`). 02 단계가 이 차트의 Deployment 를 Rollout 으로 바꾸거나 새 차트를 만든다 |

처음부터 다시 세우기 (드릴용, 빈칸을 다 채운 뒤)

```bash
kind delete cluster --name faas
kind create cluster --config poc/01-argocd/cluster/kind-config.yaml
helm install argocd argo/argo-cd --version 10.10.5 -n argocd --create-namespace \
  -f poc/01-argocd/platform/argocd/values.yaml --wait
kubectl apply -f poc/01-argocd/gitops/root.yaml
# 나머지(hello-fn 등)는 Git 에서 자동으로 돌아온다. 시작부터 hello-fn Healthy 까지 시간을 재 두면 셋업 드릴 기록이 된다
```

## 핵심 결정 3개 (+대안)

| 결정 | 이 PoC 의 선택 | 대안과 버린 이유 |
|---|---|---|
| 1. 배포 방식 | **pull 방식 GitOps (Argo CD)** | (가) CI 에서 `kubectl apply`/`helm upgrade` (push): CI 에 클러스터 관리자 권한을 줘야 하고 드리프트를 못 잡는다. (나) Flux: 기능은 비슷하지만 UI 가 없어 2분 데모에서 "지금 동기화 중" 장면을 보여 주기 어렵다 |
| 2. 함수 패키징 | **Helm 차트 (Argo CD 가 helm template)** | (가) 평범한 YAML 폴더: 테넌트·함수마다 값만 다른 파일을 복사해야 한다. (나) Kustomize: 덮어쓰기는 깔끔하지만 10/23 에 테넌트 수만큼 찍어 낼 때 Helm values 가 더 짧다. 단 Argo CD 는 `helm install` 이 아니라 `helm template` 만 쓰므로 `helm list` 에 안 보이고 Helm hook 일부가 다르게 동작한다 |
| 3. 부트스트랩 | **App of Apps (root 하나만 손으로)** | (가) Application 마다 kubectl apply: 클러스터 재생성 때 빠뜨린다. (나) ApplicationSet: 같은 틀로 많이 찍을 때(테넌트) 맞다. 10/23 에 테넌트 쪽만 ApplicationSet 으로 바꾼다 |

## 셀프 연습 1개

두 번째 함수 `bye-fn` 을 만든다. 차트는 hello-fn 을 그대로 쓰고 `message` 만 다르게. 힌트: Application 의 `source.helm.valuesObject` 로 값만 덮어쓸 수 있다 (https://argo-cd.readthedocs.io/en/stable/user-guide/helm/). `gitops/apps/bye-fn.yaml` 하나 추가 + push 만으로 뜨면 통과. kubectl apply 는 치지 않는다.

## 아직 확인 못 한 것

- 【미검증】 실제 kind 클러스터에서의 동작 전체. Claude 쪽 컨테이너에선 kind 로 파드를 띄울 수 없어서, `helm lint`·`helm template`(차트 10.10.5 렌더)·YAML 문법까지만 확인했다. 첫 실행에서 에러가 나면 출력 그대로 스레드에 붙여 줘.

## 검증 명령과 기대 출력

```bash
kubectl -n argocd get applications
# 기대: root, hello-fn (셀프 연습까지 하면 bye-fn) 모두 Synced / Healthy

kubectl -n fn-demo get deploy hello-fn -o jsonpath='{.spec.replicas}{"\n"}'
# 기대: values.yaml 의 replicaCount 와 같은 숫자

curl -s localhost:9090     # (port-forward 켠 상태)
# 기대: values.yaml 의 message 문자열

grep -rn ___ poc/01-argocd --include=*.yaml --exclude-dir=solution
# 기대: 출력 없음 (빈칸 다 채움)

wc -l poc/01-argocd/results/sync-times.csv
# 기대: 7 (헤더 1 + poll 3 + refresh 3)
```
