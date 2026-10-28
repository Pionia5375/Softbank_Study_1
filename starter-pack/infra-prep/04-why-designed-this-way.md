로드맵 위치: 본선 D-10 / 지금까지 쓴 스택마다 "왜 이렇게 설계됐나, 대안은, 트레이드오프는" 1페이지 / 본선 연결점: 1일차 설계 논의와 심사 Q&A 에서 대안·버린 이유를 30초 안에 말하기 (팀 개발·대안 문서화 20, 클라우드 활용 30)

# 04. 왜 이렇게 설계했나 (스택별 1페이지)

쓰는 법: 스택마다 **"문제 → 어떻게 → 왜 그렇게 → 대안 → 트레이드오프 → 30초 답"** 순서다. 읽고 나서 30초 답을 **소리 내어** 말해 본다(10/29 에 한 바퀴, 10/30 에 한 바퀴). 심사와 1일차 논의에서 "왜 X 냐" 는 거의 이 꼴로 온다.

레포 근거는 각 PoC README 를 가리킨다. 숫자가 아직 없는 곳은 "없다" 고 썼다. 본선 전에 채울 수 있으면 채우고, 못 채우면 "미측정" 이라고 말하는 게 지어내는 것보다 낫다.

---

## 1. Argo CD (GitOps, pull 방식)

- **문제**: 배포를 누가, 언제, 무엇으로 했는지 남기고, 되돌리기 쉽게 하고, 팀원 모두가 같은 방법으로 배포하게 하기.
- **어떻게**: 클러스터 **안에서 도는 컨트롤러** 가 Git 을 읽고(기본 polling 3분, webhook 가능) 실제 상태와 비교(diff)해서 다르면 Git 쪽으로 맞춘다(sync). `Application` 1개 = "이 레포의 이 폴더를 이 클러스터의 이 네임스페이스에". App of Apps = Application 들을 가리키는 Application 하나로 전체 부트스트랩. 【사실: https://argo-cd.readthedocs.io/en/stable/ 】
- **왜 그렇게 (pull)**: CI(밖)가 클러스터 자격증명을 가질 필요가 없다(보안). 클러스터가 Git 과 어긋나면(누가 kubectl 로 손댐) 스스로 되돌린다(selfHeal). 롤백 = `git revert`. 상태가 Git 하나에 모여 "단일 신뢰 공간" 이 된다.
- **대안**: ① CI 에서 `kubectl apply`/`helm upgrade` (push 방식): 단순하지만 CI 가 admin 권한을 갖고, 드리프트를 모른다. ② Flux CD: 같은 GitOps, UI 가 없고 CRD 가 더 잘게 나뉜다(GitRepository/Kustomization/HelmRelease). 터미널 중심 팀에 좋다. ③ 둘 다 안 쓰고 `helm` 만: 이틀짜리 해커톤이면 가능하지만 "팀 개발·대안 문서화" 점수에서 보여 줄 게 줄어든다.
- **트레이드오프**: polling 간격(빠르면 Git 서버 부하·요청 한도, 느리면 반영 지연. `poc/01` 에서 120s+jitter 60s 선택). CRD 큰 차트를 올릴 때 `ServerSideApply` 등 옵션 학습. UI·컨트롤러가 메모리 약 500MB 【추정】.
- **30초 답**: "배포 경로를 Git 하나로 모아서 누가 뭘 바꿨는지와 롤백이 `git log`/`git revert` 로 끝나게 했다. push 방식은 CI 에 클러스터 권한을 줘야 하고 드리프트를 못 잡아서 뺐다. Flux 도 가능했지만 팀이 처음 보는 사람이 많아 UI 가 있는 Argo CD 를 골랐다. polling 은 120초로 두고 webhook 은 EC2 로 가면 붙인다."
- **레포 근거**: `poc/01-argocd/README.md`(polling vs 강제 새로고침 측정 계획, 측정값 아직 없음), `poc/01/platform/argocd/values.yaml`.

## 2. Argo Rollouts (카나리 + 지표 자동 롤백)

