로드맵 위치: 3주차 10/22 (목) / Argo Rollouts 카나리 + Prometheus 지표 자동 롤백 / 본선 연결점: "배포가 망가지면 어떻게 되나?" 질문에 "카나리 20% 에서 N초 만에 자동으로 멈추고, 사용자 에러는 M% 였다" 를 숫자로 답한다. 부산 예선 1위 Crystal 팀이 쓴 구성(Argo Rollouts + Prometheus 자동 롤백)과 같은 축이라 본선에서 비교 질문이 나올 수 있다 【사실】 `notes/research/career/03-finals-and-study-direction.md`

# PoC 2단계: 나쁜 배포를 지표로 잡아 자동으로 되돌리기

오늘 끝나면 되는 것 3개
1. `git push` 한 번으로 새 버전이 20% → 60% → 100% 로 조금씩 퍼지는 걸 봤다 (카나리)
2. 일부러 망가뜨린 버전을 push 하면, 사람이 아무것도 안 해도 Prometheus 지표를 보고 스스로 멈추고 이전 버전으로 돌아간다
3. 그게 몇 초 걸렸고 그동안 사용자 요청 중 몇 % 가 에러였는지 3회 잰 표가 있다

진행 방식 (1단계와 같다)
- 개념(1절) → 파일 지도(2절) → 단계마다: 파일 주석을 위에서 아래로 읽기 → 빈칸 채우기 → 명령(한 줄씩 설명 있음) → 확인 질문 → 출력 붙여 주기.
- 빈칸은 밑줄 세 개(`___`)와 `TODO(human)` 주석. 공식 문서 링크는 각 파일 맨 위에 있다.
- 한 파일에 30분 넘게 막히면 `solution/` 의 같은 경로 파일을 본다 (`solution/README.md`).
- 출발 상태 = 1단계가 끝난 상태 (`poc/01-argocd/README.md` 9절): kind `faas` (컨텍스트 `kind-faas`), Argo CD 가 이 레포 `main` 을 보고 있음.

---

## 1. 개념 (0부터)

### 1.1 왜 필요한가: 롤링 업데이트는 "앱이 켜졌나" 만 본다

Lab 04 에서 Deployment 의 롤링 업데이트를 해 봤다. 새 파드를 하나 띄우고, readinessProbe 가 통과하면 옛 파드를 하나 끄고, 이걸 반복한다.

문제: readinessProbe 는 "이 파드가 요청을 받을 준비가 됐나" 만 본다. 앱이 켜져는 있는데 요청 3개 중 1개에 500 을 돌려주는 버전이라면? 프로브는 대부분 통과하고, 롤링 업데이트는 끝까지 가서 **모든 사용자**가 에러를 맞는다. 사람이 알아채고 `kubectl rollout undo` 를 칠 때까지.

그래서 필요한 것 두 가지:
1. 새 버전을 **일부 사용자에게만** 먼저 보낸다 (카나리)
2. 그 일부에서 **실제 성공률**을 재서, 나쁘면 사람 없이 멈춘다 (자동 분석)

### 1.2 배포 전략 4가지

| 전략 | 어떻게 | 장점 | 단점 |
|---|---|---|---|
| 재생성 (Recreate) | 옛 버전 전부 끄고 새 버전 전부 켠다 | 단순. 두 버전이 동시에 안 돈다 | 끄고 켜는 사이 서비스 중단 |
| 롤링 (RollingUpdate, Deployment 기본) | 하나씩 바꾼다 | 중단 없음 | 나쁜 버전도 결국 100% 간다. 중간에 멈추는 기준이 "프로브" 뿐 |
| 블루그린 | 새 버전을 옆에 통째로 띄워 두고, 확인 후 주소를 한 번에 전환 | 되돌리기가 즉시(주소만 다시 전환) | 잠깐이지만 파드가 2배 필요. 전환 순간 100% 가 한꺼번에 넘어간다 |
| 카나리 | 새 버전을 조금(20%)만 띄워 일부 트래픽을 받게 하고, 괜찮으면 늘린다 | 나쁜 버전의 피해가 "일부 × 짧은 시간" 으로 줄어든다 | 두 버전이 동시에 돈다 (DB 스키마 등 호환 필요). 판정 기준을 직접 정해야 한다 |

오늘은 카나리. Argo Rollouts 는 블루그린도 같은 방식으로 지원한다.

### 1.3 Argo Rollouts 가 하는 일

Argo Rollouts = 쿠버네티스에 **`Rollout` 이라는 새 리소스 종류**를 추가하는 컨트롤러다.

- `Rollout` 은 생김새가 Deployment 와 거의 같다. `spec.template` (파드 모양) 은 그대로 쓰고, `spec.strategy.canary` 에 **단계(steps)** 를 적는다.
- 컨트롤러가 하는 일: 파드 모양(template)이 바뀌면 ReplicaSet 을 2개 운영한다. 옛 것 = **stable**, 새 것 = **canary**. steps 를 위에서부터 하나씩 실행한다.
- 파드마다 `rollouts-pod-template-hash` 라벨이 붙는다. 같은 파드 모양이면 같은 값. **이 라벨로 stable 파드와 canary 파드를 구분**해서 지표를 따로 잰다.

