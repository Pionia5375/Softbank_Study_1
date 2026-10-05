# 01. 해커톤 성격 — 2025 본선 우승팀(sh-final-blue) 레포 정독과 심사 관점 역산

> 작성일: 2026-10-05 · 범위: 조사 요청 1번 "[해커톤 성격]"만 다룸
> 기술 스택별 "왜/대안/난이도"는 [06-tech-stack-map.md](./06-tech-stack-map.md), 배점·발표 형식은 [04-judging-criteria.md](./04-judging-criteria.md)에 있으므로 여기서는 **"이 대회가 무엇을 보는 대회인가"** 에 집중한다.

## 표기 규칙

| 표시 | 의미 |
|---|---|
| **[사실]** | 레포의 코드·설정·커밋 이력, 공고 원문에서 직접 확인한 내용 (경로 병기) |
| **[공식]** | 주최측 자료(모집 공고, 킥오프 PPT) 원문 |
| **[추정]** | 위 근거로부터의 추론. 검증되지 않음 |
| **[없음]** | 찾아봤지만 근거가 없는 것 |

출처 레포: `https://github.com/sh-final-blue/<레포명>` 8개, 2026-10-05에 전체 클론해 읽음.

---

## 0. 한 장 요약

1. **2025 본선은 "1주일 준비 + 2일 현장"짜리 플랫폼 구현 대회였다.** [사실] 본선 킥오프 11/28, 현장 12/6–7 (모집 공고). 우승팀 커밋도 11/29부터 시작해 **현장 이틀(12/6–7)에 web-backend 커밋 143개 중 110개**가 몰려 있다. 사전 1주는 인프라·PoC, 현장 이틀은 통합·UI·데모 다듬기.
2. **주제는 "EC2/Compute Engine 위에서 직접 만드는 서버리스 플랫폼"** 이었다. [사실, 팀 README] "Run Your Functions Instantly over HTTP — EC2/Compute Engine 위에서 구현하는 차세대 Serverless 플랫폼". [추정] "EC2 위에서"라는 단서는 Lambda·Cloud Run 같은 매니지드 서버리스를 그대로 쓰지 말라는 제약으로 읽힌다. 우승팀이 EKS도 아닌 **kOps 자체 관리형 K8s**를 택한 것이 이 제약과 맞물린다.
3. **우승팀의 승부수는 "기술 하나로 문제 정의부터 인프라까지 일관된 서사"** 였다. [추정] 서버리스의 고질 문제(콜드스타트, 컨테이너 탈출)를 문제로 정의 → WASM(Spin/SpinKube)을 해법으로 선택 → "WASM은 stateless하니 Spot에, 빌드 노드와 실행 노드는 분리" 식으로 인프라 결정이 같은 서사에서 파생된다.
4. **"동작하는 end-to-end 데모"가 있었다.** [사실] Python 코드 작성 → mypy 검증 → WASM 빌드 → ECR 푸시 → SpinApp 배포 → HTTP 호출 → 함수별 로그(Loki)·CPU(Prometheus) 조회까지 한 화면(웹 콘솔)에서 이어진다. 콘솔은 **일본어·한국어·영어** 3개 언어를 지원한다.
5. **README의 주장 중 상당수는 코드로 뒷받침되지 않는다.** [사실] "Docker 대비 10~100배 빠른 기동"의 측정 스크립트·결과가 레포에 없고, "Zero Cold Start"는 실제로는 최소 레플리카 1개를 항상 띄워 두는 방식이며, "WASM 실행 노드는 Spot"은 12/5 커밋에서 제거됐다(아래 4장). → **[추정] 심사는 데모와 서사 위주였고 세부 검증까지는 못 했을 가능성이 크다. 같은 서사에 실측 숫자를 붙이면 그것만으로 차별화된다.**

---

## 1. 2025 대회 맥락

