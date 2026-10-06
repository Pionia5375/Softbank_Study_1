로드맵 위치: 1~2주차 / 회사 지향점 심화 + 본선 주제 후보 / 본선 주제 선정·설계 문서 첫 문단·개인 면접 답변

# 07. 소프트뱅크 지향점 심화 → 본선 주제 후보 4개

> 조사일: 2026-10-06 · 03(기술 방향)·02(예선 주제)·04(심사)·01(작년 우승팀)을 다시 하지 않고, **2026년 5~10월 새 자료**와 **채용 공고·해커톤 패턴**을 더했다.
> 계기: 작년 참가자 홍석 님 조언 【사용자】 "새롭고 좋은 기술보다 **소프트뱅크 지향점과 맞닿아 있는지**가 핵심, 기술 선택의 이유·트레이드오프, 협업 태도, 상세 설계 문서 + 바로 시연".

## 표기

| 태그 | 의미 |
|---|---|
| 【사실】 | 출처에 적힌 내용 (링크 병기) |
| 【추정】 | 사실들을 묶어 내가 추론한 것. 근거를 같이 적음 |
| 【미확인】 | 찾아봤지만 공개 자료에서 못 찾은 것 |
| 【사용자】 | Jeong이 알려준 것 (홍석 님 조언 포함) |

---

## 0. 한 페이지 요약

1. **회사 한 줄**: 소프트뱅크는 2026년 5월 새 중기계획에서 슬로건을 "Beyond Carrier" → **"Activate AI for Society"** 로 바꾸고, 미야카와 사장이 **"클라우드 서비스 회사가 된다"** 고 말했다. 돈 버는 축은 **GPU를 쿠버네티스·추론 API로 파는 것(KaaS + Inference-as-a-Service)** 이고, 10월(본선 직전) 상용 출시, 7월엔 미국 법인 SB Neo까지 세웠다. 【사실, 1·2절】
2. **엔지니어 한 줄**: 지금 채용 공고와 공개 발표는 거의 다 **"멀티테넌트 쿠버네티스 플랫폼 + GPU 추론 + 멀티 클러스터 배치 + 소버린(국내 통제)"** 을 말한다. DSF를 KubeCon Japan 2026에서 발표한 디렉터가 속한 **공통플랫폼개발본부**가 KaaS 엔지니어를 뽑고 있다. 【사실, 3·4절】
3. **해커톤 패턴**: 예선은 "배포 경험/플랫폼", 본선은 **"원시 VM(IaaS) 위에 매니지드 서비스를 직접 만들어라"**(2025: EC2 위 서버리스). 둘 다 앱이 아니라 **플랫폼 엔지니어링** 문제. 【사실: 2025·2026 주제 문장 / 추정: 패턴】
4. **주제 후보 (가능성 순)** 【전부 추정】
   - **A. 미니 Infrinia: 멀티테넌트 추론 서버리스 플랫폼** (모델 고르면 OpenAI 호환 API가 나오고, 테넌트별 격리·쿼터·과금, 0↔N 스케일)
   - **B. 점수 기반 멀티 클러스터 배치 + 자동 페일오버** (미니 AITRAS/DSF)
   - **C. 자율 운영 에이전트: 장애 감지 → 원인 분석 → 가드레일 안에서 자동 복구** (LTM 멀티 에이전트, Autonomous Network Level 4 방향)
   - **D. 소버린 AI 게이트웨이: 민감도에 따라 국내/외부 모델로 나눠 보내는 정책 라우터** (오늘 나온 단바 집행임원 메시지 그대로)
5. **공부 방향 결론** 【추정】: 리셋할 필요는 없다. 1주차 쿠버네티스 기반은 네 후보 모두의 바닥이다. 다만 2주차부터 **A·B·C에 공통으로 걸리는 4개(멀티테넌시, 메트릭 기반 스케일, 멀티 클러스터, 관측+자동 조치)** 를 우선하고, 매 실습 결과를 **"소프트뱅크가 왜 이걸 하는가" 한 문단**과 같이 남긴다. (7절)

---

## 1. 회사 전략: 2026년에 바뀐 것

### 1.1 중기계획과 사장 메시지
- 【사실】 2026-01-01 신년사: 미야카와 사장이 컴퓨팅 파워를 **"차세대 사회 인프라(次世代社会インフラ)"** 로 규정. 구성요소로 계산자원, 국산 LLM Sarashina, Oracle과의 소버린 클라우드, 차세대 메모리를 듦. 사내 AI 에이전트 250만 개, 2026년은 "피지컬 AI의 해". https://www.softbank.jp/corp/news/press/sbkk/2026/20260101_01/
- 【사실】 2026-05-11 FY2025 결산 + FY2030까지 중기계획.
  - 슬로건 "Beyond Carrier" → **"Activate AI for Society"**.
  - "AI 투자는 씨 뿌리기에서 **수확 단계**로."
  - FY2030 영업이익 1.7조 엔, 순이익 7,000억 엔. **클라우드·AI 매출을 2025→2030 두 배로.**
  - 사장 발언: **"클라우드 서비스 회사가 된다."**
  - 출처: https://k-tai.watch.impress.co.jp/docs/news/2107720.html , https://www.softbank.jp/sbnews/entry/20260508_01