steps 에 쓸 수 있는 것 (오늘 쓰는 것만)

| step | 뜻 |
|---|---|
| `setWeight: 20` | 카나리 비율을 20% 로 |
| `pause: {duration: 60s}` | 60초 기다림. `duration` 을 빼면 사람이 `kubectl argo rollouts promote` 할 때까지 무한 대기 |

**비율은 어떻게 맞추나 (중요)**: 오늘은 트래픽을 나눠 주는 장치(인그레스·서비스 메시)를 안 쓴다. 그러면 Rollouts 는 **파드 수**로 비율을 흉내 낸다. replicas 5, setWeight 20 → canary 1개 + stable 4개. Service 는 두 종류 파드를 구분 없이 고르게 부르니까 대략 20% 가 카나리로 간다. 그래서 replicas 는 비율로 나누어떨어지게 고른다 (5개면 20·40·60·80 이 깔끔).
트래픽 라우팅(Traefik, Istio, Gateway API 플러그인)을 붙이면 파드 수와 상관없이 정확히 5% 같은 비율을 줄 수 있다. 이건 대안으로 7절에 남긴다.

**오늘의 결정 B (steps)** 고르는 기준

| 고민 | 짧게 잡으면 | 길게 잡으면 |
|---|---|---|
| 첫 비율 (5~25%) | 피해 범위가 작다. 하지만 파드 수 방식에선 replicas 를 늘려야 한다 (5% = 20개) | 판정에 쓸 요청이 많이 모여 숫자가 덜 흔들린다 |
| pause 길이 | 좋은 배포가 빨리 끝난다 | 분석이 여러 번 잴 수 있다. **분석 첫 측정까지 initialDelay(30s), 그 뒤 15초 간격** 이므로 pause 가 60s 면 2~3번 잰다 |
| 단계 수 | 2단계면 끝까지 약 2분 | 데모에서 "중간에 멈춘 장면"을 보여 주기 쉽다 |

상태(phase) 이름: `Healthy` (안정), `Progressing` (카나리 진행 중), `Paused` (pause 중), `Degraded` (abort 됨 = 멈추고 stable 로 돌아감).

### 1.4 오늘의 앱: podinfo

1단계 hello-fn(http-echo) 을 안 쓰는 이유 두 가지: `/metrics` 를 안 내놓아서 성공률을 잴 수 없고, 일부러 고장 내는 스위치가 없다.

podinfo 【사실】 https://github.com/stefanprodan/podinfo
- 쿠버네티스 배포 연습용으로 널리 쓰는 작은 Go 웹 앱. `GET /` 하면 버전·호스트명·메시지 JSON 을 준다.
- `/metrics` 에 Prometheus 형식으로 요청 수를 내놓는다: `http_request_duration_seconds_count{path="root", status="200"}` = "/ 경로에 200 으로 답한 횟수(누적)".
- `--random-error` 옵션을 켜면 요청 3개 중 1개 꼴로 400·409·500 같은 에러를 돌려준다. 오늘의 "나쁜 배포". 【사실, 컨테이너에서 확인】 이 옵션은 `/`만이 아니라 `/readyz`, `/metrics` 에도 걸린다 (1.5 끝에서 이게 왜 중요한지).
- `PODINFO_UI_MESSAGE` 환경변수 = 응답 JSON 의 `message`. 지금 어느 버전이 답했는지 눈으로 볼 때 쓴다.

### 1.5 AnalysisTemplate: "괜찮은지" 를 숫자로 판정하는 법

리소스 2개
- **AnalysisTemplate**: 판정 방법을 적은 틀. "15초마다 Prometheus 에 이 질의를 던지고, 결과가 0.95 이상이면 합격"
- **AnalysisRun**: 틀을 실제로 한 번 돌린 기록. 카나리가 시작될 때 Rollouts 가 자동으로 만든다. `kubectl get analysisrun` 으로 측정값과 합격/불합격을 볼 수 있다.

AnalysisTemplate 의 칸

| 칸 | 뜻 |
|---|---|
| `args` | Rollout 이 넘겨 주는 값. 오늘은 `canary-hash` = 이번 카나리 파드의 `rollouts-pod-template-hash` |
| `initialDelay` | 첫 측정 전에 기다리는 시간 |
| `interval` | 몇 초마다 잴지 |
| `successCondition` | 합격 조건식. `result` = 질의 결과(숫자 목록), `result[0]` = 첫 번째 숫자 |
| `failureLimit` | 불합격 횟수가 이 값을 **넘으면** 전체 Failed. 0 = 첫 불합격에 바로 |
| `consecutiveErrorLimit` | 질의 자체가 연속 실패(주소 틀림, 결과 없음)한 횟수가 이걸 넘으면 Error (기본 4) |

측정 하나의 결과 4가지와 Rollouts 의 반응 【사실】 Rollouts v1.10.1 소스 `rollout/analysis.go`

| 결과 | 언제 | 백그라운드 분석에서 Rollout 은 |
|---|---|---|
| Successful | 조건 참 | 계속 진행 |
| Failed | 조건 거짓이 failureLimit 초과 | **abort** (stable 로 돌아감) |
| Error | 질의 실패가 consecutiveErrorLimit 초과 | **abort** (판정을 못 하면 안전한 쪽으로) |
| Inconclusive | `failureCondition`·`successCondition` 둘 다 아님 (오늘 안 씀) | pause (사람이 판단) |