| 항목 | 내용 | 근거 |
|---|---|---|
| 대회명 / 주최·운영 | SoftBank Hackathon 2025 in Korea / 주최 SoftBank, 운영 Progate × KOREC | [공식] [링커리어 공고](https://linkareer.com/activity/273708) |
| 대회 전체 테마 | "클라우드로 미래를 만든다", AWS·GCP·Azure를 활용한 사회 문제 해결 | [공식] 위 공고, [청년개발자신문](https://www.devtimes.co.kr/news/433926) |
| 예선 | 1회차 11/8–9 (킥오프 10/31), 2회차 11/22–23 (킥오프 11/14), 온라인 | [공식] 공고 |
| 본선 | 킥오프 11/28, 현장 12/6–7 서울, 예선 통과자 약 50명 | [공식] 공고 |
| 본선 주제 | "Run Your Functions Instantly over HTTP — EC2/Compute Engine 위에서 구현하는 차세대 Serverless 플랫폼" | [사실] 우승팀 `.github/profile/README.md`. **주최측 원문은 확인 못 함 [없음]** |
| 우승팀 | 5명, 역할 DevOps 1 · Fullstack 1 · Infra 2 · Monitoring 1, 수상명 "최우수상" | [사실] `.github/profile/README.md` (이미지 alt 텍스트) |
| 프로젝트 기간 | 2025.11.28 – 12.07 | [사실] 같은 README |
| 팀 편성 | 조직 이름이 `sh-final-blue`(본선-색깔) | [사실]. [추정] 운영측이 본선 진출자를 섞어 색깔별 팀으로 편성했을 가능성. `sh-final-red` 등 다른 색 조직은 GitHub에 없음(404) [없음] |

**올해와의 대응** [추정]: 올해 본선은 11/7–8, 본선 킥오프는 10/30 또는 11/2(공고 간 불일치, 04 문서 참조). 작년과 같은 구조라면 **킥오프 후 약 1주일의 사전 개발 기간**이 있고, 그 1주일에 인프라를 미리 세워 둔 팀이 유리하다. 올해 예선 킥오프 PPT의 발표 예시 문구("どれだけでも関数がデプロイできる", "サーバーレスといえば、スケーラビリティが大事", "10,000 request/s", "Compute Engine")가 작년 본선 주제(서버리스)와 겹친다. 작년 자료를 재사용한 흔적으로 보이며, **운영측이 같은 템플릿과 문제의식을 이어 쓰고 있다**는 신호로 읽는다.

---

## 2. 8개 레포 지도

| 레포 | 역할 | 주 언어 | 커밋 / 기간 | 주 작성자 | 비고 |
|---|---|---|---|---|---|
| `.github` | 조직 프로필 README (발표 요약 역할) | Markdown | 11 / 12-08~12-10 | 정호원(DevOps) | **대회 후에** 정리됨 |
| `poc-wasm-spin` | 첫 PoC: Python→WASM 빌드·SpinApp 배포 API, DynamoDB 설계 문서 | Python | 10 / 11-29~12-02 | 조현민(Infra) | RKE2 클러스터 기준. `.kiro/specs/`에 요구사항·설계·태스크 문서 |
| `infra-iac` | Terraform: VPC, ALB(HTTPS), CloudFront+WAF, S3, ECR, Bastion, K3s 모듈 | HCL | 17 / 11-30~12-22 | 조현민 | 8일 비용 추정표(~$138) 포함 |
| `kops-repo` | kOps 클러스터 정의(cluster.yaml), ALB 라우팅 스크립트, 트러블슈팅 리포트 | Shell/YAML | 1 / 12-06 | 조현민 | 클러스터 부트스트랩 장애 분석 문서가 있음 |
| `web-faas-builder` | **핵심 엔진**: 검증→`spin build`→`spin registry push`→`spin kube scaffold`→`kubectl apply` | Python(FastAPI) | 43 / 12-02~12-06 | 조현민 | 테스트 15개 파일, hypothesis 기반 속성 테스트 포함 |
| `web-backend` | 콘솔 API(FastAPI+DynamoDB+S3) + 최종 프론트엔드(React) + Helm 차트 + CI | Python / TS | 143 / 12-01~12-07 | 최성우(Fullstack) | **12/6에 68개, 12/7에 42개** 커밋 |
| `helm-charts` | 백엔드 Helm 차트 | YAML | 2 / 12-01 | 조현민 | web-backend 안의 차트와 중복 |
| `2025softbank-hackathon-final` | 초기 프론트엔드 목업 ("Yoitang") | TS | 2 / 11-30, 12-06 | 조영빈(Infra) | Lovable 생성 코드, 목 데이터. 최종본은 `web-backend/frontend` |

[사실] 레포 이름과 실제 내용이 어긋나는 곳이 있다. 메인처럼 보이는 `2025softbank-hackathon-final`은 목업 UI뿐이고, 실제 제품은 `web-backend`와 `web-faas-builder`에 있다.

### 2.1 최종 요청 흐름 (코드로 재구성)

```
[브라우저] www.eunha.icu  ── CloudFront(+WAF) ── S3 (React 콘솔, ja/ko/en)
     │
     ▼ api.eunha.icu (ALB → kOps 클러스터)
[web-backend: FastAPI]
  ├─ 워크스페이스/함수 CRUD ── DynamoDB(싱글 테이블) + S3(코드)
  ├─ build-and-push 요청 ───▶ [web-faas-builder: builder.eunha.icu]
  │                              mypy 검증 → spin build(componentize-py)
  │                              → spin registry push → ECR
  │                              → spin kube scaffold → kubectl apply (SpinApp + HPA)
  ├─ invoke ──▶ http://<함수명>.default.svc.cluster.local  (백엔드가 클러스터 내부 DNS로 프록시)
  ├─ 로그 ────▶ Loki (function_id 라벨)
  └─ 메트릭 ──▶ Prometheus (container_cpu_usage_seconds_total)
```

- [사실] 함수 호출은 함수별 공개 URL이 아니라 **백엔드의 `/invoke` API가 클러스터 내부 Service DNS로 프록시**한다 (`web-backend/backend/app/routers/functions.py` `build_fallback_host`, `invoke_function`). 호출 시간을 재서 DynamoDB에 평균 응답시간·호출 수를 누적한다.
- [사실] 빌더와 백엔드는 `subprocess`로 `spin`, `kubectl` CLI를 직접 실행한다 (`web-faas-builder/src/services/*.py`, `functions.py`의 `kubectl delete spinapp`).

### 2.2 인프라 진화 (커밋 이력)

| 날짜 | 변화 | 근거 |
|---|---|---|
| 11/29 | RKE2 클러스터 + containerd-shim-spin v0.22.0 + spin-operator v0.6.1로 PoC. 레지스트리는 Docker Hub | [사실] `poc-wasm-spin/README.md` |
| 11/30 | Terraform 기본 인프라 + **K3s 모듈**(마스터 1 + 워커 4: Wasm/Build/Observability/Infra) | [사실] `infra-iac` CHANGELOG |
| 12/01 | "Disable K3s cluster by default" | [사실] `infra-iac` 커밋 |
| 12/02 | kOps 클러스터 부트스트랩 실패(웹훅 닭-달걀 문제) 분석 리포트 | [사실] `kops-repo/troubleshooting-report.md` |
| 12/02~ | ECR로 레지스트리 이전, builder 서비스 개발 | [사실] `infra-iac`, `web-faas-builder` 커밋 |
| 12/06 | kOps 클러스터 정의 최종 커밋 (Cilium, Cluster Autoscaler, Spot 노드 그룹, 노드 역할 분리) | [사실] `kops-repo` |

[추정] 같은 목표(WASM 실행 가능한 K8s)를 **RKE2 → K3s → kOps** 세 번 시도했다. kOps로 간 이유는 레포에 명시돼 있지 않다 [없음]. Cluster Autoscaler·AWS LB Controller·IRSA를 애드온으로 바로 쓸 수 있다는 점이 이유였을 것으로 본다.

---

## 3. 기술 선택과 그 선택이 말하는 것

자세한 대안·난이도는 06 문서에 있다. 여기서는 **각 선택이 심사에서 어떤 메시지로 작동했을지**만 본다.

| 선택 | 팀이 내세운 이유 | 심사에 주는 메시지 [추정] |
|---|---|---|
| WASM (Spin + SpinKube) | 컨테이너 레이어 제거로 콜드스타트 제거, 메모리 샌드박스로 격리 | "서버리스의 본질 문제를 알고, 업계 최신 해법을 골랐다." 독창성·기술 깊이 |
| kOps 자체 관리형 K8s (EKS 아님) | Self-managed 클러스터 구축 | "EC2 위에서"라는 주제 제약 준수 + 컨트롤 플레인부터 직접 다룰 수 있다는 인프라 역량 |
| Terraform | IaC로 VPC~CDN 구성 | 재현 가능성, 팀 공유. 올해 PPT 예시에도 "Terraform state 공유 워크플로"가 기술적 도전 사례로 나옴 [공식] |
| Spot + ARM + 노드 역할 분리 | 비용 절감, 빌드/실행 노드 분리로 병목 제거 | 비용·운영 감각. 인프라 엔지니어 채용 대회와 맞는 메시지 |
| Prometheus + Loki + 함수별 대시보드 | 함수별 리소스·로그 실시간 확인 | "만들고 끝"이 아니라 운영까지 생각했다 |
| 웹 콘솔 + URL 고정 도메인(eunha.icu) | 코드 작성부터 모니터링까지 한 화면 | 데모 완성도. 우리 예선 피드백의 "URL 고정으로 데모가 좋았다"와 같은 축 |
| 3개 언어 UI (ja/ko/en) | — | 일본 심사위원 배려 |
| Kiro 스펙 문서, hypothesis 속성 테스트 | — | [추정] AI 에이전트를 써서 요구사항→설계→태스크→테스트까지 빠르게 생성. 올해 배점의 "AI 활용 10점"과 통하는 작업 방식 |

---

## 4. README 주장 vs 코드 (검증표)

우리 본선 발표에서 같은 지적을 받지 않도록, 그리고 **"실측 숫자로 설명"하는 연습 재료**로 쓰기 위해 정리했다. 깎아내리려는 목적이 아니다. 1주일 + 2일 해커톤에서는 자연스러운 간극이다.

| README 주장 | 코드에서 확인한 사실 | 근거 |
|---|---|---|
| "Docker 대비 10~100배 빠른 기동 시간 달성" | 벤치마크 스크립트·측정 결과·그래프가 8개 레포 어디에도 없다 | [없음] `cold start`, `benchmark`, `latency` 등으로 전체 검색 |
| "Zero Cold Start" | SpinApp마다 HPA `minReplicas: 1`, CPU 기준 스케일. 항상 1개가 떠 있으므로 콜드스타트가 **발생하지 않게 피한 것**이지, 0→1 기동을 빠르게 만든 것을 보여주진 않는다. scale-to-zero(KEDA)는 Roadmap에 있음 | [사실] `web-faas-builder/src/services/deploy.py`, `.github` Roadmap |
| "Stateless WASM 실행 노드는 Spot" | 빌더가 SpinApp에 Spot toleration/affinity를 넣었다가, **SpinApp CRD(v1alpha1)가 해당 필드를 지원하지 않아** 12/5에 제거. Spot 노드는 라벨만 있고 taint가 없어서 함수 Pod가 어느 노드에 뜰지는 스케줄러에 달려 있다 | [사실] 커밋 "fix: Remove unsupported tolerations/affinity from SpinApp manifest", `test_spot.yaml` 주석, `kops-repo/cluster.yaml` |
| "ARM 아키텍처 적극 도입" | ARM(t4g.medium)은 **컨트롤 플레인 1대뿐**. 워커는 모두 x86(t3a/c5/c6i/c7i). 빌더 Dockerfile도 amd64 바이너리만 받는다. 백엔드 이미지는 amd64+arm64 멀티아키로 빌드 | [사실] `kops-repo/cluster.yaml`, `web-faas-builder/Dockerfile`, `web-backend/.github/workflows/back-deploy.yml` |
| "Multi-AZ 고가용성" | 워커는 2a·2c에 분산되지만 컨트롤 플레인 1대, NAT 게이트웨이 1개(한 AZ), Spot·빌드·관측 노드 그룹은 모두 2c 한 곳 | [사실] `cluster.yaml`, `infra-iac/modules/vpc/main.tf` |
| "ArgoCD로 CI/CD" | ArgoCD `Application` 매니페스트가 공개 레포에 없다. CI는 GitHub Actions로 ECR 푸시(백엔드), S3 sync + CloudFront 무효화(프론트). Helm values에 이미지 태그가 직접 고정됨 | [없음] `argoproj` 검색 결과 0건. [사실] `.github/workflows/*.yml`, `web-backend-platform/values.yaml` |
| "Prometheus, Grafana, Loki, Promtail" | 백엔드가 Prometheus·Loki HTTP API를 질의하는 코드는 있음. 설치용 values·대시보드 JSON은 레포에 없음 | [사실] `routers/metrics.py`, `routers/logs.py`. [없음] Grafana 설정 |
| 백엔드 README "AWS EKS + ALB + ArgoCD" | 실제 클러스터는 kOps. 문서가 이전 계획을 그대로 남김 | [사실] `web-backend/backend/README.md` vs `kops-repo` |
| 보안 ("완벽한 격리") | WASM 샌드박스 자체는 사실이지만 플랫폼 쪽은 `sshAccess: 0.0.0.0/0`, K8s API 공개 NLB, 백엔드 Pod가 kubectl로 SpinApp 삭제(클러스터 권한 보유) | [사실] `kops-repo/README.md`, `functions.py` |

**배울 점** [추정]: 심사위원 코멘트(작년 것은 공개 자료 없음 [없음])를 볼 수 없으니 확정할 수는 없지만, 우승했다는 사실로 보아 **이런 간극이 감점 요인으로 크게 작용하지 않았거나, 심사 시간 안에 드러나지 않았다**. 반대로 말하면, 올해 우리가 같은 축에서 "측정한 숫자 + 측정 방법"을 보여주면 작년 우승작보다 한 단계 위의 설득력을 갖는다. 올해 예선 피드백도 정확히 이 방향("具体的なスキーマの工夫を見られると", "AIによる補完の部分はもう少し確認できれば")이었다.

---

## 5. 심사위원이 본 것 역산

작년 본선의 공식 배점은 확인하지 못했다 [없음]. 아래는 **올해 예선 공식 배점** [공식, 킥오프 PPT]을 같은 운영사(Progate × KOREC)의 기준틀로 가정하고 작년 우승작을 대입한 것이다 [추정].

| 올해 예선 배점 항목 | 작년 우승작에서 이 항목을 채운 요소 | 강도 [추정] |
|---|---|---|
| 완성도·데모 30 — 실제 동작, 그 자리 데모, 누구나 접근 | 코드 작성→빌드→배포→호출→로그·메트릭까지 웹 콘솔에서 시연. 고정 도메인 `eunha.icu` | 강 |
| 클라우드 활용 30 — 환경 차이 흡수, 클라우드 고유 기능 대응 | VPC·ALB·CloudFront·WAF·ECR·DynamoDB·S3·IRSA·Spot·Cluster Autoscaler. 주제 제약("EC2 위에서") 안에서 AWS를 폭넓게 사용 | 강 |
| 팀 개발 20 — 팀워크, 설계 문서화, 대안 검토 과정 | 5명이 역할을 명확히 나눔(조직 README에 역할 명시). 트러블슈팅 리포트, DynamoDB 설계 문서, 배포 플로 문서, RKE2→K3s→kOps 시행착오 | 중~강 |
| 독창성 10 | 컨테이너 대신 WASM이라는 "한 방"의 차별점 | 강 |
| AI 활용 10 | Kiro 스펙, Lovable 목업. 다만 **제품 기능으로서의 AI는 없음** | 약 (작년 본선에 이 항목이 있었는지 불명 [없음]) |

**심사위원 관점 정리** [추정]:

1. **문제 정의의 날카로움.** "서버리스 플랫폼을 만들라"는 주제에 대해 대부분의 팀은 컨테이너 기반 FaaS(Knative/OpenFaaS 류)를 만들었을 것이다. 이 팀은 그 방식의 약점(콜드스타트·격리)을 먼저 꺼내고 WASM이라는 다른 실행 단위를 들고 왔다. 소프트뱅크 기술팀 입장에서 "업계 동향을 알고 있다"는 신호다.
2. **주제 제약을 정면으로 받아들임.** 매니지드 서비스로 우회하지 않고 kOps로 컨트롤 플레인부터 세웠다. 인프라 엔지니어 채용 대회라는 성격과 맞다.
3. **데모가 끊기지 않음.** 사용자 경험이 "코드 붙여넣기 → 버튼 → URL → 결과 → 로그/메트릭"으로 이어진다. 내부가 복잡해도 심사위원은 이 흐름만 본다. 우리 예선의 "URL 고정이 훌륭하다"는 피드백과 같은 평가 축이다.
4. **운영 감각.** 비용 추정표, Spot, 노드 역할 분리, 관측성. "만들고 끝"이 아닌 "운영할 것"을 전제로 한 설계로 보인다.
5. **일본 심사위원 배려.** UI 일본어 지원. 발표 언어는 확인 못 함 [없음]. 우리 예선에서는 "일본어 발표"가 여러 심사위원 코멘트에 등장했으므로, 언어가 실제로 인상에 영향을 준다 [사실, 우리 예선 피드백].

---

## 6. 우리 예선 피드백과 겹쳐 보기

| 우리 예선 피드백 [사실] | 작년 우승작에서 같은 축 | 본선 시사점 [추정] |
|---|---|---|
| IR 접근이 테마에 맞다, 그런데 **구체적인 스키마 고안점**을 보고 싶었다 | 우승작도 SpinApp 매니페스트 모델·DynamoDB 키 설계를 문서로 남겼지만 발표에서 보였는지는 불명 | 핵심 데이터 구조(IR, 스키마, 상태 머신)는 **슬라이드/문서 한 장으로 직접 보여준다** |
| DB·스토리지·인프라 고유 기능까지 어떻게 확장하나 | 우승작은 함수 실행만 다루고 상태(DB) 연결은 다루지 않음 (Roadmap에도 없음) | "확장 지점"을 설계에 미리 표시해 둔다. 질문 받을 걸 전제로 |
| 온프레가 단일 이미지 pull → 클라우드와 같은 다중 컨테이너로 | — | 환경 간 **대칭성**을 본다. 한쪽만 깊은 설계는 아쉬움으로 지적됨 |
| 정적 분석 + AI 보완 부분을 더 확인하고 싶다 | 우승작도 AI는 개발 도구로만 사용 | AI를 쓴다면 **동작과 정확도를 확인 가능한 형태**로 보여준다 |
| URL 고정으로 데모가 좋다 | 우승작도 고정 도메인 + 콘솔 | 데모 동선은 이미 강점. 유지한다 |

---

## 7. 우리가 가져갈 것 / 피할 것 [추정]

가져갈 것:
- **한 줄 서사 + 일관된 파생 결정.** "X 문제를 Y로 푼다"를 먼저 정하고, 인프라 선택을 전부 그 서사에서 설명할 수 있게 한다.
- **사전 1주 동안 인프라를 끝내 두기.** 작년 팀은 클러스터를 세 번 갈아엎었고, 현장 이틀은 통합과 UI에 썼다. 본선 킥오프 직후 클러스터·CI·도메인을 먼저 고정한다.
- **고정 URL + 웹 콘솔 + 관측 화면**으로 끊기지 않는 데모.
- **트러블슈팅 기록을 문서로 남기기.** "팀 개발 20점"의 대안 검토·고찰 증거가 된다.

피할 것 (= 우리가 이길 지점):
- **측정 없는 성능 주장.** 기동 시간·처리량은 측정 스크립트, 조건, 결과 그래프를 같이 낸다 (예: 같은 함수를 컨테이너 vs WASM으로 0→1 기동 p50/p99).
- **README와 실제 구현의 불일치.** 발표 자료의 주장 하나하나를 `file:line`이나 데모로 증명할 수 있게 한다.
- **스케일 투 제로 없이 "서버리스"라고 부르기.** 서버리스 주제가 다시 나오면 0→N 스케일링(KEDA, Knative, SpinKube autoscaler)이 첫 질문이 될 가능성이 높다.

---

## 8. 확인하지 못한 것 [없음]

- 2025 본선의 **주최측 공식 주제 문구, 배점, 발표 시간, 심사위원 구성**. 우승팀 README에만 주제가 남아 있다.
- 작년 **심사위원 코멘트**, 발표 슬라이드·영상, 발표 언어.
- **다른 본선 팀들의 레포.** `sh-final-red` 등 다른 색 조직은 존재하지 않음(404). 다른 이름을 썼을 수 있으나 찾지 못함.
- ArgoCD Application, Grafana 대시보드, Prometheus/Loki 설치 설정. 비공개 레포에 있었을 수 있음.
- kOps를 최종 선택한 이유, K3s를 포기한 이유.
- 공개 회고 글(블로그·velog 등). 검색했지만 찾지 못함.

## 출처

- 우승팀 레포 (2026-10-05 클론): https://github.com/sh-final-blue — `.github`, `2025softbank-hackathon-final`, `web-backend`, `web-faas-builder`, `infra-iac`, `kops-repo`, `poc-wasm-spin`, `helm-charts`
- [공식] SoftBank Hackathon 2025 in Korea 모집 공고: https://linkareer.com/activity/273708
- [공식] 청년개발자신문 기사: https://www.devtimes.co.kr/news/433926
- [공식] 올해 예선 킥오프 PPT (사용자 업로드, "Term1｜Kickoff SoftBank Hackathon 2026 powered by KOREC × Progate")
- [사실] 우리 예선 심사 피드백 (사용자 메시지, 2026-10-05)