- **문제**: 새 버전이 망가졌을 때 사용자 피해를 "일부 × 짧게" 로 줄이고, 사람이 안 보고 있어도 멈추게 하기.
- **어떻게**: `Rollout` 은 Deployment 와 거의 같은데 `strategy.canary.steps` 로 20% → 대기 → 60% → 100% 를 적는다. 컨트롤러가 ReplicaSet 2개(stable/canary)를 운영하고, `AnalysisTemplate` 이 Prometheus 에 PromQL 을 물어(예: canary 파드의 5xx 비율) 기준을 넘으면 **abort** = 트래픽을 stable 로 되돌린다. 【사실: https://argo-rollouts.readthedocs.io/en/stable/features/canary/ 】
- **왜 그렇게**: 표준 Deployment 의 RollingUpdate 는 "새 파드가 Ready 면 계속 간다" 라 **지표를 안 본다**. 프로브는 통과하는데 에러율이 오르는 배포를 못 막는다. 롤백 판단을 사람이 아니라 지표에 맡기면 새벽에도 같다.
- **대안**: ① Deployment + `maxSurge/maxUnavailable` + 사람이 보고 `helm rollback` (Lab 04 에서 0.25s 롤백 측정): 가장 단순, 자동 판정 없음. ② Flagger: 같은 기능, 메시 나 인그레스(Traefik/NGINX)와 결합해 **트래픽 비율을 정확히** 자른다. ③ 블루그린: 두 벌 전부 띄우고 스위치. 자원 2배, 되돌리기 즉시. ④ 서비스 메시(Istio) 가중치 라우팅: 정확하지만 메시 도입 비용.
- **트레이드오프**: 메시 없이 쓰면 카나리 비율 = **파드 수 비율** 이라 정확하지 않다(파드 5개에서 20% = 1개). 두 버전이 동시에 돌아 DB 스키마 호환이 필요. Analysis 지표가 "짧은 창에 요청이 적으면" 판정이 흔들린다(`poc/02` 에서 scrape 10s 로 줄인 이유).
- **30초 답**: "Deployment 는 프로브만 보고 지표는 안 본다. 그래서 Rollouts 로 20% 카나리에서 Prometheus 의 5xx 비율을 보고 자동으로 멈추게 했다. Flagger 는 인그레스와 묶여 비율이 정확하지만 부품이 하나 더 늘어서, 이틀 안에는 Rollouts 단독으로 가고 '비율이 파드 수 기준' 이라는 한계는 문서에 적었다."
- **레포 근거**: `poc/02-rollouts/README.md`, `poc/06-fault-injection`(s3 bad-deploy 시나리오, `results/s3-bad-deploy.csv` 는 대역 클러스터 기준).

## 3. NetworkPolicy + Cilium (테넌트 네트워크 격리)

- **문제**: 여러 테넌트(사용자)의 워크로드가 한 클러스터에 있을 때 서로 못 보게 하고, "막혔다" 를 증명하기.
- **어떻게**: 네임스페이스마다 **기본 거부**(모든 ingress/egress 차단) NetworkPolicy 를 깔고, 필요한 길만 허용한다(같은 네임스페이스, DNS, 인그레스 컨트롤러). NetworkPolicy 는 **CNI 가 구현** 하므로 CNI 를 Cilium 으로 바꿨고, Hubble 로 흐름을 기록해 "누가 누구에게 막혔나" 를 본다. 【사실: https://kubernetes.io/docs/concepts/services-networking/network-policies/ 】
- **왜 그렇게**: 쿠버네티스 기본은 **전부 허용** 이다. 격리는 명시해야 생긴다. Cilium 을 고른 이유는 차단 자체가 아니라(kindnet 도 지금은 표준 NetworkPolicy 를 강제한다【사실: poc/03 README 1.5】) ① Hubble 관측(증거) ② L7 정책(HTTP 메서드·경로 단위) ③ eBPF 데이터패스(iptables 규칙 수가 늘어도 덜 느려진다는 주장, **이 레포에선 미측정**).
- **대안**: ① kindnet/flannel + 표준 NetworkPolicy: 가볍지만 관측이 없다. ② Calico: 성숙, 정책 표현이 풍부, Hubble 급 UI 는 엔터프라이즈. `poc/06` 에 Calico 대조 CSV 있음. ③ 서비스 메시 mTLS(Istio/Linkerd): 신원 기반 격리 + 암호화, 사이드카·학습 비용. ④ 테넌트마다 클러스터 분리: 가장 강하지만 비용·운영 N배.
- **트레이드오프**: Cilium 은 설치 3~5분·메모리 수백 MB 【추정】 추가, kind 에서 가끔 특이 동작. L7 정책은 Envoy 를 경유해 지연이 조금 는다(미측정). 기본 거부를 깔면 **DNS 를 빼먹어서 전부 멈추는 사고** 가 흔하다(허용 규칙에 kube-dns 53 포트 필수).
- **30초 답**: "기본값이 전부 허용이라 네임스페이스마다 기본 거부를 깔고 필요한 길만 열었다. CNI 는 Cilium 인데, 차단은 기본 CNI 도 하지만 '막혔다는 증거' 를 Hubble 로 보여 주고 HTTP 단위 정책까지 가려고 골랐다. 대가는 설치 시간과 메모리고, 메시 mTLS 는 이틀 안엔 과하다고 봤다."
- **레포 근거**: `poc/03-tenant-isolation/README.md` 1.5절, `poc/06/results/s4-tenant-breach*.csv`.