**백그라운드 분석 vs 단계 분석**: `strategy.canary.analysis` 에 적으면 카나리가 도는 내내 계속 잰다 (백그라운드). `steps` 안에 `- analysis:` 로 적으면 그 단계에서 한 번 재고 넘어간다. 오늘은 백그라운드: pause 중 언제든 나빠지면 바로 멈추게.

**오늘의 질의, 한 줄씩**

```
sum(rate(http_request_duration_seconds_count{namespace="fn-canary", app="podinfo", path="root", rollouts_pod_template_hash="{{args.canary-hash}}", status=~"2.."}[1m]))
/
sum(rate(http_request_duration_seconds_count{namespace="fn-canary", app="podinfo", path="root", rollouts_pod_template_hash="{{args.canary-hash}}"}[1m]))
```

- `http_request_duration_seconds_count{...}`: 파드마다, 상태코드마다 따로 쌓이는 누적 요청 수
- `{...}` 안: 이 조건에 맞는 것만. `rollouts_pod_template_hash` = 카나리 파드만, `path="root"` = 사용자 요청만 (헬스체크 `/readyz` 는 빼야 숫자가 안 흐려진다), `status=~"2.."` = 정규식, 2로 시작하는 세 자리
- `rate(...[1m])`: 누적값을 "최근 1분 동안 초당 몇 개" 로 바꾼다
- `sum(...)`: 카나리 파드가 여러 개면 합친다
- 위 / 아래 = 2xx 응답 수 / 전체 응답 수 = **성공률 (0~1)**

Prometheus 가 이 라벨들을 어디서 얻나: Prometheus 차트의 기본 긁기 설정(`kubernetes-pods`)이 `prometheus.io/scrape: "true"` 주석이 붙은 파드를 찾아 긁고, **파드 라벨을 지표 라벨로 복사**한다 (`app`, `rollouts_pod_template_hash`). 라벨 이름의 `-` 는 `_` 로 바뀐다. 그리고 `namespace`, `pod` 라벨을 붙인다. 【사실】 차트 29.37.0 `values.yaml` `scrapeConfigs.kubernetes-pods`

**오늘의 결정 D (합격선)** 고르는 기준

| 합격선 | 의미 | 위험 |
|---|---|---|
| 0.99 | 100번 중 1번까지 실패 허용 | 원래 가끔 실패하는 앱이면 좋은 배포도 멈춘다 (오탐) |
| 0.95 | 20번 중 1번 | 오늘 나쁜 버전(약 0.65)은 넉넉히 잡는다 |
| stable 과 비교 | "카나리 성공률 ≥ stable 성공률 - 1%p" | 질의가 2개 필요. 원래 에러율이 있는 실서비스에선 이게 맞다 (셀프 연습 후보) |

failureLimit 0 vs 1: 0 이면 한 번 튄 값(파드가 막 뜨며 느린 순간)으로도 멈춘다. 1 이면 두 번 연속 나빠야 멈추지만 15초 늦어진다.

**긁는 간격과 알아채는 시간 (오늘의 결정 C)**

- `rate(...[1m])` 은 1분 창 안에 점이 **최소 2개** 있어야 값이 나온다. 없으면 "결과 없음" → 그 측정은 Error.
- Prometheus 차트 기본 `scrape_interval` 은 1m. 그러면 1분 창 안에 점이 1개뿐이라 질의가 계속 "결과 없음" → 분석 Error → **좋은 배포도 abort**. 【사실, 6절 실측】 1m 간격 Prometheus 에서 4분 동안 결과가 계속 비어 있었다. 그래서 이 값을 줄여야 한다.
- 줄일수록 빨리 알아채지만 Prometheus 가 더 자주 일한다 (메모리·CPU). 실습 규모(파드 10개 안팎)에선 10s 로 가도 부담이 없다 【추정】.

**나쁜 버전은 자기 지표도 망가뜨린다** (Claude 가 미리 잰 것, 6절)
`--random-error` 는 `/metrics` 에도 걸려서, 나쁜 카나리는 Prometheus 긁기도 1/3 확률로 실패한다. 점이 빠지니 창이 짧으면(30s) "결과 없음" 이 섞이고, Error 는 failureLimit 에 안 세어져서 판정이 늦어진다. 그래서 창을 1m 로 잡았다: 30s 창 = Failed 까지 95초(1회), 1m 창 = 45초(3회 모두).

### 1.6 Argo CD 와 같이 쓸 때 생기는 일

