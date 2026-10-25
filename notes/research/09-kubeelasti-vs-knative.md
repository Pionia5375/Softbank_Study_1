로드맵 위치: 4주차 / 서버리스 scale-to-zero 도구 선택 (KubeElasti vs Knative) / 본선 연결점: 작년 본선 주제가 FaaS, 2위 팀이 Knative+gVisor. 설계 문서 "검토한 대안" 칸과 심사 질문 "왜 Knative?"에 바로 답하기

# KubeElasti를 서버리스에 쓰면 어때? Knative와 비교

작성 2026-10-26 (KST). 질문: 【사용자】 "https://github.com/KubeElasti/KubeElasti 이거 어때? 서버리스 구현한다고 하면. knative랑 비교해서."

조사 방법: KubeElasti 레포 main(마지막 커밋 7ac5b66, 2026-08-12)을 clone해서 문서와 resolver 소스를 직접 읽음. GitHub 페이지, CNCF 프로젝트 페이지, TrueFoundry 블로그 확인. 클러스터에 직접 띄워 재 본 숫자는 **없음** (클라우드 컨테이너에서는 kind 실행 불가).

---

## 0. 한 줄 결론

**우리 FaaS PoC의 런타임은 Knative 그대로 간다. KubeElasti로 바꾸지도, 병행하지도 않는다.** 대신 설계 문서의 "검토한 대안"에 KubeElasti를 넣고, 버린 이유 3개(1→N 스케일러 따로 필요, Prometheus 의존, 콜드 스타트 폴링 지연)를 적는다. 단 본선 주제가 "기존 앱(Deployment)에 scale-to-zero 붙여서 비용 줄이기" 쪽이면 KubeElasti가 더 맞는 답이 될 수 있어서, 그 판단 기준을 §6에 남겨 둔다.

---

## 1. KubeElasti가 뭐야 (개괄)

- 【사실】 Kubernetes에서 **0↔1 스케일만** 담당하는 오퍼레이터. 1→N은 HPA나 KEDA에 맡긴다. (레포 README "It only handles scaling the application down to 0 replicas and scaling it back up to 1 replica ... The scaling after 1 replica is handled by the autoscaler like HPA or Keda.")
- 【사실】 기존 `Deployment` / `StatefulSet` / Argo `Rollout` 을 **그대로 두고** `ElastiService` 라는 CRD 하나를 옆에 붙이는 방식. (README Key Features, docs/src/install/configure-elastiservice.md)
- 【사실】 부품은 두 개. (docs/src/documentation/architecture/architecture.md)
  - **Operator**: kubebuilder로 만든 컨트롤러. 싱글톤(1개만 활성).
  - **Resolver**: 0개일 때 들어온 요청을 잡아 두는 HTTP 프록시. 여러 개 띄울 수 있음.

### 1.1 동작 원리: 두 가지 모드

```
[Serve 모드: Pod ≥ 1]
클라이언트 → Ingress → Service → EndpointSlice → Pod        (KubeElasti 안 거침)

[Proxy 모드: Pod = 0]
클라이언트 → Ingress → Service → (Resolver를 가리키는 EndpointSlice) → Resolver
     Resolver: 요청을 메모리에 붙잡고 Operator에게 "요청 왔어" 알림
     Operator: replicas 0→minTargetReplicas, KEDA면 일시정지 풀기
     Resolver: 3초마다 "Pod 떴나?" 확인 → 뜨면 private Service로 요청 넘김
     Operator: Serve 모드로 전환 (EndpointSlice를 다시 진짜 Pod로)
```

핵심 아이디어는 **Service 이름은 그대로 두고, 그 뒤의 EndpointSlice만 바꿔치기**하는 것. 그래서 Ingress·서비스 메시·클라이언트 쪽은 아무것도 몰라도 된다.