## 4. Knative Serving (요청 기반 0↔N 오토스케일)

- **문제**: 함수(짧게 돌고 대부분 놀고 있는 워크로드)를 요청이 없으면 0개로 줄여 비용을 아끼고, 요청이 오면 자동으로 띄우기.
- **어떻게**: `Service(ksvc)` 하나에 코드 이미지만 적으면 Knative 가 Deployment·Service·라우트·리비전을 만든다. 파드가 0개일 때 요청은 **activator** 가 받아 큐에 들고, **KPA(autoscaler)** 가 동시 요청 수(concurrency)를 보고 파드를 띄운 뒤 넘긴다. 리비전마다 트래픽 비율을 나눌 수 있다. 【사실: https://knative.dev/docs/serving/autoscaling/ 】
- **왜 그렇게**: HPA 는 CPU/메모리 기준이고 **0 으로 못 줄인다**(0이면 지표가 없다). "요청 수" 를 보는 프록시(queue-proxy)가 파드 옆에 붙어야 0↔1 이 된다. Knative 는 이걸 전부 갖춘 CNCF Graduated 프로젝트라 직접 만드는 것보다 안전.
- **대안**: ① KEDA HTTP Add-on: KEDA 생태계, HTTP 인터셉터가 activator 역할. ② KubeElasti: 0↔1 만 담당, 기존 Deployment/Rollout 에 얹을 수 있음 (→ [decisions/2026-10-26.md](../../decisions/2026-10-26.md) 에서 불채택). ③ OpenFaaS/Fission: 함수 플랫폼 통째, 틀이 정해져 있다. ④ HPA + minReplicas 1: 0 포기, 가장 단순. ⑤ 작년 우승팀처럼 WASM 런타임 + 자체 스케줄: 콜드 스타트 ms 급, 언어 제약.
- **트레이드오프**: 콜드 스타트(0→1) 수백 ms~수 초 — **`poc/04` 의 측정 계획(runc vs gVisor p50/p95)이 아직 미실행**. 부품이 많아(activator, autoscaler, controller, webhook, Kourier) 메모리 1GB 안팎 【추정】. 디버깅 레이어가 늘어난다.
- **30초 답**: "함수는 대부분 놀아서 0 으로 줄이는 게 비용의 핵심인데 HPA 는 0 이 안 된다. 요청을 가로채 파드를 깨우는 activator 가 있는 Knative 를 썼다. KEDA HTTP 나 KubeElasti 도 봤지만 0↔N 과 리비전 트래픽 분할까지 한 몸인 건 Knative 라서. 대가는 콜드 스타트와 부품 수고, 콜드 스타트는 min-scale 1 과 gVisor 유무로 숫자를 비교할 계획이다."
- **레포 근거**: `poc/04-faas-runtime/README.md`, `notes/research/09-kubeelasti-vs-knative.md`.

## 5. gVisor (샌드박스 런타임)