- Argo CD 는 Rollout 을 그냥 "Git 에 있는 YAML 하나" 로 보고 apply 한다. 카나리 진행은 Rollouts 컨트롤러 몫. Argo CD 는 Rollout 의 상태를 읽어 Health 로 보여 준다 (`Progressing`, `Suspended`(pause), `Degraded`(abort)) 【사실】 https://argo-cd.readthedocs.io/en/stable/operator-manual/health/
- **abort 뒤의 엇갈림**: Rollouts 가 abort 하면 클러스터에선 stable(v1) 파드가 다시 100% 다. 그런데 Git 과 Rollout 의 spec 은 여전히 v3-bad 다. Argo CD 입장에서 spec 은 Git 과 같으니 `Synced`, 상태는 `Degraded`. selfHeal 이 다시 밀어 넣을 것도 없다 (이미 같으니까). 즉 **"클러스터는 안전하지만 Git 은 나쁜 상태"**.
- 정리하는 법 = Git 을 고친다 (`git revert`). push 하면 Rollout 의 template 이 v1(= 현재 stable)과 같아지고, Rollouts 는 카나리 단계 없이 바로 `Healthy` 로 간다. 되돌리기도 Git 기록에 남는 것, 이게 GitOps 식 롤백이다.
- 반대로 `kubectl argo rollouts undo` 처럼 클러스터에서 직접 되돌리면? selfHeal 이 Git 상태(v3-bad)로 다시 바꿔 놓는다. 그래서 GitOps 에선 손 롤백 대신 Git 을 고친다.

**오늘의 결정 A (컨트롤러 개수)**: Rollouts 컨트롤러는 "단계를 넘기는 두뇌" 다. 죽어 있으면 새 배포가 그 자리에서 멈출 뿐, 이미 떠 있는 파드와 Service 는 그대로 돈다. 2개면 리더 선출로 하나만 일하고 하나는 대기(바로 이어받기). 1개면 메모리 절약 + Deployment 가 다시 띄울 때까지 수십 초 정지.

### 1.7 용어

| 용어 | 한 줄 뜻 |
|---|---|
| CRD | 쿠버네티스에 새 리소스 종류를 추가하는 정의서. `Rollout`, `AnalysisTemplate` 이 이걸로 생긴다 |
| Rollout | Deployment 자리에 쓰는 리소스. template + 카나리 steps |
| stable / canary | 지금 서비스 중인 버전 / 시험 중인 새 버전. 각각 ReplicaSet 하나 |
| setWeight | 카나리 비율(%). 오늘은 파드 수로 근사 |
| promote / abort | 다음 단계로 넘기기 / 멈추고 stable 로 되돌리기 |
| AnalysisTemplate / AnalysisRun | 판정 방법 / 판정을 한 번 돌린 기록 |
| podTemplateHash | 파드 모양의 지문. 카나리 파드만 고를 때 쓴다 |
| PromQL | Prometheus 질의 언어. `rate`, `sum`, 라벨 조건 `{}` |
| scrape | Prometheus 가 `/metrics` 를 읽어 가는 것 |
| retry | abort 된 같은 카나리를 처음부터 다시 시작 (`kubectl argo rollouts retry`) |

---

## 2. 파일 지도

```
poc/02-rollouts/
├── README.md                          이 문서
├── platform/                          (Jeong) 클러스터에 한 번 까는 것의 Helm values
│   ├── rollouts/values.yaml           Argo Rollouts 차트. 빈칸 4 (결정 A)
│   └── prometheus/values.yaml         Prometheus 차트. 빈칸 6 (결정 C)
├── app/                               (Jeong) Argo CD 가 이 폴더를 fn-canary 에 apply
│   ├── service.yaml                   podinfo 앞 주소. 빈칸 3
│   ├── rollout.yaml                   podinfo Rollout. 빈칸 11 (결정 B)
│   └── analysis-template.yaml         성공률 판정. 빈칸 5 (결정 D)
├── gitops/podinfo.yaml                (Jeong) Argo CD Application. 빈칸 4. kubectl apply 로 한 번
├── scripts/                           (Claude, 완성본)
│   ├── load.sh                        클러스터 안 부하 Pod. start / stop / stats
│   └── measure-rollback.sh            나쁜 배포 → abort → 카나리 0개 까지 시간 + 에러 수, N회
├── results/                           rollback.csv 가 쌓이는 곳
└── solution/                          정답본 (같은 구조). 30분 막혔을 때만
```

---

## 3. 단계

### 0단계: 준비

```bash
cd /Users/ijeong/softbank_study_1/Softbank_Study_1
git switch main && git pull origin main
#   오늘 뼈대 받기
kubectl config current-context
#   kind-faas 여야 한다. 아니면: kubectl config use-context kind-faas
kubectl -n argocd get applications
#   1단계 상태 확인. root, hello-fn 이 Synced / Healthy
brew install argoproj/tap/kubectl-argo-rollouts
#   kubectl 에 "argo rollouts" 부명령을 추가하는 플러그인. Rollout 상태를 사람이 읽기 좋게 그려 준다
kubectl argo rollouts version
#   플러그인 버전 (v1.10.x 면 된다)
```

붙여 줄 것: 위 출력 전부

### 1단계: Argo Rollouts 설치

파일: `platform/rollouts/values.yaml` (주석 읽기). 빈칸 4개.
- `installCRDs`, `keepCRDs`: 주석의 "안 하면 무슨 일이 생기나" 를 읽고 true/false
- `controller.replicas`: **결정 A** (1.6 끝). 이유를 7절 표에
- `dashboard.enabled`: 노트북 플러그인으로 같은 화면을 띄울 수 있다면 클러스터에 따로 둘 이유가 있나?