- 【사실】 Proxy 모드에서 Operator가 대상 Service용 EndpointSlice를 만들어 Resolver Pod IP를 넣고, 진짜 Pod로 가는 `<이름>-private` Service를 따로 만든다. (docs/src/documentation/architecture/state.md "Redirecting requests to resolver", "Sync Private Service")
- 【사실】 Resolver는 요청의 헤더 하나(기본 `Host`, Helm 차트 기본값은 `X-Envoy-Decorator-Operation`)를 `서비스.네임스페이스.svc.cluster.local` 형태로 읽어서 어느 서비스로 갈 요청인지 판단한다. 이 헤더가 안 맞으면 요청을 못 넘긴다. (docs/src/documentation/architecture/resolver.md) → NGINX, Istio, Envoy Gateway용 설정 문서가 따로 있다.

### 1.2 0으로 줄이는 판단: Prometheus 폴링

- 【사실】 트리거 타입은 현재 `prometheus` **하나뿐**. Operator가 **30초마다** PromQL을 실행해서 값이 `threshold` 미만이면 0으로 줄인다. (configure-elastiservice.md "KubeElasti polls this metric every 30 seconds")
- 【사실】 `cooldownPeriod` 기본 900초(15분), 최소 0, 최대 7일. 0→1로 올린 뒤 이 시간 동안은 줄이지 않는다. (같은 문서)
- 【사실】 그래서 **Prometheus 설치가 전제 조건**이고, 요청 수를 보여 주는 메트릭(예: `nginx_ingress_controller_requests_total`)이 있어야 한다. (docs/src/install/pre-requisites.md)
- 그 밖에: 0일 때 헬스체크 요청에는 Resolver가 가짜 응답을 주고 깨우지 않는 `probeResponse`, cron으로 scale-to-zero 허용 시간대를 정하는 `enabledPeriod` 가 있음. 【사실】 (같은 문서)

### 1.3 0에서 깨울 때: 요청 큐잉의 세부 로직 (소스 기준)

`resolver/internal/throttler/throttler.go` `Try()` 를 읽은 결과:

1. 요청이 오면 breaker(동시 실행 슬롯 + 대기열)에 들어간다.
2. 슬롯을 잡은 상태에서 대상 Service의 EndpointSlice에 Ready 엔드포인트가 있는지 본다.
3. 없으면 Operator에 알리고(같은 서비스는 30초에 한 번만 알림, `OperatorRetryDuration`), **`QueueRetryDuration` 만큼 `time.Sleep`** 한 뒤 2로 돌아간다.
4. 있으면 private Service로 프록시하고 끝.

여기서 나오는 성질 두 개:

- 【사실】 확인 간격은 Helm 기본값 **3초** (`charts/elasti/values.yaml` `queueRetryDuration: "3"`, 바이너리 기본값은 5초). 즉 Pod가 Ready가 된 순간과 Resolver가 알아채는 순간 사이에 **최대 3초가 그냥 비어 있을 수 있다.** 【추정】 콜드 스타트 측정값이 3초 단위로 계단처럼 나올 것. 이 값을 1초로 줄이면 대신 API 서버/캐시 조회가 늘어난다.
- 【사실】 breaker는 Resolver 프로세스에 **하나**이고 모든 서비스가 같이 쓴다 (`NewThrottler` 가 breaker 1개 생성). Helm 기본 동시 슬롯 100, 대기열 50000. 기다리는 요청도 sleep 동안 슬롯을 잡고 있다. 【추정】 멀티테넌트에서 테넌트 A의 콜드 스타트 폭주가 테넌트 B의 깨우기 요청까지 밀리게 만들 수 있다(noisy neighbor). Resolver를 여러 개 띄우면 완화.
- 【사실】 요청 타임아웃 600초(`reqTimeout`). 문서에는 "5분 재시도 후 드롭"이라고도 적혀 있어 문서와 기본값이 어긋남.

---

## 2. 성숙도