- **문제**: 남이 올린 코드를 우리 노드에서 돌린다. 컨테이너는 커널을 공유하므로 커널 취약점 하나면 노드 전체가 뚫린다.
- **어떻게**: 컨테이너와 호스트 커널 사이에 **Sentry**(유저 공간에서 도는 "가짜 커널")를 끼워 시스템 콜을 먼저 받는다. 호스트 커널에는 훨씬 적은 종류의 시스템 콜만 간다. 쿠버네티스에서는 노드 containerd 에 `runsc` 를 등록하고 `RuntimeClass` 로 이름(`gvisor`)을 붙여 파드가 `runtimeClassName: gvisor` 로 고른다. 【사실: https://gvisor.dev/docs/ 】
- **왜 그렇게**: 이미지·배포 방식은 그대로 두고(`runtimeClassName` 한 줄) 격리 수준만 올릴 수 있다. VM 보다 가볍고 빠르게 뜬다.
- **대안**: ① runc + seccomp/AppArmor + Pod Security(restricted): 커널 공유는 그대로, 공격면만 줄임. 가장 가벼움. ② Kata Containers: 파드마다 경량 VM. 격리 최강, 시작 수백 ms~초, 중첩 가상화 필요(kind 에선 어려움). ③ Firecracker(AWS Lambda 방식): microVM, 직접 엮기엔 이틀로 부족. ④ WASM(작년 우승팀 Blue): 샌드박스가 언어 런타임에 내장, 콜드 스타트 ms, **언어·라이브러리 제약**.
- **트레이드오프**: 시스템 콜을 두 번 거치므로 **I/O·네트워크 많은 코드가 느려진다**(CPU 계산은 거의 그대로). 호환 안 되는 시스템 콜이 있다. exec 노드에만 설치해 build/system 풀은 runc 유지(노드 풀 분리의 이유 중 하나). **숫자는 `poc/04` 콜드 스타트·지연 측정 계획에 있으나 미실행.**
- **30초 답**: "테넌트 코드를 돌리니 커널 공유가 가장 큰 위험이라 gVisor 로 시스템 콜을 가로챘다. Kata 는 격리가 더 강하지만 VM 이라 무겁고 kind 에서 안 돌아 연습을 못 한다. WASM 은 작년 우승팀 방식인데 언어 제약이 커서, 어떤 언어든 받는 FaaS 에는 gVisor 가 맞다고 봤다. 대가는 I/O 성능이고 exec 풀에만 적용했다."
- **레포 근거**: `poc/04-faas-runtime/README.md` 1.5절, `platform/runtimeclass-gvisor.yaml`, `scripts/install-gvisor.sh`.

## 6. Prometheus (+ Operator, Grafana)

- **문제**: "지금 서비스가 건강한가, 그 배포가 뭘 바꿨나" 를 숫자로 보고, 기준을 넘으면 알리기.
- **어떻게**: 각 프로그램이 `/metrics` 에 숫자를 텍스트로 노출하고, Prometheus 가 **15초마다 가서 긁는다(pull)**. 라벨 붙은 시계열로 저장(TSDB), PromQL 로 질의, 규칙을 주기적으로 평가해 Alertmanager 로 넘긴다. Operator 는 `ServiceMonitor`/`PrometheusRule` 같은 **K8s 리소스로 설정을 쓰게** 해 준다 → 설정도 Git 에 (03 문서). 【사실: https://prometheus.io/docs/introduction/overview/ 】
- **왜 그렇게 (pull)**: 긁는 쪽이 대상 목록을 알고 있으니 "대상이 사라짐(target down)" 을 바로 안다. 앱은 에이전트·자격증명 없이 `/metrics` 만 열면 된다. 쿠버네티스 서비스 디스커버리와 궁합이 좋다(파드가 늘면 알아서 긁는다).
- **대안**: ① CloudWatch Container Insights / Datadog(push 에이전트): 설치 쉽고 매니지드, 비용·벤더 종속, PromQL 생태계(대시보드·규칙)와 다름. ② OpenTelemetry Collector 로 수집 통일 후 Prometheus/타 백엔드에 전달: 표준적이지만 부품 하나 더. ③ VictoriaMetrics / Grafana Mimir: 장기 저장·대용량. 이틀짜리엔 불필요. ④ 로그만 보기: 비율·p95 를 못 만든다.
- **트레이드오프**: 단일 인스턴스면 긴 기간·큰 카디널리티에 약하다(라벨 폭발 주의: 요청 경로를 그대로 라벨에 넣지 말 것). 긁기 간격이 알림 지연의 바닥(03 문서 확인 질문). kube-prometheus-stack 은 무겁다(메모리 1GB 안팎 【추정】, `labs/06` 에서 재기로 했으나 미실행).
- **30초 답**: "앱은 `/metrics` 만 열고 Prometheus 가 긁는 pull 구조라 대상이 죽은 것도 바로 보이고, 파드가 늘어도 자동으로 따라온다. CloudWatch 도 되지만 PromQL 로 카나리 판정과 SLO 알림을 같은 숫자로 묶고 싶어서 Prometheus. Operator 를 써서 규칙도 Git 에 둔다. 장기 저장은 포기했고 이틀 데모엔 1일 보관이면 된다."
- **레포 근거**: `labs/06-observability-k6/promql.md`, `poc/02/platform/prometheus/values.yaml`(scrape 10s 결정), `poc/06/defenses/prometheus-alerts-values.yaml`(알림 5개).