```bash
grep -n ___ poc/02-rollouts/platform/rollouts/values.yaml
#   빈칸 남았나. 출력이 없어야 한다

helm repo update
#   1단계에서 등록한 argo 저장소 목록 새로 받기 (argo-rollouts 차트도 같은 저장소에 있다)

helm install argo-rollouts argo/argo-rollouts \
  --version 2.43.8 \
  --namespace argo-rollouts --create-namespace \
  -f poc/02-rollouts/platform/rollouts/values.yaml \
  --wait --timeout 5m
#   install argo-rollouts : 설치 이름
#   argo/argo-rollouts    : argo 저장소의 argo-rollouts 차트
#   --version 2.43.8      : 차트 버전 고정 = Argo Rollouts v1.10.1
#   --namespace ...       : 컨트롤러는 argo-rollouts namespace 에. 그래도 모든 namespace 의 Rollout 을 본다
#   --wait                : 컨트롤러 파드가 Ready 될 때까지 기다렸다 끝남

kubectl -n argo-rollouts get pods
#   컨트롤러 파드가 replicas 에 쓴 개수만큼 Running
kubectl get crd | grep argoproj.io
#   Argo CD 것(applications 등) + Rollouts 것 5개(rollouts, analysistemplates, analysisruns, clusteranalysistemplates, experiments)
```

확인 질문: `keepCRDs` 를 false 로 두고 `helm uninstall argo-rollouts` 를 하면, fn-canary 의 podinfo 파드들은 어떻게 될까?

붙여 줄 것: 마지막 두 명령 출력

### 2단계: Prometheus 설치

파일: `platform/prometheus/values.yaml`. 빈칸 6개.
- 부품 4개 켜고 끄기: 오늘 필요한 건 "파드의 `/metrics` 를 긁어서 질의에 답하는 서버" 하나다
- `scrape_interval`: **결정 C** (1.5 "긁는 간격과 알아채는 시간")
- `persistentVolume.enabled`: 주석 질문

```bash
grep -n ___ poc/02-rollouts/platform/prometheus/values.yaml

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
#   Prometheus 커뮤니티 차트 저장소 등록 (Lab 06 에서 했으면 "already exists" 가 나와도 괜찮다)
helm repo update

helm install prometheus prometheus-community/prometheus \
  --version 29.37.0 \
  --namespace monitoring --create-namespace \
  -f poc/02-rollouts/platform/prometheus/values.yaml \
  --wait --timeout 5m
#   설치 이름 prometheus → 서버 Service 이름이 prometheus-server 가 된다 (AnalysisTemplate 주소에 쓴다)
#   --version 29.37.0 = Prometheus v3.15.0

kubectl -n monitoring get pods,svc
#   prometheus-server 파드 하나 Running(2/2 가 아니라 1/1: configmapReload 를 껐으니까), Service prometheus-server 포트 80
```

확인 질문: AnalysisTemplate 에 넣을 주소를 `http://<서비스>.<namespace>.svc.cluster.local:<포트>` 모양으로 써 보면?

붙여 줄 것: `get pods,svc` 출력과 확인 질문 답

### 3단계: 앱 파일 3개 작성 → push

순서대로 (주석 → 빈칸)
1. `app/service.yaml` (빈칸 3): Lab 02 에서 써 본 것
2. `app/rollout.yaml` (빈칸 11): 위쪽 template 은 Deployment 와 같다. 아래 steps 는 **결정 B** (1.3 표)
3. `app/analysis-template.yaml` (빈칸 5): `args` 이름 맞추기, **결정 D** (1.5 표), 2단계에서 쓴 주소, `status` 정규식

```bash
grep -rn ___ poc/02-rollouts/app
#   빈칸 남았나

kubectl create namespace fn-canary --dry-run=client -o yaml | kubectl apply -f -
#   검사용으로 namespace 만 먼저 (있으면 그대로). 다음 줄의 서버 검사가 namespace 를 요구해서
kubectl apply --dry-run=server -f poc/02-rollouts/app/
#   --dry-run=server: API 서버에 "이거 넣으면 받아 줄래?" 만 묻고 실제로는 안 만든다.
#   Rollout CRD 의 규칙(필드 이름·타입)으로 검사해 준다. 오타가 있으면 여기서 걸린다
#   기대: 3줄 모두 "created (server dry run)"

git add poc/02-rollouts && git commit -m "poc/02: podinfo Rollout + AnalysisTemplate" && git push origin main
#   Argo CD 는 Git 을 보므로, push 해야 다음 단계에서 Argo CD 가 이 파일을 읽을 수 있다
```

확인 질문: replicas 5, 첫 setWeight 20 이면 카나리 파드 몇 개, stable 몇 개? setWeight 30 이면?

붙여 줄 것: dry-run 출력, 확인 질문 답

### 4단계: Argo CD 에 붙이고 부하 넣기

파일: `gitops/podinfo.yaml` (빈칸 4). 1단계 `hello-fn.yaml` 과 같은 모양. prune·selfHeal 은 1단계 선택 그대로 + 주석의 질문은 6단계에서 확인.