- 【사실】 2026-08-04 FY2026 1분기: 매출 1조 8,147억 엔(+9%), 법인 부문 매출 +11%, **클라우드·AI 서비스 +31%**, 연 30% 성장 지속 전망. AI 계산자원 제공 매출이 이미 1분기부터 발생. 클라우드·AI 목표 매출총이익률 30~40%. https://www.softbank.jp/en/sbnews/entry/20260804_01 , https://www.softbank.jp/corp/ir/documents/presentations/fy2026/q1_investors_qa/
- 【사실】 **2026-10-06(오늘)** 통합보고서 2026, 단바 히로토라(丹波廣寅) 집행임원(프로덕트·AI 담당) 메시지: 경쟁력은 사무 생산성이 아니라 **기업 핵심 시스템에 AI를 넣는 것**에서 온다. **민감도가 낮은 일은 해외 클라우드·AI, 미션 크리티컬·고민감 데이터는 소버린 클라우드·소버린 AI**로 나누자. 소버린 = 데이터·기술·운영을 국내에서 통제. https://www.softbank.jp/sbnews/entry/20261006_01

### 1.2 AI 데이터센터 · GPU 클라우드 · Infrinia
- 【사실】 2026-01-21 **Infrinia AI Cloud OS**: 미국 서니베일의 Infrinia 팀이 만든 GPU 데이터센터용 소프트웨어 스택. **KaaS**(멀티테넌트 쿠버네티스)와 **Inf-aaS**(OpenAI 호환 API 추론). BIOS·RAID·OS·GPU 드라이버·네트워크까지 자동화, GB200 NVL72에서 GPU 간 대역폭이 최대가 되게 노드 배치, 테넌트 격리·암호화·자동 모니터링·**과금 API**. https://www.softbank.jp/en/corp/news/press/sbkk/2026/20260121_01/
- 【사실】 2026-05-25 **"AI 데이터센터 GPU 클라우드"**: "네오클라우드"(CoreWeave 같은 GPU 전문 클라우드) 사업. 그룹사 대상 베타 시작, **2026년 10월 상용 출시** 예정. GB200 NVL72, 국내 데이터센터. 사장: "계산자원과 그걸 돌리는 소프트웨어가 AI 자체와 함께 경쟁력을 정한다." https://www.softbank.jp/corp/news/press/sbkk/2026/20260525_01/ , https://atmarkit.itmedia.co.jp/ait/articles/2606/23/news068.html
- 【미확인】 10/6 기준 GPU 클라우드 정식 출시(GA) 보도자료는 아직 못 찾음. 본선 전에 나올 가능성 높음 → **나오면 본선 직전 가장 따끈한 소재**.
- 【사실】 2026-07-02 **SB Neo** 설립(미국 델라웨어, 소프트뱅크 51% · 소프트뱅크그룹 49%). Infrinia로 미국 하이퍼스케일러·기업에 GPU 클라우드 판매, 단계적으로 10GW 규모, FY2027 서비스 개시. https://www.softbank.jp/en/corp/news/press/sbkk/2026/20260702_01
- 【사실】 2026-03-02(MWC) **"Telco AI Cloud"** 비전: ① 대형 GPU 데이터센터(학습) ② AI-RAN 기반 엣지(MEC, 저지연 추론) ③ 둘을 묶는 Infrinia. AITRAS 오케스트레이터가 수요·전력에 따라 계산을 옮김. https://rcrwireless.com/20260312/ai/softbanks-telco-ai-cloud
- 【사실】 데이터센터: 홋카이도 도마코마이(2026-02 기준 공정 60~70%, FY2026 개소 목표, 냉량 기후·재생에너지·재해 분산), 오사카 사카이(옛 샤프 공장, 초기 약 150MW). https://www.softbank.jp/en/sbnews/entry/20260225_01
- 【미확인】 두 데이터센터 실제 가동일.

