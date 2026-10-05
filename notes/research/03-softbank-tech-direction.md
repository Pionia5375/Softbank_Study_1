# 03. 소프트뱅크 기술 방향: AITRAS 오케스트레이터 · llm-d · NVIDIA Serverless API

> 조사일: 2026-10-05 · 범위: 조사 항목 3 [소프트뱅크 기술 방향]
> 목적: "소프트뱅크가 지금 푸는 문제"를 정리하고 본선(11/7–8) 주제 예측과 연결한다.

## 표기 규칙

| 태그 | 의미 |
|---|---|
| **[공식]** | 소프트뱅크·Red Hat·NVIDIA·OCM 프로젝트의 1차 자료에 적힌 내용 |
| **[2차]** | 업계 매체 보도 (1차 자료로 직접 확인 못 함) |
| **[추측]** | 위 자료를 근거로 내가 추론한 것. 근거를 같이 적는다 |
| **[없음]** | 찾아봤지만 공개 자료에서 확인할 수 없었던 것 |

---

## 0. 한 줄 요약

소프트뱅크는 **"여러 곳에 흩어진 GPU 클러스터(기지국 엣지 + AI 데이터센터)를, 성격이 전혀 다른 워크로드(초저지연 vRAN / 메모리 많이 먹는 AI 추론)가 같이 쓰게 하면서, 남는 GPU를 API로 팔아 돈을 버는 것"**을 풀고 있다. 기술적으로는 **멀티 클러스터 스케줄링(OCM + 동적 스코어링) + 분산 LLM 추론(llm-d/vLLM) + 서버리스형 추론 API**의 조합이다. **[추측: 아래 1~4절 공식 자료들을 묶은 해석]**

---

## 1. AITRAS와 AITRAS Orchestrator