```bash
kubectl apply -f poc/02-rollouts/gitops/podinfo.yaml
#   Application 을 Argo CD 에 등록 (1단계 App of Apps 폴더가 아니라 직접)
kubectl -n argocd get application podinfo -w
#   -w = 바뀔 때마다 한 줄씩. Synced / Healthy 가 되면 Ctrl+C
kubectl argo rollouts get rollout podinfo -n fn-canary
#   Rollout 을 나무 모양으로: Status ✔ Healthy, Images 6.14.1 (stable), 파드 5개

poc/02-rollouts/scripts/load.sh start
#   fn-canary 에 부하 Pod(load) 를 띄운다. 이게 없으면 분석이 "요청 0개" 로 실패한다 (1.5)
kubectl -n fn-canary logs load --tail=5
#   "1792... 200" 같은 줄이 계속 나오면 OK
```

Prometheus 에서 직접 질의해 보기 (선택이지만 추천)

```bash
kubectl -n monitoring port-forward svc/prometheus-server 9091:80
#   노트북 9091 → Prometheus. 브라우저 http://localhost:9091 (1단계 hello-fn 이 9090 을 쓰니 9091)
```

브라우저 질의 칸에 넣어 볼 것:
`sum by (rollouts_pod_template_hash) (rate(http_request_duration_seconds_count{namespace="fn-canary", path="root"}[1m]))`
= 버전(해시)별 초당 요청 수. 지금은 한 줄. 5단계에서 두 줄로 갈라진다.

붙여 줄 것: `kubectl argo rollouts get rollout` 출력, 위 질의 결과 숫자

### 5단계: 좋은 배포 관찰 (v1 → v2)

터미널 하나는 이걸 켜 둔다:

```bash
kubectl argo rollouts get rollout podinfo -n fn-canary --watch
#   단계가 넘어갈 때마다 다시 그린다. Step 1/4, SetWeight 20, 카나리 파드, AnalysisRun 이 보인다
#   (그림으로 보고 싶으면 다른 터미널에서 kubectl argo rollouts dashboard → http://localhost:3100)
```

다른 터미널에서 `app/rollout.yaml` 의 image 태그를 `6.15.0`, `PODINFO_UI_MESSAGE` 를 `"v2"` 로 바꾸고:

```bash
git commit -am "poc/02: podinfo v2" && git push origin main
kubectl -n argocd annotate application podinfo argocd.argoproj.io/refresh=normal --overwrite
#   Argo CD 의 다음 polling 을 기다리지 않고 지금 Git 을 다시 읽게 하는 신호 (1단계에서 쓴 것)
```

볼 것
- `--watch` 화면: canary 파드 1개 → (60초) → 3개 → (60초) → 5개, 마지막에 옛 ReplicaSet 이 scaled down
- `kubectl -n fn-canary get analysisrun` : 하나 생기고 `Running` → 끝나면 `Successful`
- 4단계 질의: 해시가 두 줄로 갈라지고 비율이 약 20:80 → 60:40 → 0:100

확인 질문: 좋은 배포가 끝날 때까지 몇 초 걸렸나? steps 에 적은 pause 합과 비교하면 차이는 어디서 생겼을까?

붙여 줄 것: `--watch` 마지막 화면, `get analysisrun` 출력

### 6단계: 나쁜 배포 → 자동 롤백 → 3회 측정

`app/rollout.yaml` 에서 `# - --random-error` 의 `#` 를 지우고, 메시지를 `"v3-bad"` 로.

```bash
poc/02-rollouts/scripts/measure-rollback.sh 3
#   먼저 켜 둔다. "카나리 시작 대기 중" 이 나오면 다른 터미널에서 아래 두 줄
git commit -am "poc/02: podinfo v3 (bad)" && git push origin main
kubectl -n argocd annotate application podinfo argocd.argoproj.io/refresh=normal --overwrite
```

스크립트가 하는 일 (scripts/measure-rollback.sh 맨 위 주석)
- 1회차: 카나리가 생기는 순간 t=0 → abort 된 순간 → 카나리 파드가 0개가 된 순간을 1초 간격으로 찍는다
- 2·3회차: `kubectl argo rollouts retry` 로 같은 나쁜 카나리를 다시 시작해서 같은 걸 잰다 (push 를 반복 안 해도 됨)
- 그 구간에 부하 Pod 가 받은 요청 수와 2xx 아닌 응답 수를 센다 → `results/rollback.csv`

동시에 볼 것

```bash
kubectl argo rollouts get rollout podinfo -n fn-canary --watch
#   Status ✖ Degraded, Message: "RolloutAborted: ... Background analysis phase error/failed"
kubectl -n fn-canary get analysisrun
#   가장 아래 줄 Failed
kubectl -n fn-canary get analysisrun <이름> -o yaml | grep -A3 measurements
#   value: '[0.66...]' 처럼 측정값이 남아 있다
kubectl -n argocd get application podinfo
#   SYNC STATUS Synced, HEALTH STATUS Degraded  (1.6 의 "클러스터는 안전, Git 은 나쁨")
```

확인 질문 (gitops/podinfo.yaml 주석의 질문): selfHeal 이 true 인데 Argo CD 가 v3-bad 를 다시 밀어 넣지 않았다. 왜?

붙여 줄 것: 스크립트 마지막 표, `get application podinfo` 출력

### 7단계: Git 으로 되돌리기

