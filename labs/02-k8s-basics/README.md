로드맵 위치: W1 D2 (10/6) / 쿠버네티스 기초: kind, Deployment·Service·Ingress, Helm 차트 / 본선 연결점: 본선 가설 전부(멀티 환경 배치·장애 조치·스케일·AI 추론)가 K8s 위에서 돈다. 완성도·데모 30점, 클라우드 활용 30점의 바탕.

# Lab 02 — 쿠버네티스 기초: Lab 01 이미지를 kind 클러스터에 올리기

Lab 01에서 만든 `lab01-hello:multi` 이미지를 내 맥 안의 쿠버네티스(kind)에 올리고, 밖에서 `curl`로 부를 수 있게 만든다. 마지막엔 같은 배포를 Helm 차트로 포장한다.

> 로드맵 원문(STATUS 10/6)은 "예선 샘플 앱(다중 서비스)"이지만, 개념을 처음 익히는 날이라 서비스 1개짜리 Lab 01 이미지로 시작한다. 다중 서비스는 10/7 이후.

## 큰 그림

```
맥 터미널
  └─ curl localhost:8088/hello
        │  (kind-config.yaml 의 extraPortMappings)
        ▼
  kind 노드 (Docker 컨테이너 1개 = K8s 서버 1대 흉내)
        │  NodePort 30080
        ▼
     Traefik ──(ingress.yaml 규칙)──▶ Service "hello" ──▶ Pod ×N (Spring 컨테이너)
```

| 용어 | 한 줄 뜻 |
|---|---|
| 클러스터 | 컨테이너를 대신 띄워 주고 관리하는 서버 묶음. 여기선 kind 가 맥 안에 1대짜리로 흉내 낸다 |
| Pod | K8s 가 띄우는 최소 단위. 보통 컨테이너 1개를 감싼 것 |
| Deployment | "이 이미지로 Pod 를 N개 항상 유지해" 라는 선언 |
| Service | Pod 들 앞의 고정 이름. Pod 가 다시 떠서 IP 가 바뀌어도 이 이름으로 부르면 된다 |
| Ingress | 밖에서 온 HTTP 요청을 어느 Service 로 보낼지 적은 규칙표. 실제 처리는 Ingress 컨트롤러(Traefik)가 한다 |
| Helm 차트 | 위 YAML 들을 묶고, 바뀌는 값만 values.yaml 로 뺀 배포 꾸러미 |

## 구조

```
labs/02-k8s-basics/
├── kind-config.yaml        클러스터 설정 (맥 8088 → 노드 30080)
├── traefik-values.yaml     Ingress 컨트롤러(Traefik) 설치 옵션
├── k8s/                    손으로 쓴 매니페스트 (3~4단계)
│   ├── deployment.yaml     TODO(human): replicas
│   ├── service.yaml
│   └── ingress.yaml
├── chart/hello/            같은 걸 Helm 차트로 (5단계)
│   ├── Chart.yaml
│   ├── values.yaml         TODO(human): values-demo.yaml 만들기
│   └── templates/
└── results/                측정 메모
```

## 진행 순서

모든 명령은 이 폴더에서 실행한다: `cd labs/02-k8s-basics`

### 0. 도구 확인

```bash
docker version --format '{{.Server.Version}}'   # Docker Desktop 이 켜져 있는지
kind version
kubectl version --client
helm version
docker images lab01-hello                        # Lab 01 이미지가 남아 있는지
```

없는 도구는 `brew install kind kubectl helm`. Lab 01 이미지가 없으면 `docker build -f ../01-docker-basics/app/Dockerfile.multi -t lab01-hello:multi ../01-docker-basics/app`.

### 1. 클러스터 만들기

```bash
time kind create cluster --config kind-config.yaml
kubectl get nodes
```

### 2. 이미지 넣기

kind 노드는 맥의 Docker 이미지 목록을 못 본다. 직접 넣어 줘야 한다.

```bash
kind load docker-image lab01-hello:multi --name lab02
```

`content digest ... not found` 에러가 나면 (Docker Desktop의 containerd 이미지 저장소 문제):
```bash
docker save lab01-hello:multi -o /tmp/lab01.tar && kind load image-archive /tmp/lab01.tar --name lab02
```

### 3. Deployment

```bash
kubectl apply -f k8s/deployment.yaml
kubectl get pods -w          # Running 이 되면 Ctrl+C
kubectl delete pod -l app=hello && kubectl get pods -w   # 지워도 다시 생기는지 (자가 치유)
```

TODO(human): `replicas` 를 정한다 (`k8s/deployment.yaml` 주석 참고).

### 4. Service → Ingress

```bash
kubectl apply -f k8s/service.yaml
kubectl get endpoints hello                 # Service 가 넘겨 줄 Pod IP 목록
kubectl run tmp --rm -it --image=curlimages/curl --restart=Never -- \
  sh -c 'for i in 1 2 3 4 5 6; do curl -s http://hello/hello; echo; done'   # 클러스터 안에서 Service 이름으로 호출

helm repo add traefik https://traefik.github.io/charts && helm repo update
helm install traefik traefik/traefik -n traefik --create-namespace -f traefik-values.yaml
kubectl get pods -n traefik -w

kubectl apply -f k8s/ingress.yaml
for i in 1 2 3 4 5 6; do curl -s localhost:8088/hello; echo; done   # host 값이 Pod 이름
```