### 1.3 LLM · 에이전트
- 【사실】 2026-06-30 SB Intuitions **Sarashina3** 공개(mini/nano/guard/embedding/rerank). Oracle Alloy 기반 국내 소버린 클라우드로 제공. 디지털청 정부 AI 시험 모델로 선정. https://www.sbbit.jp/article/cont1/185977
- 【사실】 2026-07-16 **LTM(Large Telecom Model)** = Sarashina + NVIDIA Nemotron(학습 데이터·레시피 공개형). 이유: 효율, 데이터 거버넌스, 투명성. "풀스택 소버린 AI". https://www.softbank.jp/en/corp/technology/research/topics/225/
- 【사실】 2026-03-12 LTM 기반 **멀티 AI 에이전트**로 기지국 통합 작업 검증 시작: 로그·설정에서 이상 감지 → 원인 특정 → 수정안 → **실행** → 관계자 조율. 다음은 장애 대응·트래픽 최적화. 성과 수치는 없음. https://www.softbank.jp/en/corp/news/press/sbkk/2026/20260312_02/
- 【사실】 2026-06-19 TM Forum **자율 네트워크 Level 3** 인증(RAN·코어 장애 관리). 다음 목표는 생성 AI로 **Level 4**. https://www.softbank.jp/corp/news/info/2026/20260619_01/
- 【사실】 2026-02-17 Ampere와 **CPU로 소형·MoE 모델 추론** 실험(llama.cpp 최적화, CPU/GPU 혼합 노드 배치, 저전력·모델 전환 빠르게). 수치는 미공개. https://www.softbank.jp/corp/news/press/sbkk/2026/20260217_01/
- 【사실】 2026-02-16 AMD Instinct **GPU 분할**(1장을 여러 논리 장치로)을 오케스트레이터에 적용. MIG의 AMD판. https://www.softbank.jp/corp/news/press/sbkk/2026/20260216_01/
- 【사실】 SoftBank World 2026(07-24 공개) 키워드: **"Customer Zero"**(AI를 사내에서 먼저 쓴다), **"AI-Ready Modernization"**(AI가 안전하게 바꾸고 테스트할 수 있는 시스템), **"Patching as a Service"**(7월 출시, 3,000사로 확대). https://www.softbank.jp/sbnews/entry/20260724_01
- 【사실】 사내 전 직원(약 2만 명)에게 에이전트 제작을 의무화, 1인 100개 목표(닛케이 2026-06-08). https://reskill.nikkei.com/article/DGXZQOLM0462V0U6A600C2000000/ 개수 표기(250만 vs 2.5억)는 출처마다 달라 【미확인】.

### 1.4 6월 이후 기술 공개의 특징
- 【사실】 6~10월에 **새 오케스트레이터 기능, 새 성능 수치, AITRAS 상용 사이트 발표는 없음**. 새로 나온 건 SB Neo, LTM·오픈 모델, GPU 클라우드 위 피지컬 AI, KubeCon DSF 발표, HAPS/NTN 같은 **사업·전략 쪽**.
- 【추정】 그래서 심사위원 머릿속의 "지금 우리 회사 이야기"는 **GPU 클라우드 상용화(10월) + 소버린 + 에이전트 운영**일 가능성이 크다. 무선(RAN·HAPS)은 직군상 본선 과제와 거리가 있음(03에서 판단한 것과 같음).

---

## 2. 엔지니어 레벨: 실제로 무엇을 만들고 말하나

### 2.1 공개 발표
- 【사실】 **KubeCon + CloudNativeCon Japan 2026**(요코하마, 7/29~30): 공통플랫폼개발본부 디렉터 **다케우치 카즈마사**, "Score-Driven Multi-Cluster Management: An Evaluation Framework for Decision-Making". AI-RAN 오케스트레이터와 DSF를 클러스터 간 자원 배분의 핵심으로 소개. https://www.softbank.jp/corp/technology/research/topics/227/ (일본어만)
- 【사실】 topics/196: AITRAS 오케스트레이터는 **5블록**(멀티 클러스터 관리 / 메트릭 / 동적 스코어링 / 멀티 클러스터 스케줄링 / 자원 재배치). OpenShift + RHACM/OCM, 로컬 Prometheus → 점수를 `AddOnPlacementScore`로 허브에 전송, **OCM Policy로 GPU MIG 설정 변경**, 시계열 전력 예측. 대표 유스케이스는 **LLM 추론 엔드포인트**. https://www.softbank.jp/en/corp/technology/research/topics/196/
- 【사실】 topics/223(2026-07-14): Ericsson과 "AI-RAN Orchestration: shared infrastructure" 백서(슬라이싱·에너지 효율·생애주기 관리).
- 【사실】 topics/221(2026-06-24): "자율 네트워크를 위한 풀스택 소버린 AI" = LTM + Infrinia, 합성 데이터·익명화·샌드박스·가드레일.
- 【미확인】 KubeCon 발표 슬라이드·영상, Qiita/Zenn 회사 계정, Speaker Deck, CloudNative Days 발표, llm-d에 대한 소프트뱅크 명의 기여, DSF 커밋 이력(접근 차단).