```bash
git revert --no-edit HEAD && git push origin main
#   방금 커밋(v3-bad)을 거꾸로 하는 새 커밋을 만든다. 기록을 지우지 않고 "되돌렸다" 를 남긴다
kubectl -n argocd annotate application podinfo argocd.argoproj.io/refresh=normal --overwrite
kubectl argo rollouts get rollout podinfo -n fn-canary
#   카나리 단계 없이 바로 ✔ Healthy (template 이 현재 stable 과 같아졌으니까)
kubectl -n argocd get application podinfo
#   Synced / Healthy
```

붙여 줄 것: 마지막 두 명령 출력

---

## 4. 깨뜨렸다 고치기: Prometheus 주소 오타

`app/analysis-template.yaml` 의 `address` 에서 `prometheus-server` 를 `prometheus-svr` 로 바꾸고 push. 그다음 5단계처럼 **좋은 배포**(메시지만 `"v4"`)를 push 한다.

예상해 볼 것 (먼저 적고 나서 돌린다): 좋은 배포인데 끝까지 갈까?

```bash
kubectl -n fn-canary get analysisrun -w
#   Running → Error
kubectl -n fn-canary get analysisrun <이름> -o jsonpath='{.status.message}{"\n"}'
#   consecutiveErrors (5) > consecutiveErrorLimit (4): ... no such host
```

【사실, 6절 실측】 첫 측정 30초 뒤부터 10초 간격 재시도 5번 → 약 70초 만에 Error → abort. **판정을 못 하면 좋은 배포도 멈춘다** (fail-closed). 고치기: 주소를 되돌리고 push → `kubectl argo rollouts retry rollout podinfo -n fn-canary`.

확인 질문: 반대로 "질의 실패면 그냥 통과" (fail-open) 로 하고 싶다면 무슨 칸을 바꿔야 할까? 본선 데모에선 어느 쪽이 맞을까?

---

## 5. 측정

`results/rollback.csv` (scripts/measure-rollback.sh 가 채움) 를 아래 표로 옮긴다.

| 회 | detect_s (카나리 시작→abort) | clean_s (→카나리 0개) | 마지막 측정값 | 요청 | 에러 | 에러 % |
|---|---|---|---|---|---|---|
| 1 | | | | | | |
| 2 | | | | | | |
| 3 | | | | | | |
| 중앙값 | | | | | | |

비교 기준 (계산으로, 직접 재지 않아도 됨)
- 분석 없이 롤링 업데이트였다면: 나쁜 버전이 100% 까지 가고 에러율 약 33% 가 사람이 알아챌 때까지 계속 【추정】 podinfo `--random-error` = 1/3
- 오늘 기대값: 카나리 20% × 에러 약 1/3 ≈ 전체 요청의 6~7% 가 에러, 약 60초 동안 【추정】 (initialDelay 30 + interval 15 × 2)

측정 조건도 같이 적는다: 노드 수, replicas, 결정 B·C·D 값, 부하 초당 요청 수 (`load.sh stats` 의 requests ÷ 구간 초).

---

## 6. Claude 가 미리 확인한 것과 못 한 것

이 PoC 는 클라우드 컨테이너에서 만들었다. 그 컨테이너에선 kind 가 뜨지 않아서 (컨테이너 안의 컨테이너 생성이 막힘) **전체 흐름을 클러스터에서 끝까지 돌리진 못했다**. 대신 부품별로 확인했다.

| 무엇 | 어떻게 | 결과 |
|---|---|---|
| Helm values 2개 | 실제 차트(2.43.8, 29.37.0)로 `helm template` | 렌더 성공. Rollouts: CRD 5 + Deployment 1. Prometheus: Deployment 1 + Service `prometheus-server:80`, `scrape_interval: 10s` |
| app/ 3개 (정답본) | 실제 API 서버(k3s v1.34)에 Rollouts CRD 를 깔고 `kubectl apply --dry-run=server` | 3개 모두 통과 (필드 오타 없음) |
| PromQL | podinfo 6.15.0 두 개(정상, `--random-error`)를 띄우고 Prometheus v3.15.0 으로 같은 질의 | 정상 1.00, 나쁨 0.63~0.69 |
| 판정 로직 | Rollouts v1.10.1 컨트롤러(소스 빌드)가 실제 AnalysisRun 을 돌림 | 정상 → Successful (4/4 측정 1.0). 나쁨 → **45초에 Failed** (3회 모두, 1m 창). 30s 창은 Error 가 섞여 95초 (1회) |
| 주소 오타 (4절) | 같은 방법 | 약 70초에 Error (consecutiveErrors 5 > 4) |
| scrape 1m (결정 C 기본값) | 1m 간격 Prometheus 를 따로 띄워 같은 `[1m]` 질의 | 4분 내내 결과 없음 (창 안의 점 1개). 10s 간격은 같은 시점에 값이 나옴 |
| scripts/ | `bash -n`, shellcheck | 문법·경고 없음 |

【미검증】 kind 위에서 Argo CD → Rollout → 카나리 단계 진행 → abort → retry 의 전 과정, `measure-rollback.sh` 실제 실행. Jeong 의 노트북이 첫 실행이다. 이상하면 스크립트 출력을 그대로 붙여 주면 Claude 가 고친다.
【추정】 노트북 실측 detect_s 는 위 45초에 "카나리 파드 뜨는 시간 + AnalysisRun 생성" 이 더해져 50~70초.