| 항목 | KubeElasti | Knative Serving |
|---|---|---|
| CNCF 단계 | 【사실】 **Sandbox**, 2026-01-03 승인 ([cncf.io/projects/kubeelasti](https://www.cncf.io/projects/kubeelasti)) | 【사실】 **Graduated**, 2025-10-08 ([CNCF 발표](https://www.cncf.io/announcements/2025/10/08/cloud-native-computing-foundation-announces-knatives-graduation/)) |
| GitHub 스타 | 【사실】 278, 포크 26, 열린 이슈 36, 열린 PR 15 (GitHub 페이지, 2026-10-26 조회) | 【미확인】 이번에 API가 막혀 못 봄. 수천 단위로 알고 있음 |
| 버전 | 【사실】 v0.1.30 (2026-07-23), 이후 v0.1.31-rc2 (2026-08-06)만 있음. CRD는 `v1alpha1` | 【사실】 1.x 대 정식 릴리스 (PoC에서 쓰는 중) |
| 활동 | 【사실】 첫 커밋 2024-04-26, 총 413 커밋, 기여자 23명. **main 마지막 커밋 2026-08-12**, 이후 약 2.5개월 커밋 없음 (clone 결과) | 【추정】 분기별 릴리스가 꾸준함 |
| 사람 | 【사실】 메인테이너 3명(TrueFoundry 2, 개인 1). 2026년 커밋 45개가 한 사람(Raman Tehlan) (`MAINTAINERS`, `git shortlog`) | 여러 회사 |
| 채택 | 【사실】 Production: TrueFoundry, Zurich Lab, Vxplain, Buildo(Karpenter와 같이 EKS 비용 절감). 나머지 5곳은 "Development/Evaluating" (docs/src/about/adopters.md, 자기 신고) | 【사실】 CNCF 졸업 요건상 다수 프로덕션 채택 확인됨 (발표문) |

정리: **아이디어는 깔끔하지만, 한 회사(TrueFoundry)가 시작한 0.1.x 샌드박스 프로젝트이고 최근 두 달 반 동안 멈춰 있다.** 해커톤에서 막혔을 때 검색해서 나오는 자료량이 Knative와 비교가 안 된다.

---

## 3. 항목별 비교

| 기준 | KubeElasti | Knative Serving | 우리 PoC 관점 |
|---|---|---|---|
| 스케일 범위 | 0↔1만. 1→N은 HPA/KEDA 따로 | 0↔N 전부 (KPA: 동시 요청 수·RPS 기반) | FaaS는 "요청 몰리면 N개"가 핵심 데모. KubeElasti면 KEDA까지 설치해야 같은 그림 |
| 기존 Deployment 재사용 | 【사실】 그대로 씀. ElastiService만 추가 | 【사실】 `serving.knative.dev/v1 Service`로 다시 써야 함 | 우리는 함수를 플랫폼이 만들어 주는 구조라 "기존 YAML 재사용"의 이득이 거의 없음 |
| 0으로 줄이는 근거 | Prometheus 쿼리 30초 폴링 + cooldown(기본 15분) | 【사실】 queue-proxy가 보내는 요청 수로 autoscaler가 판단. scale-to-zero-grace-period 기본 30초 ([Knative docs](https://knative.dev/docs/serving/autoscaling/scale-to-zero/)) | KubeElasti는 Prometheus 장애 = 스케일다운 정지. Knative는 자체 메트릭이라 외부 의존 없음 |
| 0에서 깨우기 | Resolver가 3초 간격 폴링으로 Ready 확인 | 【추정】 activator가 엔드포인트 변경을 watch로 받아서 바로 넘김 (폴링 간격 없음) | 콜드 스타트 숫자로 Knative가 유리할 가능성 높음. **측정 안 함** |
| 켜져 있을 때 경로 | 【사실】 Service → Pod 직통. 프록시 0 | 【사실】 모든 Pod에 queue-proxy 사이드카. 트래픽이 적으면 activator도 경로에 남음(target-burst-capacity) | KubeElasti 장점. 공식 문서의 "queue-proxy 2~5ms"는 KubeElasti 측 주장이고 근거 없음 【미확인】 |
| 상시 리소스 | Operator 1 + Resolver N. Pod마다 사이드카 없음 | controller, autoscaler, activator, webhook + 네트워킹(Kourier) + Pod마다 queue-proxy | 【추정】 함수 수가 많을수록 KubeElasti가 가벼움. 숫자 공개된 것 없음 |
| 네트워킹 | 아무 Ingress나. 단 Resolver가 읽을 헤더 맞춰야 함 | Kourier/Istio/Contour 중 하나 필수 | 우리는 Kourier 이미 구성 |
| 리비전·트래픽 분할 | 없음 (Argo Rollouts에 맡김) | 【사실】 Revision 불변 스냅샷 + 퍼센트 분할 내장 | 둘 다 카나리는 됨. 방식이 다름 |
| Argo Rollouts | 【사실】 `scaleTargetRef.kind: Rollout` 지원 | ksvc는 Rollout으로 못 감쌈. Knative 자체 트래픽 분할 사용 | **KubeElasti의 진짜 장점.** 02단계 Rollouts 자동 롤백 + 0스케일을 한 앱에 같이 쓸 수 있음 |
| Argo CD | 평범한 YAML이라 문제 없음 | 【사실】 ksvc도 잘 동기화됨. 다만 Knative가 만드는 Revision/Route는 Argo CD 바깥 객체 | 둘 다 OK |
| gVisor | Pod spec에 `runtimeClassName: gvisor` 바로 | 【사실】 `kubernetes.podspec-runtimeclassname: enabled` 기능 플래그 필요 (우리 `config-features-patch.yaml`에 이미 있음) | 둘 다 OK |
| 테넌트 격리 | 【사실】 `global.allowedNamespaces`로 네임스페이스 한정 설치 가능(Role/RoleBinding만). Resolver는 공용 1세트 → 테넌트 NetworkPolicy에 `elasti` 네임스페이스 허용 필요. 공용 breaker로 noisy neighbor 【추정】 | activator도 공용. 테넌트 NetworkPolicy에 `knative-serving`·`kourier-system` 허용 필요(03단계에서 이미 함) | 비슷. KubeElasti는 Prometheus 쿼리를 테넌트별로 써야 해서 손이 더 감 |
| 프로토콜 | 【사실】 HTTP만 (TCP/UDP 예정) | HTTP, gRPC, WebSocket | |
| 세팅 난이도 (해커톤 며칠) | Helm 1개 + Prometheus + (KEDA) + Ingress 헤더 설정 | YAML 3개(CRD, core, Kourier) + 설정 패치. 이미 PoC에 있음 | 우리는 Knative가 **이미 돌아가는 상태**라 바꾸면 비용만 듦 |

### 콜드 스타트 숫자에 대해

- 【사실】 KubeElasti 공식 비교 문서는 scale-from-zero를 "KubeElasti 200~800ms, Knative 300~1000ms"라고 적었지만 **측정 조건·방법이 전혀 없다** (docs/src/about/comparisons/kubeelasti-vs-knative.md). 위 §1.3의 3초 폴링 기본값과도 맞지 않는다. 마케팅 숫자로 보고 인용하지 않는다.
- 【사실】 TrueFoundry 블로그에도 KubeElasti 측정값은 없다 ([블로그](https://truefoundry.com/blog/scaling-to-zero-in-kubernetes-a-deep-dive-into-elasti)).
- 【사실】 콜드 스타트의 대부분은 어느 도구든 "스케줄 → 이미지 → 컨테이너 생성 → 앱 시작 → readiness" 구간이고 이건 도구와 무관하다 (poc/04 README §1.6 분해). 도구 차이는 "Ready를 몇 ms 만에 알아채고 요청을 넘기나"뿐.
- 우리 숫자: poc/04 `scripts/coldstart.sh` 의 runc/gVisor p50·p95 칸은 **아직 비어 있음** (Mac 실행 전).

---

## 4. 추천: 바꿀까, 병행할까, 버릴까

**추천: 버린다 (설계 문서 대안으로만 기록).**

이유:
1. **FaaS 데모의 핵심이 0→N인데 KubeElasti는 0↔1만 한다.** 같은 그림을 만들려면 KubeElasti + KEDA(또는 HPA) + Prometheus 세 개를 엮어야 하고, 셋의 상호작용(KEDA 일시정지, minReplicas 1)이 새 장애 지점이 된다. Knative는 하나로 끝난다.
2. **콜드 스타트 데모에서 불리할 가능성이 높다.** Ready 확인이 3초 간격 sleep 폴링이라, "콜드 스타트 몇 ms"를 자랑해야 하는 FaaS 주제에서 손해. 간격을 줄이면 해결되지만 그 튜닝과 검증이 또 일이다. (【추정】, 측정 안 함)
3. **성숙도 리스크.** Sandbox, v0.1.x, `v1alpha1`, 최근 2.5개월 커밋 없음, 실질 메인테이너 1명. 본선 이틀 동안 막히면 기댈 자료가 없다. 반면 Knative는 Graduated이고 작년 2위 팀이 같은 조합으로 이미 증명했다.
4. **이미 Knative + gVisor + Kourier가 PoC에 구성돼 있다.** 바꾸는 순간 04·05단계(컨트롤 플레인이 ksvc를 server-side apply) 코드와 가이드 ch05 이후를 다 고쳐야 한다. 본선까지 남은 날짜 대비 얻는 게 없다.

병행(둘 다 설치)도 추천하지 않는 이유: 같은 클러스터에서 함수 경로가 두 개가 되면 데모·설명이 흐려지고, 심사에서 "왜 둘 다?"에 답할 거리가 "비교해 봤다"뿐이다.

### 버린 대안 (설계 문서에 그대로 옮길 표)

| 대안 | 장점 | 버린 이유 |
|---|---|---|
| **KubeElasti** | 기존 Deployment/Rollout 그대로, 켜져 있을 때 프록시 0, 사이드카 없음 | 0↔1만 담당 → KEDA·Prometheus 추가 필요. Ready 확인 3초 폴링. Sandbox·v0.1.x·최근 활동 정체 |
| **KEDA HTTP Add-on** | KEDA 생태계, 0↔N | 【사실, TrueFoundry 블로그 주장】 스케일업 뒤에도 프록시가 경로에 남음. 【미확인】 우리 조사 범위 밖 |
| **직접 구현 (EndpointSlice 바꿔치기 + 큐 프록시)** | 동작 원리를 완전히 이해·설명 가능 | 해커톤 기간에 안정화 불가. 단 KubeElasti 구조가 "직접 만든다면 이렇게"의 좋은 참고 설계 |
| **Knative Serving (채택)** | 0↔N 한 번에, Revision·트래픽 분할 내장, Graduated, 작년 2위 검증 | queue-proxy 사이드카 오버헤드, 설치 부품 많음, ksvc로 다시 써야 함 |

---

## 5. 그래도 KubeElasti에서 가져갈 것

- **심사 Q&A 무기**: "Knative 말고 다른 건 봤나?" → "KubeElasti를 봤다. EndpointSlice만 바꿔서 켜져 있을 땐 프록시가 0인 게 장점이지만, 우리 FaaS는 0→N이 핵심이고 Ready 확인이 3초 폴링이라 콜드 스타트에서 불리해서 버렸다." 이 한 문단이면 팀 개발(대안 문서화) 20점 항목에 바로 들어간다.
- **설계 아이디어**: Knative가 트래픽 적을 때 activator를 경로에 남기는 것(target-burst-capacity)과 KubeElasti의 "0일 때만 프록시" 설계는 같은 트레이드오프(버스트 보호 vs 홉 하나 줄이기)의 양 끝이다. 설계 문서의 "요청 경로" 절에 이 비교를 넣으면 깊이가 생긴다.

---

## 6. 판단이 뒤집히는 조건

본선 주제가 아래 쪽이면 KubeElasti를 다시 본다.

- "이미 돌아가는 서비스(Deployment, Rollout)들의 유휴 비용을 줄여라" → 기존 YAML을 안 건드리는 게 핵심 가치가 됨.
- Argo Rollouts 카나리 + 자동 롤백을 유지한 채로 0스케일이 필요한 경우 → Knative ksvc는 Rollout과 같이 못 씀.
- 함수 수가 수백 개라 Pod마다 queue-proxy 사이드카 비용이 문제가 되는 경우.

이때도 Prometheus·KEDA 설치 시간과 3초 폴링 튜닝(`queueRetryDuration`)을 일정에 넣어야 한다.

---

## 핵심 결정 3개 (+대안)

1. **함수 런타임은 Knative Serving 유지** / 대안: KubeElasti+KEDA, KEDA HTTP Add-on, 직접 구현 / 이유: 0→N 한 부품, Graduated, 이미 구성됨.
2. **KubeElasti는 병행 설치하지 않고 설계 문서 대안으로만 기록** / 대안: 같은 클러스터에서 둘 다 띄워 콜드 스타트 비교 / 이유: 남은 일정 대비 데모 가치 낮음, 경로가 둘이면 설명이 흐려짐.
3. **콜드 스타트 비교 숫자는 KubeElasti 공식 문서 값을 인용하지 않음** / 대안: 그대로 인용 / 이유: 측정 조건 없음, 소스의 3초 폴링 기본값과 모순.

## 셀프 연습 1개

아래 질문에 3문장으로 답해 보기 (소리 내서, 1분 안에):
"KubeElasti는 켜져 있을 때 프록시가 0인데, 왜 Knative를 골랐나요? Knative의 queue-proxy 오버헤드는 어떻게 생각하나요?"
(힌트: 0→N 담당 범위, Ready 감지 방식, 우리가 queue-proxy에서 얻는 것 = 동시성 제한과 메트릭)

## 검증 명령과 기대 출력

이 문서의 사실 부분을 직접 확인하는 명령 (Mac 어디서든, 클러스터 불필요):

```bash
git clone --filter=blob:none https://github.com/KubeElasti/KubeElasti.git /tmp/ke && cd /tmp/ke
git log -1 --format='%cd'                                   # 기대: Wed Aug 12 2026 (또는 이후 날짜면 활동 재개)
grep -n 'queueRetryDuration\|queueSize\|maxQueueConcurrency' charts/elasti/values.yaml
#   기대: maxQueueConcurrency: "100" / queueRetryDuration: "3" / queueSize: "50000"
grep -n 'time.Sleep(t.retryDuration)' resolver/internal/throttler/throttler.go
#   기대: 한 줄 (Ready 확인 사이 sleep 폴링)
grep -n 'every 30 seconds' docs/src/install/configure-elastiservice.md
#   기대: "KubeElasti polls this metric every 30 seconds ..."
```

Sources:
- KubeElasti 레포: https://github.com/KubeElasti/KubeElasti (main 7ac5b66)
- CNCF KubeElasti 페이지: https://www.cncf.io/projects/kubeelasti
- Knative 졸업 발표: https://www.cncf.io/announcements/2025/10/08/cloud-native-computing-foundation-announces-knatives-graduation/
- Knative scale-to-zero 문서: https://knative.dev/docs/serving/autoscaling/scale-to-zero/
- TrueFoundry 블로그: https://truefoundry.com/blog/scaling-to-zero-in-kubernetes-a-deep-dive-into-elasti