### 5. Helm 차트로 다시

```bash
kubectl delete -f k8s/                       # 손으로 만든 것 지우기
helm template hello chart/hello              # 실제로 만들어질 YAML 미리 보기
helm install hello chart/hello
curl -s localhost:8088/hello
helm upgrade hello chart/hello --set replicaCount=3 && kubectl get pods
helm history hello
helm rollback hello 1 && kubectl get pods
```

TODO(human): `values-demo.yaml` 만들기 (`chart/hello/values.yaml` 맨 아래 주석 참고).

### 6. 정리

```bash
kind delete cluster --name lab02
```

## 측정표

| 항목 | 방법 | 결과 |
|---|---|---|
| 클러스터 생성 시간 | 1단계 `time kind create cluster` | 30.5s (노드 이미지 받는 시간 포함, 1회) |
| Pod 삭제 → 새 Pod Running | 3단계, `-w` 출력의 AGE 로 | Running 표시까지 0s. 실제 응답 가능까지 약 4~5s 【추정: Lab 01 기동 시간 기준, readinessProbe 없음】 |
| `helm upgrade` replicas 1→3, 전부 Running 까지 | 5단계 | 18s 안 (get pods 시점 AGE 18s, 정확한 값은 미측정) |
| 클러스터 떠 있을 때 메모리 | `docker exec lab02-control-plane crictl stats` | hello Pod 1개 약 175MB (요청 없을 때), 쿠버네티스 부품 합계 약 510MB (apiserver 248MB) |

replicas 선택과 이유: **3**

- 얻는 것: Pod 하나가 죽어도 남은 Pod가 요청을 받는다 (새 Pod 응답까지 약 4~5s 공백을 메움). 요청을 여러 Pod로 분산한다.
- 대가: Pod당 메모리 약 175MB, 3개면 약 525MB (Docker Desktop 7.7GB 중).
- 【추정】노드 1대에서는 Pod들이 같은 CPU를 나눠 써서, 분산이 응답 시간을 실제로 줄이는지는 모른다 → 10/10 k6로 replicas 1 vs 3 측정 예정.

values-demo.yaml 에서 덮어쓴 키와 이유: `replicaCount: 3`

- dev와 demo는 Pod 수가 달라야 한다. dev(맥)는 메모리를 아끼려고 기본값 1, demo는 심사 중 Pod 하나가 죽어도 응답이 끊기지 않고 요청이 분산되도록 3.

## 핵심 결정 3개와 대안

1. **로컬 클러스터 = kind** 【추정: 근거는 아래】
   - 대안: minikube, k3d, Docker Desktop 내장 K8s
   - 고른 이유: 노드가 Docker 컨테이너라 가볍고, 설정 파일 하나로 노드 수·포트를 고정해 매번 같은 클러스터를 재현할 수 있다. 일일 셋업 드릴(만들고 지우기 반복)에 맞다. 작년 우승팀은 AWS에서 kOps를 썼지만 로컬 연습용으로는 과하다.
2. **Ingress 컨트롤러 = Traefik (Helm, NodePort)**
   - 【사실】 커뮤니티 ingress-nginx는 2026년 3월 은퇴(유지보수 종료)했다. 출처: [CNCF 블로그 2026-04-02](https://www.cncf.io/blog/2026/04/02/ingress-nginx-retirement-experience-from-end-users/)
   - 【사실】 kind 공식 문서는 지금 cloud-provider-kind(v0.9.0+)의 내장 Ingress 지원을 안내한다. 출처: [kind Ingress 문서](https://kind.sigs.k8s.io/docs/user/ingress/)
   - 대안: cloud-provider-kind (맥에선 `sudo` 로 따로 띄워야 하고 접속 포트가 매번 바뀜), Gateway API (Ingress의 후속 표준, 10/7 이후 비교 대상)
   - 고른 이유: 맥에서 sudo 없이 고정 포트(8088)로 접속되고, Helm으로 남의 차트를 먼저 써 보는 경험이 5단계(내 차트 쓰기)로 이어진다.
3. **이미지 전달 = `kind load` (레지스트리 없음)**
   - 대안: 로컬 레지스트리 컨테이너, Docker Hub/ECR push
   - 고른 이유: 맥 한 대에서 끝나고 인터넷이 필요 없다. 한계: 클러스터를 다시 만들 때마다 load를 다시 해야 하고, 실제 클라우드에선 레지스트리가 필수라 W2 CI/CD 단계에서 바꾼다.

## 스스로 풀어 볼 문제 1개

`k8s/service.yaml` 의 `selector` 를 `app: hello2` 로 바꿔 apply 하면 `curl localhost:8088/hello` 가 어떻게 될까? 예상을 먼저 적고, 해 보고, `kubectl get endpoints hello` 로 이유를 확인한 다음 원래대로 돌린다.

## 검증 명령과 기대 출력

```bash
kubectl get nodes                 # lab02-control-plane   Ready
kubectl get deploy,svc,ingress    # deployment hello READY 1/1(또는 N/N), service hello ClusterIP, ingress hello
curl -s localhost:8088/hello      # {"message":"hello","host":"hello-xxxxxxxxxx-xxxxx"}
helm list                         # hello  ... deployed
```