---

## 7. 오늘의 결정 표 (Jeong 이 채움 → Claude 가 `decisions/2026-10-22.md` 로 옮김)

| 결정 | 고른 값 | 버린 대안과 이유 (한 줄) | 측정값 |
|---|---|---|---|
| A. 컨트롤러 replicas | | | |
| B. canary steps | | | 5단계 좋은 배포 총 시간 |
| C. scrape_interval | | | 6단계 detect_s 중앙값 |
| D. 합격선 / failureLimit | | | 6단계 마지막 측정값 |
| (질문) abort 뒤 selfHeal 이 v3-bad 를 다시 안 미는 이유 | | | |

---

## 8. 이 단계가 끝난 상태 (다음 단계들이 이걸 전제로)

| 항목 | 값 |
|---|---|
| Argo Rollouts | Helm release `argo-rollouts`, namespace `argo-rollouts`, 차트 2.43.8 (v1.10.1), values = `poc/02-rollouts/platform/rollouts/values.yaml` |
| Prometheus | Helm release `prometheus`, namespace `monitoring`, 차트 29.37.0 (v3.15.0). 주소 `http://prometheus-server.monitoring.svc.cluster.local:80`. `prometheus.io/scrape: "true"` 주석 붙은 파드를 10s(결정 C) 간격으로 긁는다 |
| podinfo | Application `podinfo` (kubectl apply 로 붙임), namespace `fn-canary`, Rollout 5개, AnalysisTemplate `success-rate` |
| 부하 | `scripts/load.sh` (필요할 때만 start. 다 쓰면 stop) |

처음부터 다시 세우기 (1단계 드릴 뒤에 이어서)

```bash
helm install argo-rollouts argo/argo-rollouts --version 2.43.8 -n argo-rollouts --create-namespace \
  -f poc/02-rollouts/platform/rollouts/values.yaml --wait
helm install prometheus prometheus-community/prometheus --version 29.37.0 -n monitoring --create-namespace \
  -f poc/02-rollouts/platform/prometheus/values.yaml --wait
kubectl apply -f poc/02-rollouts/gitops/podinfo.yaml
```

---

## 핵심 결정 3개 (+대안)

| 결정 | 이 PoC 의 선택 | 대안과 버린 이유 |
|---|---|---|
| 1. 점진 배포 도구 | **Argo Rollouts** (Argo CD 와 같은 계열, Argo CD 가 상태를 바로 읽음) | (가) Flagger: 기능 비슷, Flux 와 짝. Argo CD 를 이미 쓰니 UI·Health 연동에서 Rollouts 가 낫다. (나) Deployment + 사람이 지켜보기: 판정이 사람 반응 속도(분 단위)에 묶인다. (다) Knative 트래픽 분할: 10/24 에 FaaS 쪽에서 다시 비교 |
| 2. 트래픽 비율 | **파드 수로 근사 (라우팅 장치 없음)** | (가) Traefik/Gateway API 플러그인: 5% 같은 작은 비율을 정확히 줄 수 있지만 설치·설정이 하나 더. 본선에서 인그레스를 정하면 붙인다. (나) Istio: 정확하지만 kind 노트북에 무겁다 |
| 3. 판정 기준 | **카나리 2xx 비율 ≥ 0.95, 1m 창, 15초 간격, 백그라운드, 질의 실패 시 abort** | (가) 지연시간(p95) 기준: 느려지는 버그를 잡지만 오늘 고장은 에러형. 셀프 연습. (나) stable 대비 비교: 원래 에러가 있는 서비스에 맞다. (다) Job 으로 스모크 테스트: 트래픽이 없는 함수(FaaS 0→N)에 맞다. 10/24 후보 |

## 셀프 연습 1개

지연시간 기준을 하나 더 붙인다. podinfo 의 `--random-delay` (0~5초 무작위 지연) 를 "느린 나쁜 배포" 로 쓰고, AnalysisTemplate 에 두 번째 metric `p95-latency` 를 추가한다. 힌트: `histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{...카나리 조건...}[1m])))` 결과가 0.5(초) 이하면 합격. 성공률 metric 은 통과하는데 지연 metric 으로 abort 되면 통과. 문서: https://argo-rollouts.readthedocs.io/en/stable/features/analysis/ (metrics 는 목록이라 여러 개 쓸 수 있다)

## 검증 명령과 기대 출력

```bash
grep -rn ___ poc/02-rollouts --include=*.yaml --exclude-dir=solution
# 기대: 출력 없음 (빈칸 다 채움)

kubectl -n argo-rollouts get deploy
# 기대: argo-rollouts READY 1/1 (결정 A 가 2면 2/2)

kubectl -n argocd get application podinfo
# 기대: Synced  Healthy (7단계 뒤)

kubectl argo rollouts get rollout podinfo -n fn-canary | head -8
# 기대: Status ✔ Healthy, Images ghcr.io/stefanprodan/podinfo:6.15.0 (stable)

kubectl -n fn-canary get analysisrun
# 기대: Successful 1개 이상(5단계), Failed 3개 이상(6단계), Error 1개(4절)

wc -l poc/02-rollouts/results/rollback.csv
# 기대: 4 (헤더 1 + 3회)
```