### 2.2 채용 공고에서 읽히는 것 (softbank.jp/recruit/career)
| 공고 | 소속 | 핵심 기술 | 【사실】 |
|---|---|---|---|
| KaaS 클라우드 서비스 개발 엔지니어 (004986) | 공통플랫폼개발본부 | K8s 클러스터 관리 기능, **멀티테넌시**·네트워크·스토리지·보안, Python/Go/**Java**, 우대: **CNCF OSS 기여**, CKA/CKS | ✓ |
| Private Cloud 개발 IaaS/KaaS (004975) | | VMware/OpenStack/KVM, K8s/Rancher/OpenShift, CI/CD(**ArgoCD**) | ✓ |
| AI 클라우드 플랫폼 엔지니어 (005070) | AI&HPC 인프라본부 | GPU 클러스터, K8s 관리, **Slurm**, IB/NVLink, Ansible/Terraform | ✓ |
| 소버린 AI 인프라 엔지니어 (004963) | | Terraform, K8s, AWS/GCP/**OCI**, GitHub Actions, LangChain/OpenAI API, 멀티 클라우드 | ✓ |
| 차세대 클라우드 프로덕트 엔지니어 (004720) | | **IAM·KMS·암호화**, 포털 설계, GPU 인프라·PaaS, IaC | ✓ |
| SRO (SB OAI Japan) (004843) | | **SLO/SLI**, 장애 대응, 변경 관리, **LLM·에이전트 모니터링** | ✓ |

- 【추정】 DSF 발표자와 KaaS 공고가 같은 본부. 즉 **"멀티 클러스터 배치"와 "멀티테넌트 KaaS"는 같은 팀의 같은 제품 라인**이다. 해커톤 채용 직군(클라우드 인프라 엔지니어)도 이쪽과 가장 가깝다.
- 【추정】 공고 공통분모: **쿠버네티스 + IaC + 보안/멀티테넌트 설계 + LLM 연동**. ML 연구가 아니라 플랫폼·프로덕트 엔지니어.
- 공고 원문: https://www.softbank.jp/recruit/career/positions/detail/004986/ (번호만 바꿔서 확인)

### 2.3 반복해서 나오는 기술 키워드 (자주 나온 순, 【추정: 위 자료 빈도】)
1. Kubernetes / KaaS 2. GPU(GB200, MIG·분할) 3. 멀티 클러스터 배치(OCM·Placement·점수) 4. 추론 API(OpenAI 호환) 5. 자율 운영·멀티 에이전트 6. 소버린·멀티테넌시 7. Prometheus 메트릭 기반 판단 8. 전력 인지(Kepler·전력 예측) 9. OpenShift 10. IaC(Terraform·Ansible) 11. ArgoCD·Kueue 12. SLO/SLI·가드레일

---

## 3. 해커톤 자체의 패턴

| 회차 | 주제 | 출처 |
|---|---|---|
| 2025 예선 | "Make Deployment Delightful: 즐거운 배포 경험" | https://github.com/2025-softbank-hackathon 【사실: 해당 팀 README】 |
| 2025 본선 | "Run Your Functions Instantly over HTTP: **EC2/Compute Engine 위**에서 구현하는 차세대 서버리스 플랫폼" | sh-final-blue README 【사실】 |
| 2026 예선 | "One Action, Infinite Clouds" | 02 문서 【사실】 |
| 2026 본선 | ? | 【미확인】 |

- 【추정】 패턴: **예선 = 배포 플랫폼/경험, 본선 = IaaS VM 위에 매니지드 서비스를 직접 구현.** 2026 본선이 같은 결이라면 "VM 위에 직접 만드는 ○○ 플랫폼"(PaaS/FaaS/추론 서비스/매니지드 K8s) 형태가 유력하고, 회사가 10월에 출시하는 게 정확히 **"GPU 위에 직접 만든 KaaS + 추론 API"** 다.
- 【사실】 공식 대회 주제는 2025·2026 모두 큰 틀이 **"클라우드로 사회 문제를 해결"** (모집 공고: https://linkareer.com/activity/340301 ). 회차별 세부 주제는 킥오프에서 공개.
- 【사실】 2026 예선 다른 팀들(Camellia=우리, Daisy, Hibiscus, Azalea, Freesia, Spillway, PieckPick, Railshot)도 전부 **멀티 환경 배포 플랫폼**. README 공통점: 실측 숫자, 트레이드오프 명시, 심사위원용 데모 모드, 역할 분담. 【추정】 이게 이 대회의 "기본기"로 굳어 있음 → 숫자·트레이드오프만으로는 차별화가 약하고, **회사 방향과의 연결**이 차별점이 된다(홍석 님 조언과 일치).
- 【추정】 2025 우승팀 멤버 중 한 명이 2026 예선에도 다시 참가한 흔적이 있음(팀 레포 연락처 기준). 경험자가 섞여 있다고 보고 준비하는 게 안전.

### 3.1 채용 트랙 (홍석 님이 말한 두 전형)
- 【사실】 해커톤 채용은 "클라우드 인프라 / 클라우드 엔지니어" **특별 포지션**(서류 면제 면접, 일본어는 우대). https://newdept.inha.ac.kr/japan/8242/subview.do
- 【사실】 일본 신졸 일반 루트에 **OPEN 선고(総合コース / エンジニアコース)** 가 있음. 평가: 논리적 사고, 커뮤니케이션, 책임감, 학습력 + 엔지니어는 기술 기초·개발 경험·새 기술 호기심. https://www.softbank.jp/recruit/graduate/recruit/flow/
- 【추정】 홍석 님의 "오픈 엔지니어 트랙" = OPEN 선고 엔지니어 코스. 이쪽은 일본어 면접 비중이 크다는 말과 맞음. Jeong은 일본어가 이미 인정받았으니 **두 트랙 모두 열려도 불리하지 않음**.

---

## 4. 본선 주제 후보 4개

공통 전제 【추정】: 2일 현장 + 약 1주 사전 기간, 팀 클라우드 비용 소액(예선 ₩300,000), 실제 GPU는 쓰기 어렵다 → **CPU로 작은 모델(예: 0.5B~1.5B, llama.cpp)을 돌리거나 GPU를 "자원 단위"로 흉내** 내는 게 현실적.

### 후보 A. 미니 Infrinia: 멀티테넌트 "모델 고르면 API가 나오는" 추론 서버리스 플랫폼 【가능성: 가장 높음】

**한 줄**: 테넌트가 콘솔에서 모델을 고르면 OpenAI 호환 엔드포인트와 API 키가 나오고, 요청이 없으면 0으로 줄고 몰리면 늘어나며, 테넌트끼리 자원·네트워크가 격리되고 토큰 단위로 과금된다.

- **왜 소프트뱅크 방향인가**
  - 【사실】 10월 출시하는 GPU 클라우드의 두 기능(KaaS, Inf-aaS) 그 자체. SB Neo로 해외 판매까지 하는 회사 핵심 사업.
  - 【사실】 KaaS 공고(004986)의 업무가 "멀티테넌시·네트워크·스토리지·보안".
  - 【추정】 작년 본선(서버리스 함수 플랫폼)의 2026년판. "VM 위에 직접 만든다"는 본선 패턴과 정확히 겹침.
- **심사위원이 볼 각도** 【추정】
  - 격리: "옆 테넌트가 폭주하면 내 지연은?" (noisy neighbor)
  - 콜드스타트: "0에서 첫 응답까지 몇 초? 모델 로딩을 어떻게 줄였나?"
  - 과금·쿼터: "토큰을 어디서 세나? 쿼터 초과 시 동작은?"
  - 왜 Namespace 격리인가 vs 클러스터/VM per tenant (Infrinia는 둘 다 함)
- **2일 MVP 범위** 【추정】
  - kind(또는 VM 위 k3s) 1개, 테넌트 = Namespace + `ResourceQuota` + `NetworkPolicy`
  - 모델 서버: llama.cpp server(OpenAI 호환 `/v1/chat/completions`) + 작은 GGUF 모델 1~2종
  - 게이트웨이(Spring Boot 가능): API 키 → 테넌트 식별 → 레이트 리밋 → 라우팅 → 토큰 수 Prometheus 기록
  - 스케일: KEDA(요청 수/대기열 기반) 0↔N
  - 콘솔: 모델 선택 → 엔드포인트·키 발급 → 사용량 그래프(Grafana 임베드)
  - 측정: 콜드스타트 시간, p95 지연, tokens/s, 노이지 네이버 실험 전후 p95
- **Jeong이 설명할 수 있어야 할 것**
  - 테넌트 격리 4계층(계산·네트워크·데이터·ID)과 각 계층에서 고른 수단, 버린 대안
  - 서버리스 콜드스타트의 원인(이미지 pull, 모델 로딩, 컨테이너 기동)과 줄이는 방법(모델 캐시, 최소 1 레플리카, 사전 pull)
  - Prefill/Decode, KV 캐시 인지 라우팅이 왜 필요한지(03 문서) — 구현은 안 해도 "다음 단계"로 말할 수 있게
  - 과금 단위로 토큰을 고른 이유 vs 시간·요청 수
- **기존 실습과의 연결**: Lab 03(requests/limits, QoS), Lab 04(HPA), Lab 05(taint·PriorityClass·선점) → 바로 이어짐

### 후보 B. 점수 기반 멀티 클러스터 배치 + 자동 페일오버 (미니 AITRAS/DSF) 【가능성: 높음】

**한 줄**: 여러 클러스터(클라우드 + 온프레 역할)의 실시간 메트릭으로 점수를 매겨 워크로드를 가장 좋은 곳에 두고, 점수가 떨어지거나 클러스터가 죽으면 자동으로 옮긴다.

- **왜 소프트뱅크 방향인가**
  - 【사실】 소프트뱅크가 OCM에 기여한 DSF를 7월 KubeCon Japan에서 직접 발표. 회사가 "밖에 보여주고 싶은 기술"로 고른 주제.
  - 【사실】 오케스트레이터의 대표 유스케이스가 LLM 추론 엔드포인트 배치 → A와 합칠 수 있음.
  - 【사실】 예선 주제(Infinite Clouds)의 자연스러운 다음 단계, 우리 팀 예선의 "배포 대상 추천"(P2로 미뤘던 것)과 직결 (02 문서).
- **심사위원이 볼 각도** 【추정】
  - "점수 지표·가중치를 왜 그렇게? 데이터는 얼마나 신선해야?"
  - "평가 로직은 중앙? 클러스터마다?" (DSF 설계 문서의 트레이드오프 그대로)
  - "배치(어느 클러스터)와 라우팅(어느 인스턴스)을 어디서 나눴나?"
  - "상태 있는 워크로드는?"
- **2일 MVP 범위** 【추정】
  - kind 3개(hub + 2 managed) + OCM, 각 클러스터 Prometheus
  - Scorer API(Spring Boot 또는 FastAPI): 지연·남은 CPU·비용(가짜 단가) → 점수 → `AddOnPlacementScore`
  - `Placement`가 점수 상위 1개 선택 → `ManifestWork`로 배포
  - 장애 주입(클러스터 노드 정지 또는 부하) → 재배치까지 시간 측정, 사용자는 고정 URL로 계속 접속
  - 측정: 재배치 시간(감지·결정·배포 분해), 점수 계산 주기 vs 반응 속도
- **Jeong이 설명할 수 있어야 할 것**: OCM 리소스 4종의 역할, 점수 함수 설계 근거, 페일오버 시간 분해, Karmada/ArgoCD ApplicationSet 대신 OCM을 고른 이유
- **기존 계획과의 연결**: 10/18 게이트(배치+페일오버 데모)와 같은 목표. 그대로 진행.

### 후보 C. 자율 운영 에이전트: 감지 → 원인 → 가드레일 안 자동 복구 【가능성: 중간, 단 어느 주제든 "AI 활용 10점"으로 붙일 수 있음】

**한 줄**: 장애가 나면 에이전트가 메트릭·로그를 읽고 원인을 좁혀 조치안을 내고, 허용된 조치는 자동 실행, 위험한 조치는 사람 승인 후 실행. 모든 판단은 감사 로그로 남긴다.

- **왜 소프트뱅크 방향인가**
  - 【사실】 LTM 멀티 에이전트가 "감지 → 원인 → 수정안 → 실행 → 조율"을 기지국 업무에서 검증 중. 다음 영역이 장애 대응.
  - 【사실】 자율 네트워크 Level 3 인증, 다음 목표 Level 4. "AI-Ready Modernization"(AI가 안전하게 바꿀 수 있는 시스템). SRO 공고의 "LLM·에이전트 모니터링".
- **심사위원이 볼 각도** 【추정】
  - "AI가 틀리면?" → 실행 권한 경계, 드라이런, 롤백, 승인 단계
  - "규칙 기반 대비 무엇이 나아졌나?" → MTTD/MTTR 숫자
  - "LLM 호출 비용 대비 효과는?"
- **2일 MVP 범위** 【추정】
  - Lab 06 스택(Prometheus·Loki·Alloy) 그대로 + 장애 시나리오 3개(OOM, 잘못된 설정 배포, 트래픽 급증)
  - 에이전트: 읽기 도구(PromQL·로그 조회·`kubectl get/describe`)는 자유, 쓰기 도구는 화이트리스트(롤백·스케일·재시작)만, 그 외는 승인 요청
  - 대시보드: 장애 타임라인 + 에이전트 판단 근거 + 승인 버튼
  - 측정: 시나리오별 MTTD·MTTR, 원인 적중률(규칙만 vs 규칙+LLM)
- **Jeong이 설명할 수 있어야 할 것**: 자율 레벨(L0~L5) 개념, 권한 경계 설계(예선 D-05·D-06 "AI는 판단, 실행은 검증된 경로" 원칙 재사용), SLO·에러 버짓

### 후보 D. 소버린 AI 게이트웨이: 민감도 기반 정책 라우터 【가능성: 중간~낮음 (단독 주제로는), A나 C의 한 기능으로는 높음】

**한 줄**: 요청의 민감도(개인정보·사내 기밀)를 판정해, 민감하면 국내/온프레 모델로, 아니면 외부 API로 보내고, 키·감사 로그·데이터 위치를 통제한다.

- **왜 소프트뱅크 방향인가**
  - 【사실】 오늘(10/6) 단바 집행임원 메시지의 "저민감 = 해외 클라우드, 고민감 = 소버린"과 정확히 같은 구조.
  - 【사실】 Sarashina3 guard 모델, Oracle 소버린 클라우드, 소버린 AI 인프라 엔지니어 공고(004963), 차세대 클라우드 프로덕트 공고의 IAM·KMS.
- **심사위원이 볼 각도** 【추정】: "민감도 판정을 틀리면?(오탐·미탐 비용 비대칭)", "키 관리는 누가?", "감사 로그는 위변조 방지되나?"
- **2일 MVP 범위** 【추정】: 게이트웨이(규칙 + 작은 분류 모델), 백엔드 2개(로컬 llama.cpp = "국내", 외부 API = "해외"), PII 마스킹, 감사 로그, 정책 YAML. 측정: 판정 정확도, 추가 지연.
- **Jeong이 설명할 수 있어야 할 것**: 소버린의 세 요소(데이터·기술·운영), 미탐/오탐 중 무엇을 줄이게 설계했는지
- 【추정】 A의 게이트웨이에 "정책 라우팅" 한 기능으로 얹으면 **A + D가 회사 메시지를 가장 넓게 덮는 조합**.

### 4.1 후보 비교

| | A 추론 플랫폼 | B 멀티 클러스터 배치 | C 자율 운영 | D 소버린 라우터 |
|---|---|---|---|---|
| 회사 방향 직결도 | ◎ 10월 출시 상품 | ◎ KubeCon 발표 기술 | ○ LTM·L4 | ○ 오늘 나온 메시지 |
| 해커톤 패턴(본선=IaaS 위 매니지드 구현) | ◎ | ○ | △ | △ |
| 예선과의 연속성 | ○ | ◎ | ○ | △ |
| 2일 MVP 난이도 | 중 | 중상 (OCM) | 중 | 하 |
| 데모 직관성 | ◎ 모델 고르면 API | ○ 그래프로 이동 | ◎ 장애→복구 타임라인 | ○ |
| Jeong 현재 실습과 거리 | 가까움 (Lab 03~05) | 중간 (OCM 신규) | 가까움 (Lab 06) | 가까움 |

【추정】 실제 본선 주제가 무엇이든 위 4개 중 하나 또는 조합에 걸릴 확률이 높다. 특히 **A를 바닥으로, B(어디에 둘지)·C(어떻게 지킬지)·D(누가 어디로)를 기능으로 얹는 구조**가 설명이 가장 깔끔하다.

---

## 5. 발표·설계 문서에 쓸 회사 언어 【추정】

- 첫 문단에 회사 문장을 그대로 인용하고 우리 설계와 연결: 예) "소프트뱅크는 계산자원을 **차세대 사회 인프라**로 보고, GPU 클라우드를 KaaS와 Inf-aaS로 제공한다. 우리는 그 축소판을 ○○ 제약 아래에서 만들었다."
- 일본어 키워드: 次世代社会インフラ / ソブリンAI / テレコAIクラウド(Telco AI Cloud) / Inference as a Service / マルチテナント / スコアリング / 自律ネットワーク / Customer Zero
- 기술 하나를 깊게: "Namespace 멀티테넌시 vs 테넌트별 클러스터", "vLLM vs llama.cpp(CPU)", "OCM vs Karmada" 같은 비교 1개를 숫자와 함께.
- 【사용자】 홍석 님: 설계 문서가 평가 비중이 크고 중간 점검·최종 발표의 기준점 → **설계 문서 템플릿을 지금 만들어 두고 실습마다 채우기**(8절 셀프 연습).

## 6. 협업·태도 (홍석 님 조언을 행동으로) 【추정】

- 본선 준비 기간(킥오프~현장): 팀 채널에 **매일 짧은 진행 공유 + 자료 링크**, 대면 미팅 적극 제안. 이 프로젝트에서 만든 조사 문서(01~07)가 그대로 "공유 자료"가 된다.
- 현장: 소프트뱅크 엔지니어·인사 담당자와 대화할 **질문 3개를 미리 준비**. 예) "GPU 클라우드 Inf-aaS의 테넌트 격리는 어느 계층까지 하나요?", "DSF 점수에서 전력 예측은 실제로 얼마나 쓰이나요?", "LTM 에이전트의 실행 권한은 어디까지 열어 두나요?" → 회사 연구를 읽었다는 걸 자연스럽게 보여 줌.
- 캐주얼 면접 대비: "왜 소프트뱅크인가"에 **1~4절 사실 2개 + 내 실습 숫자 1개**로 30초 답변을 한국어·일본어로.

## 7. 공부 방향: 리셋 말고 우선순위 조정 【추정】

- 유지: 1주차(쿠버네티스 기본·관측·부하 테스트)는 네 후보 모두의 바닥. 그대로 끝낸다.
- 2주차부터 앞당길 것 (네 후보에 공통으로 걸리는 순)
  1. **멀티테넌시**: Namespace + ResourceQuota + NetworkPolicy + RBAC, 노이지 네이버 실험 (A, D)
  2. **CPU LLM 서빙 + 메트릭 기반 0↔N 스케일**: llama.cpp OpenAI 호환 서버 + KEDA, 콜드스타트 측정 (A)
  3. **OCM 멀티 클러스터 + 점수 배치 + 페일오버**: 10/18 게이트 그대로 (B)
  4. **관측 + 자동 조치 에이전트**: Lab 06 위에 읽기/쓰기 도구 분리한 에이전트 (C)
- 줄일 것: 무선(RAN·HAPS), Slurm·InfiniBand 같은 HPC 네트워크는 개념 한 줄만.
- 매 실습 README 끝에 **"소프트뱅크 연결" 한 문단**(어떤 공고·발표와 연결되는지)을 추가.
- STATUS.md·로드맵(05) 반영은 Jeong 확인 후 (TODO(human) 아래).

---

## 핵심 결정 3개 (+대안)

1. **주제 후보 1순위를 A(멀티테넌트 추론 플랫폼)로 둠**
   - 대안: B를 1순위로(예선 연속성, 기존 10/18 게이트와 일치)
   - 이유: 회사의 10월 출시 상품 + 본선 패턴(IaaS 위 매니지드 구현) 두 축에 동시에 맞음. B는 A 위의 "배치 기능"으로 흡수 가능.
2. **공부 방향은 리셋하지 않고 2주차 우선순위만 조정**
   - 대안: 남은 기간을 A 하나에 올인
   - 이유: 주제가 미공개라 한 곳에 올인하면 빗나갈 때 손실이 큼. 4개 공통 기반(멀티테넌시·스케일·멀티 클러스터·관측)은 어느 주제에도 재사용됨.
3. **실습 결과마다 "회사 연결" 문단을 붙임**
   - 대안: 본선 직전에 한 번에 정리
   - 이유: 홍석 님 조언의 핵심이 "지향점과의 연결". 사후 정리하면 숫자·근거가 빠짐.

**TODO(human)**
- 1순위를 A로 둘지 B로 둘지 결정 (위 결정 1)
- 7절 우선순위를 STATUS.md·로드맵 05에 반영할지 결정

## 셀프 연습 1개

후보 A를 골랐다고 치고, 설계 문서 **첫 문단 3문장**을 써 보기: ① 회사 문장 인용(1절에서 하나), ② 우리가 만든 것, ③ 가장 중요한 트레이드오프 하나(예: Namespace 격리 vs 테넌트별 클러스터). 한국어로 쓰고, 되면 일본어로도.

## 검증 명령과 기대 출력

```bash
# 1) 이 문서가 main에 있는지
git log --oneline -1 -- notes/research/07-softbank-direction-finals-topics.md
# 기대: 커밋 한 줄 (해시 + "Research 07 ...")

# 2) 핵심 출처가 살아 있는지 (브라우저로 열어도 됨)
curl -s -o /dev/null -w "%{http_code}\n" https://www.softbank.jp/corp/news/press/sbkk/2026/20260525_01/
# 기대: 200

# 3) GPU 클라우드 정식 출시(GA) 보도가 나왔는지 주 1회 확인
#    https://www.softbank.jp/corp/news/press/sbkk/2026/ 목록에서 "GPUクラウド" 검색
# 기대: 10월 중 상용 출시 보도자료 (나오면 1.2절 갱신)
```

---

## 확인 못 한 것
- 【미확인】 GPU 클라우드 GA 보도, 외부 고객, 가격
- 【미확인】 KubeCon Japan 2026 DSF 발표 슬라이드·영상
- 【미확인】 사카이·도마코마이 실제 가동일
- 【미확인】 2025 본선 다른 팀 레포, 공식 수상 목록, 본선 배점, 참가자 회고 글(한·일·영 검색 모두 없음)
- 【미확인】 topics 번호 231 이후: 조사 결과가 엇갈림(231=방재, 232=HAPS 레이저 측거로 나온 조사와 231 이후 404로 나온 조사). 목록 페이지가 JS 렌더링이라 직접 확인 못 함.
- 【미확인】 소프트뱅크 명의 llm-d 기여, 회사 기술 블로그(Qiita/Zenn) 계정

## 출처 (본문 외 추가)
- 신년사 2026: https://www.softbank.jp/corp/news/press/sbkk/2026/20260101_01/
- 중기계획 보도: https://k-tai.watch.impress.co.jp/docs/news/2107720.html , https://k-tai.watch.impress.co.jp/docs/news/2084734.html
- R&D topics 224~230: https://www.softbank.jp/en/corp/technology/research/topics/224/ (번호만 바꿔서)
- Red Hat × SoftBank Kepler: https://www.redhat.com/en/about/press-releases/red-hat-and-softbank-corp-implement-ai-ran-optimize-network-performance-and-sustainability
- Red Hat Developer DSF 해설: https://developers.redhat.com/articles/2026/03/09/smarter-multi-cluster-scheduling-dynamic-scoring-framework
- Ericsson 피지컬 AI 시연: https://www.ericsson.com/en/press-releases/2026/2/softbank-corp-and-ericsson-demonstrate-network-enabled-physical-ai-with-ai-ran
- 2026 모집 공고: https://linkareer.com/activity/340301 , https://www.contestkorea.com/sub/view.php?Txt_gbn=1&Txt_bcode=030310001&str_no=202608180036
- 2025 모집 공고: https://linkareer.com/activity/273708
- 신졸 선고 흐름: https://www.softbank.jp/recruit/graduate/recruit/flow/
- 2025 본선 우승팀: https://github.com/sh-final-blue