## 7. 짧게: kind / k3s / Terraform / Kaniko

- **kind**(연습): 노드 = Docker 컨테이너. 대안 minikube(단일 노드 중심), k3d. 이유: 다중 노드·taint·포트 매핑을 파일 하나로 재현. → 01 문서.
- **k3s**(데모 후보): 바이너리 하나, `curl | sh`, 배터리 포함. 대안 kubeadm(정석, 손이 많이 감), EKS(매니지드, 시간·비용). → 01 문서, `poc/07/README.md` 1.3절.
- **Terraform**(환경 재현): `apply` 한 줄로 같은 환경. 대안 eksctl(EKS 전용), CloudFormation(AWS 전용), 손으로. 이유: 로컬 kind(`labs/07`)와 AWS(`poc/07`)를 같은 언어로, 팀원이 같은 환경을 다시 세울 수 있다. 트레이드오프: state 관리(원격 state + lock 이 없으면 둘이 동시에 apply 하다 꼬인다 — 본선 1일차 결정 사항), 학습 곡선.
- **Kaniko**(클러스터 안 빌드): Docker 데몬 없이 파드 안에서 이미지 빌드 → 빌드 노드 풀에 격리. 대안 BuildKit(rootless), 외부 CI(GitHub Actions)에서 빌드 후 push. 이유: 테넌트 코드 빌드를 플랫폼 안에서 통제. 주의: Kaniko 저장소는 **아카이브됨(더 이상 개발·유지보수 안 함)**【사실: https://github.com/GoogleContainerTools/kaniko README 첫 줄, 2026-10-28 조회】, 커뮤니티 포크(Chainguard 등)만 남았다 — 본선에선 "BuildKit 또는 GitHub Actions 로 빌드" 가 더 안전한 답일 수 있다. `poc/04` 는 Kaniko 로 되어 있으니 질문 나오면 이 점을 먼저 말한다.

---

## 1일차 논의에서 쓰는 법

- 상대가 X 를 제안하면: "X 좋다. 우리가 Y 를 고려한 이유는 (한 줄), X 로 가면 (트레이드오프 한 줄). 어느 쪽이든 **측정값으로 결정하자** — 오늘 밤 둘 다 PoC 10분씩?" 이 꼴로. 강요가 아니라 **대안을 표로 만드는 사람** 이 된다(내정자 조언: 영향력은 기여로 얻는다).
- 설계 문서의 "대안" 절은 이 문서의 각 "대안" 줄을 복사해서 시작하면 된다.

## 핵심 결정 3개 (+대안)

1. **각 스택을 "문제→어떻게→왜→대안→트레이드오프→30초 답" 틀로 통일.** 대안: 장단점 표만. 이유: 심사 질문이 "왜" 로 오고, 답은 대안과 버린 이유가 있어야 점수가 된다(팀 개발 20).
2. **미측정은 미측정이라고 쓴다.** 대안: 문서 수치 인용. 이유: 조건 없는 숫자는 반박당하면 신뢰를 전부 잃는다. 본선 전에 `poc/04` 콜드 스타트, `labs/06` 스택 메모리 둘만이라도 재면 좋다.
3. **Kaniko 유지보수 중단을 먼저 밝힌다.** 대안: 모른 척. 이유: 아는 심사위원이 물으면 더 나쁘다. "알고 있고, 본선에선 BuildKit/CI 빌드로 바꿀 수 있다" 가 더 좋은 인상.

## 셀프 연습 1개

6개 스택 중 하나를 골라 **대안으로 바꿨을 때 바뀌는 파일 목록** 을 적어 본다. 예: Argo Rollouts → Flagger 면 `poc/02` 의 `Rollout` → `Deployment` + `Canary` CRD, Prometheus 쿼리는 그대로, Traefik/NGINX 인그레스 필요. 그 목록의 길이가 "전환 비용" 이고, 설계 문서에 한 줄로 들어간다.

## 검증 (이 문서는 읽기용)

- 10/29 와 10/30 에 각 스택 30초 답을 녹음하지 말고 **소리 내어 말하기만** 한 번씩. 막히는 스택을 README 의 소감 줄에 적는다.
- `grep -c '^- \*\*30초 답\*\*' starter-pack/infra-prep/04-why-designed-this-way.md` → 6