### 1.1 AITRAS가 뭔가
- **[공식]** AITRAS는 소프트뱅크의 AI-RAN 제품으로, "AI와 RAN(무선 접속망)을 같은 가속 컴퓨팅 플랫폼에서 돌리는 것"이 목표. NVIDIA GH200 Grace Hopper + NVIDIA AI Aerial 기반, 2026 회계연도부터 상용망 도입 목표. ([topics/224](https://www.softbank.jp/en/corp/technology/research/topics/224/))
- **[공식]** 실측 수치: AITRAS 서버 1대로 100MHz 4T4R 20셀 처리, Transformer 기반 AI로 5G 속도 약 30% 개선, Massive MIMO 스펙트럼 효율 약 3배. (같은 출처)
- **[공식]** AI-RAN Alliance 참여 조직 140개 이상 (2026년 7월 기준). (같은 출처)

### 1.2 오케스트레이터가 왜 필요한가 (핵심 문제)
- **[공식]** vRAN은 "초저지연 처리", AI 앱은 "대용량 데이터의 효율적 메모리 관리 + 여러 워크로드의 최적 배치"를 요구한다. 요구사항이 충돌하는 두 워크로드를 같은 인프라 위에서 돌리는 게 과제. ([2024-11-12 보도자료, BusinessWire](https://www.businesswire.com/news/home/20241112940159/en/SoftBank-Corp.-Develops-Orchestrator-to-Operate-AI-and-vRAN-on-the-Same-Virtualized-Infrastructure))
- **[공식]** 오케스트레이터는 "사용자 배포 요청, 수요 예측, 공급 측 자원 가용성을 고려한 최적 매칭 알고리즘"과 "그에 따른 동적 인프라 자원 조정"을 한다. Red Hat OpenShift 기반, 일본 내 분산 거점의 멀티 클러스터를 중앙 관리. (같은 출처)
- **[공식]** 전력 관점도 핵심: Red Hat의 Kepler(eBPF 기반 전력 측정)로 Pod·MIG 단위 GPU 전력을 계산하고, 전력 소비를 예측해 배치를 최적화. ([Red Hat×SoftBank MWC 2025, IntelligentCIO](https://www.intelligentcio.com/eu/2025/03/03/mobile-world-congress-red-hat-announces-collaboration-with-softbank/))
- **[공식]** AI-RAN Alliance WG2 화이트페이퍼(2026-02-26)에서 소프트뱅크가 오케스트레이터 요구사항 논의를 주도·편집. "AI-RAN Orchestrator는 AI·RAN 각 도메인 오케스트레이터(DSO)에 자원을 배분한다." ([topics/198](https://www.softbank.jp/en/corp/technology/research/topics/198/), [topics/196](https://www.softbank.jp/en/corp/technology/research/topics/196/))
- **[공식]** 2026-02-27 Ericsson Intelligent Automation Platform과 연동, AI·RAN 도메인 간 동적 자원 배분 시연. ([topics/191](https://www.softbank.jp/en/corp/technology/research/topics/191/))
- **[없음]** vRAN과 AI 사이의 구체적 우선순위 규칙(예: RAN 트래픽 급증 시 AI Pod를 몇 ms 안에 축출하는지)은 공개 자료에 없음.

---

## 2. Dynamic Scoring Framework (DSF)와 OCM 기여

### 2.1 사실관계
- **[공식]** 2026-02-18, 소프트뱅크가 AITRAS Orchestrator의 핵심 컴포넌트인 **Dynamic Scoring Framework**를 **Open Cluster Management(OCM)** 에 업스트림 기여. Red Hat이 OpenShift / Advanced Cluster Management(ACM)에 통합 예정. ([보도자료](https://www.softbank.jp/en/corp/news/press/sbkk/2026/20260218_01/))
- **[공식]** 코드 위치: 처음엔 `open-cluster-management-io/addon-contrib/dynamic-scoring-framework`(v0.1.0)였고, 현재는 독립 레포 **https://github.com/open-cluster-management-io/dynamic-scoring-framework** 로 "졸업". Helm 차트 `ocm/dynamic-scoring-framework`. Go 모듈 경로는 `open-cluster-management.io/dynamic-scoring`. (레포 README, 2026-10-05 확인)
- **[공식]** Red Hat Developer 해설 글 (Jian Qiu, 2026-03-09): Kueue, ArgoCD와 코드 수정 없이 연동 가능하다고 설명. ([링크](https://developers.redhat.com/articles/2026/03/09/smarter-multi-cluster-scheduling-dynamic-scoring-framework))

### 2.2 OCM 기본 개념 (DSF를 이해하려면 먼저 필요)
- **[공식]** OCM = Kubernetes 멀티 클러스터·멀티 클라우드 관리 OSS (CNCF Sandbox). 허브(hub) 클러스터 1개가 여러 관리 대상(managed/spoke) 클러스터를 관리.
- 배치 결정에 쓰는 리소스 **[공식, topics/196]**:

| 리소스 | 역할 | Spring 개발자 식 비유 **[추측: 이해용]** |
|---|---|---|
| `Placement` | "이런 조건 만족하는 클러스터에 배치해라" | 로드밸런서의 라우팅 규칙 |
| `PlacementDecision` | 조건을 만족해서 실제로 선택된 클러스터 목록 | 규칙 평가 결과 |
| `AddOnPlacementScore` | 클러스터별 점수 (배치 판단 재료) | 헬스체크 + 가중치 |
| `ManifestWork` / `ManifestWorkReplicaSet` | 결정된 클러스터에 실제 매니페스트 배포 | 배포 실행기 |

### 2.3 DSF 구조
- **[공식]** 구성 요소 4개 (topics/196 + 레포 README):
  1. **Scoring API**: 시계열 메트릭을 받아 점수를 돌려주는 공통 인터페이스. 평가 로직 자체는 프레임워크 밖에서 구현(Flask/FastAPI + Prophet, PyTorch, LLM 등). config 엔드포인트로 필요한 데이터 소스·조회 범위·주기를 선언.
  2. **DynamicScorer (CRD)**: Scoring API를 등록.
  3. **DynamicScoringConfig (CRD)**: 어떤 클러스터에 어떤 Scorer를 돌릴지 필터 규칙 → ConfigMap으로 각 클러스터에 배포.
  4. **DynamicScoringAgent**: 각 클러스터에 OCM Addon으로 자동 배포. 로컬 Prometheus에서 메트릭을 가져와 Scoring API를 주기적으로 호출하고, 결과를 Prometheus 메트릭 또는 `AddOnPlacementScore`로 내보냄.
- **[공식] 설계 트레이드오프** (레포 `docs/concept-and-design.md`): "평가 로직은 무겁고 유스케이스마다 달라서 클러스터마다 띄우면 비효율" vs "데이터 신선도를 위해 메트릭 수집 근처에서 트리거해야 함" → **평가 로직은 중앙, 수집·트리거는 분산**하는 하이브리드. 이 트레이드오프 설명 방식 자체가 본선 발표의 좋은 본보기.
- **[공식]** 샘플 Scorer: CPU 기반, **LLM 기반 시계열 예측**, Darts 선형회귀 예측, 정적 점수, **GPU 전력·성능 AI 워크로드 Scorer**, OCM Policy 감시자, **MCP 서버(AI 보조 최적화용)**. (레포 README)
- **[공식]** 최적화 예시(`docs/optimization-using-dsf.md`): 점수 + OCM Policy로 클러스터별 **MIG 설정(GPU 분할)을 바꿔가며** GPU 수요(앱)와 공급(정책)을 맞춰 배치. 
- **[공식]** 레포 설계 문서의 사용자 스토리 1: "이종 하드웨어 멀티 클러스터 LLM 추론 플랫폼에서 GPU 사용률·전력·비용으로 효율 점수를 매겨 배치".
- **[없음]** DSF 적용 전후 성능·전력 절감 수치는 소프트뱅크 해설(topics/196)에도 없음.
- **[2차·NVIDIA 블로그]** 오케스트레이터로 GPU 활용률을 기존 약 33%에서 거의 100%까지 올렸다는 주장 있음 ([NVIDIA 블로그](https://developer.nvidia.com/blog/ai-ran-goes-live-and-unlocks-a-new-ai-opportunity-for-telcos/)). 측정 조건 미공개.

### 2.4 로컬에서 직접 돌려볼 수 있는가
- **[공식]** Quickstart는 kind로 hub + managed 클러스터를 만들고 `clusteradm`, `helm`, `kube-prometheus-stack`으로 구성. 즉 **노트북 한 대로 재현 가능**하고 AWS 비용 없음.
- **[추측]** 4주 학습 안에서 "멀티 클러스터 스케줄링" 실습 소재로 가장 직접적. 단, kind 클러스터 3개 + Prometheus는 메모리 16GB 이상 권장 (경험칙, 공식 수치 아님).

---

## 3. llm-d 연동

- **[공식]** Red Hat 블로그 (Tushar Katarki, 2026-02-18): ([링크](https://www.redhat.com/en/blog/how-llm-d-brings-critical-resource-optimization-softbanks-ai-ran-orchestrator))
  - vLLM = 단일 노드 GPU 추론 엔진, **llm-d = vLLM을 Kubernetes 위에서 여러 노드로 분산 오케스트레이션**하는 OSS.
  - 연동 포인트 ① **Prefill/Decode 분리(disaggregation)**: "AITRAS가 prefill과 decode 단계에 특화된 GPU 자원을 동적으로 할당". 
  - ② **지능형 라우팅**: prefix·KV 캐시·부하 인지(prefix, kvcache, and load aware) 라우팅으로 요청을 GPU에 보냄.
  - 역할 분담: "AITRAS는 여러 GPU 클러스터에 걸쳐 RAN 워크로드와 LLM 요청을 오케스트레이션·최적화하고, llm-d와 vLLM이 추론 요청을 라우팅한다."
  - 기대 효과: 이종 워크로드 통합 관리, 수요 기반 자율 스케일링, 전력 효율·TCO 개선.
- **[없음]** 처리량·지연·비용 개선 수치는 블로그에 없음.
- **[추측] 계층 구조로 정리하면:**

```
[AITRAS Orchestrator + DSF]  ← 어느 클러스터에, 얼마만큼의 GPU를 (클러스터 간)
        │
[llm-d]                      ← 클러스터 안에서 어느 vLLM 인스턴스로 요청을 보낼지 (요청 단위)
        │
[vLLM]                       ← GPU 1장(1노드) 안에서 어떻게 빨리 돌릴지
```

  → "배치(placement) 문제"와 "라우팅(routing) 문제"를 다른 계층에서 푼다는 구조. 본선에서 설계 질문이 나오면 이 구분을 말할 수 있어야 함.

### 용어 짧게 (Spring 개발자용) **[추측: 이해용 단순화]**
- **Prefill**: 프롬프트 전체를 한 번에 읽는 단계. 계산 많음(compute-bound).
- **Decode**: 토큰을 하나씩 생성하는 단계. 메모리 대역폭 많음(memory-bound).
- 둘의 병목이 다르므로 다른 GPU에 나눠 배치하면 효율이 오름 = disaggregation.
- **KV 캐시 인지 라우팅**: 같은 앞부분(prefix)을 이미 계산해 둔 인스턴스로 요청을 보내 재계산을 피함. 세션 스티키 라우팅의 LLM 버전.

---

## 4. NVIDIA Serverless API와 "GPU를 API로 판다"는 축

### 4.1 NVIDIA AI Enterprise Serverless API
- **[공식]** NVIDIA 블로그 (2024-11, 후지사와시 실증): "AI-RAN 위에 AI 워크로드를 배포·관리하는, NVIDIA AI Enterprise 기반 서버리스 API". 클라우드에서 들어온 외부 추론 작업을, 여유 용량이 생긴 분산 AI-RAN 서버로 보내는 구조 → 저지연 로컬 추론 마켓플레이스. ([NVIDIA 블로그](https://developer.nvidia.com/blog/ai-ran-goes-live-and-unlocks-a-new-ai-opportunity-for-telcos/))
- **[공식]** 2024-11-12 소프트뱅크 보도자료에도 "NVIDIA AI Enterprise와 연동해 serverless API 지원"이 오케스트레이터 기능으로 명시. (BusinessWire 링크, 1.2절)
- **[2차]** 수익 모델: RAN은 평균 약 1/3 용량만 쓰므로 나머지 2/3를 AI 추론으로 판매. "capex 1달러당 5년간 약 5달러 추론 매출", AI 중심 시나리오 ROI 219%. GB200-NVL2 서버당 약 25,000 tokens/s → 서버당 시간당 $20, 월 $15K 수익 가능. ([TelecomTV](https://www.telecomtv.com/content/telcos-and-ai-channel/softbank-and-nvidia-tie-revenue-model-to-new-ai-ran-solution-51753/), NVIDIA 블로그) — NVIDIA·소프트뱅크 자체 추정치이며 독립 검증 아님.
- **[없음]** 이 서버리스 API의 엔드포인트 스펙, 콜드스타트 시간, 과금 단위 등 상세 기술 문서는 공개 자료에서 찾지 못함.

### 4.2 Infrinia AI Cloud OS (같은 문제의 데이터센터 버전)
- **[공식]** 2026-01-21 발표. GB200 NVL72용 소프트웨어 스택. 두 기능: **KaaS**(멀티테넌트 Kubernetes as a Service), **Inf-aaS**(LLM 추론을 API로 제공, **OpenAI 호환 API**, "Kubernetes를 몰라도 모델만 고르면 배포"). BIOS·RAID·OS·GPU 드라이버·네트워크·K8s 컨트롤러·스토리지까지 전체 자동화. NVLink 도메인·GPU 근접성 기반 노드 자동 할당. 테넌트 격리, 모니터링·페일오버 자동화. ([보도자료](https://www.softbank.jp/en/corp/news/press/sbkk/2026/20260121_01/))
- **[공식]** 2026-05-25: "AI Data Center GPU Cloud"로 베타, **2026년 10월 정식 출시** 예정(= 본선 직전). ([보도자료](https://www.softbank.jp/en/corp/news/press/sbkk/2026/20260525_01/))
- **[추측]** Inf-aaS의 "모델만 고르면 API가 나온다"는 UX는 사실상 서버리스 추론. AI-RAN 쪽(엣지)과 데이터센터 쪽(Infrinia) 모두 **"인프라를 숨기고 API로 GPU를 판다"** 는 같은 방향.

---

## 5. 정리: 소프트뱅크가 지금 푸는 문제 5가지

| # | 문제 | 근거 | 확실도 |
|---|---|---|---|
| 1 | **이종 워크로드 공존**: 지연 민감(vRAN)과 처리량 중심(AI)이 같은 GPU를 나눠 쓰기 | 1.2절 보도자료 | [공식] |
| 2 | **멀티 클러스터 배치 최적화**: 지역·하드웨어가 다른 여러 클러스터 중 어디에 둘지, 사용자 정의 점수로 결정 | DSF, OCM 기여 | [공식] |
| 3 | **전력·비용을 1급 지표로**: CPU/메모리뿐 아니라 전력 예측·GPU 전력 효율로 배치 | Kepler, DSF 전력 Scorer | [공식] |
| 4 | **분산 LLM 추론의 효율**: prefill/decode 분리, KV 캐시 인지 라우팅 | llm-d 연동 | [공식] |
| 5 | **유휴 GPU 수익화**: 서버리스 추론 API·OpenAI 호환 API로 외부 고객에 판매, 멀티테넌트 격리 | NVIDIA Serverless API, Infrinia Inf-aaS | [공식] (수익 수치는 [2차]) |

공통 키워드 **[추측]**: *"인프라 차이를 숨기는 추상화 계층 + 그 아래에서 점수 기반으로 배치를 자동 결정"*. 예선 피드백에서 칭찬받은 "배포 대상 차이를 신경 쓰지 않는 IR"과 "URL 고정으로 뒷단을 숨김"과 같은 방향의 사고다.

---

## 6. 본선 주제 예측과의 연결

전제 (모두 학습자 제공 정보, 내가 직접 확인 안 함):
- 작년 본선 주제는 "서버리스 플랫폼 직접 구현".
- 올해 예선 테마는 "One Action, Infinite Clouds." (킥오프 PPT slide 14–21: 로컬 앱을 AI로 하이퍼스케일러/온프레미스에 원터치 배포. 평가 중 "클라우드 활용 수준 30점 = 환경 차이 흡수·포터빌리티, 각 클라우드 고유 기능 대응").
- 모집 직군은 인프라 엔지니어 / 클라우드 엔지니어 (킥오프 PPT slide 8–9). **AI-RAN 연구 직군은 아님** → 본선 과제가 RAN 자체를 다룰 가능성은 낮다고 봄 **[추측]**.

### 가설 (모두 [추측])

| 가설 | 내용 | 회사 방향과의 연결 | 예선과의 연속성 | 가능성 |
|---|---|---|---|---|
| **A. 멀티 클러스터 스마트 배치** | 여러 환경(클라우드 여러 개 + 온프레미스)에 동시에 걸쳐, 비용·지연·부하 같은 **점수로 배포 위치를 자동 결정**하고 상황이 바뀌면 재배치 | DSF/OCM 그 자체 (문제 2·3) | 예선의 "어디에 배포할지"를 "어디가 최적인지 판단"으로 한 단계 심화. 피드백의 "온프레미스도 여러 컨테이너 협조" 지적과도 맞닿음 | 높음 |
| **B. AI 추론 서버리스 플랫폼** | 모델(또는 함수)을 올리면 API 엔드포인트가 나오고, 요청량에 따라 GPU/CPU를 0↔N 스케일. 멀티테넌트·과금 | NVIDIA Serverless API, Infrinia Inf-aaS (문제 4·5) | 작년 본선 "서버리스 플랫폼"의 AI 버전 | 중~높음 |
| **C. 공유 자원 위 우선순위 스케줄링** | 지연 민감 워크로드와 배치성 워크로드가 같은 노드 풀을 공유할 때, 우선순위·선점·자원 분할(MIG 유사)로 SLO 지키기. 장애 대응·성능 튜닝 시나리오 포함 | vRAN vs AI 공존 (문제 1) | 예선보다는 거리가 있음 | 중 |

- **[추측]** 해커톤은 2일·클라우드 비용 팀당 ₩300,000(예선 기준) 제약이 있으므로, 실제 GPU를 요구하는 과제보다는 **CPU 컨테이너로 "GPU 자원"을 흉내 내게 하거나 kind/k3s 같은 경량 환경에서 개념을 구현**하는 형태가 현실적.
- **[추측]** 어떤 가설이든 심사에서 나올 질문 예: "점수는 어떤 지표로 어떻게 계산했나, 왜 그 지표인가", "배치 판단과 요청 라우팅을 어디서 분리했나", "평가 로직을 중앙에 두나 각 클러스터에 두나" (DSF 설계 문서의 트레이드오프 그대로).

### 학습 시사점 (항목 5 갭 분석 스레드로 넘길 재료)
1. Kubernetes 기본 (Deployment/Service/Ingress, requests/limits, HPA) → 모든 가설의 바닥.
2. **OCM 실습**: kind로 hub + 2 cluster, `Placement` + `AddOnPlacementScore`로 배치 바꾸기 → 가설 A.
3. **DSF Quickstart 그대로 따라 하기** + 샘플 Scorer를 Spring Boot/FastAPI로 직접 작성 → 가설 A. 소프트뱅크 엔지니어가 만든 OSS를 직접 써봤다는 것 자체가 발표 포인트가 될 수 있음 **[추측]**.
4. Prometheus 메트릭 기반 스케일링 (KEDA 또는 Knative scale-to-zero) → 가설 B.
5. vLLM 또는 llama.cpp를 CPU로 띄워 OpenAI 호환 API 만들어 보기, 앞단에 간단한 라우터 → 가설 B. llm-d는 GPU 전제라 개념 이해까지만 **[추측]**.
6. PriorityClass·선점, ResourceQuota, 노드 taint/toleration → 가설 C.

---

## 7. 확인 못 한 것 / 다음에 볼 것
- **[없음]** AI-RAN Alliance WG2 화이트페이퍼 본문 (다운로드 필요, 이번엔 보도 요약만 확인).
- **[없음]** NVIDIA AI Enterprise Serverless API 기술 스펙.
- **[없음]** DSF·llm-d 연동의 정량 결과.
- 소프트뱅크 2024-12 AI-RAN 화이트페이퍼 PDF: https://www.softbank.jp/corp/set/data/technology/research/story-event/Whitepaper_Download_Location/pdf/SoftBank_AI_RAN_Whitepaper_December2024.pdf (미독)
- DSF 레포의 `docs/scoring-api-samples.md`, `samples/ai-workload-scorer` 상세 (실습 시 읽기).

## 출처 목록
- SoftBank 보도자료 2026-02-18 (DSF 오픈소스화): https://www.softbank.jp/en/corp/news/press/sbkk/2026/20260218_01/
- SoftBank 기술 해설 DSF: https://www.softbank.jp/en/corp/technology/research/topics/196/
- SoftBank AI-RAN 상용화 해설: https://www.softbank.jp/en/corp/technology/research/topics/224/
- AI-RAN Alliance 오케스트레이터 화이트페이퍼 소개: https://www.softbank.jp/en/corp/technology/research/topics/198/
- SoftBank × Ericsson 오케스트레이터 연동: https://www.softbank.jp/en/corp/technology/research/topics/191/
- SoftBank 2024-11-12 오케스트레이터 개발 발표: https://www.businesswire.com/news/home/20241112940159/en/SoftBank-Corp.-Develops-Orchestrator-to-Operate-AI-and-vRAN-on-the-Same-Virtualized-Infrastructure
- Red Hat 블로그 llm-d × AITRAS: https://www.redhat.com/en/blog/how-llm-d-brings-critical-resource-optimization-softbanks-ai-ran-orchestrator
- Red Hat Developer DSF 해설: https://developers.redhat.com/articles/2026/03/09/smarter-multi-cluster-scheduling-dynamic-scoring-framework
- DSF 레포: https://github.com/open-cluster-management-io/dynamic-scoring-framework
- Red Hat × SoftBank MWC 2025 (IntelligentCIO): https://www.intelligentcio.com/eu/2025/03/03/mobile-world-congress-red-hat-announces-collaboration-with-softbank/
- NVIDIA 블로그 AI-RAN Goes Live: https://developer.nvidia.com/blog/ai-ran-goes-live-and-unlocks-a-new-ai-opportunity-for-telcos/
- TelecomTV 수익 모델 기사: https://www.telecomtv.com/content/telcos-and-ai-channel/softbank-and-nvidia-tie-revenue-model-to-new-ai-ran-solution-51753/
- Infrinia AI Cloud OS 발표: https://www.softbank.jp/en/corp/news/press/sbkk/2026/20260121_01/
- AI Data Center GPU Cloud 발표: https://www.softbank.jp/en/corp/news/press/sbkk/2026/20260525_01/
- 예선 킥오프 PPT (학습자 제공, slide 8–9, 14–21, 40–41)
