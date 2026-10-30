로드맵 위치: 본선 D-8 (10/31 KST 새벽 기준) / 본선 킥오프 이후 현황 인수인계 / Claude Code CLI 세션이 바로 이어받기

# 본선 상황 handoff (2026-10-30 킥오프 직후)

> 이 파일 하나만 읽으면 CLI 세션이 지금까지의 맥락을 잡고 바로 일할 수 있게 정리했다.
> 작성: 2026-10-31 02:20 KST, **갱신 02:50 KST**: Notion 회의록 2개(「10/30 Meeting」, 「10/30 Meeting - 2」) 반영 (클라우드 프로젝트 스레드 "본선 상황 handoff 문서 만들기").
> 표기: 【사실】(출처) / 【추정】 / 【미확인】 / 【사용자】(Jeong이 말한 것).
> 맨 아래 §9에 CLI에서 바로 붙여 넣을 첫 프롬프트가 있다.

---

## 0. 30초 요약

- 【사실: notes/research/10】 본선 주제는 **"Beyond Lock-In: Frictionless Cloud Management Across Platforms"**. 예선 배포 시스템을 멀티 클라우드 관리 플랫폼으로 키우고, 핵심은 **클라우드·온프레 사이 무중단 이전**.
- 【사실: 10 §1】 데모 필수 3장면: ① 클라우드 간 라이브 이전 ② 멀티 환경 보안·거버넌스 시각화 ③ AI 에이전트가 샌드박스에서 점검·수정. 배점 30/30/10/10/20. Day1(11/7) 중간 7분, Day2(11/8) 최종 5분, 슬라이드 금지.
- 【사실】 팀 **Iron** 5명 확정(이정·박승준·박소정·강윤주·오채건). 1차 회의 10/30 21:00~21:48, 이어서 Slack 허들 2차 대화(「10/30 Meeting - 2」). 정기 회의 **매일 22:00**(회의록 표기 "10시"), 다음 회의 **10/31(토) 22:00**.
- 【사실: 10/30 Meeting - 2 §4】 **특화 테마 = 보안, 전원 동의.** 오채건 아이디어 = 이전 과정을 단계별로 도식화 → 단계별 취약점 → **가드레일 프레임워크**(자동 차단 / 판단 필요한 건 경고만) + 실시간 관제 대시보드.
- 【사실: Meeting - 2 §5】 **역할 잠정 배분**(10/31 확정): 이정 = API·오케스트레이터·IR·어댑터 / 강윤주 = 이전·롤백 핸들러·Argo Rollouts·Terraform / 박소정 = Terraform·CI/CD / 오채건 = 온프레 전환 + 보안 전반 / 박승준 = 프론트 + AI 에이전트 지원.
- 【사실: Meeting - 2 §6】 **팀 일정**: 10/31까지 설계 확정 → 11/1(일) 개발 시작 → 11/6(금) 서비스 완성 → 11/7~8 발표.
- 【사실: decisions/2026-10-30.md】 아키텍처는 Jeong 쪽에서 v0.3-k8s까지 그렸고 큰 결정 대부분을 Jeong이 확정. 허들에서 팀이 초안을 봤지만 **확장 베이스·데모 경로·DB 이전·시크릿 저장소는 미정**. 그리고 허들 회의록의 "온프레 ↔ AWS 우선, GCP는 여유 시"가 기존 가정(AWS → GCP)과 **어긋난다** (§5).
- 【사실】 요구사항 명세 v3가 레포·Google Doc·Notion **3곳**에 있다. 어느 쪽이 원본인지 Jeong이 아직 안 정했다.
- 【사실】 팀 GitHub 조직(Softbank-Hackathon-Team)의 Service 레포에 이슈/PR 템플릿을 올리려다 **403**(Claude GitHub 앱 미설치). CLI는 Jeong 본인 git 권한으로 푸시할 수 있으니 여기서 풀린다.

---

## 1. 일정·마감

| 날짜 (KST) | 내용 | 상태 |
|---|---|---|
| 10/30(금) 20:00~21:00 | 공식 킥오프 (Google Meet) | 【사실】 완료 |
| 10/30(금) 21:00~21:48 | 1차 팀 회의 | 【사실】 완료. 회의록 = Notion 「10/30 Meeting」 |
| 10/30(금) 밤 | Slack 허들 (팀원 파악·주최 정보·아키텍처 초안·**보안 특화 결정**·잠정 역할) | 【사실】 완료. 회의록 = Notion 「10/30 Meeting - 2」 |
| **10/31(토) 19~20시** | 전원: 브레인스토밍·담당 영역 리서치를 Notion 개인 페이지에 업로드 | 【사실: 1차 회의 §12】 |
| **10/31(토) 22:00** | 2차 회의: **역할 확정**, 설계 확정 (특화 테마는 이미 보안으로 정함) | 【사실】 |
| **11/1(일)** | 개발 시작 (가능하면) | 【사실: Meeting - 2 §6】 |
| 11/3(화)까지 | 박소정 졸업작품 발표로 바쁨, 이후 풀가동 | 【사실: Meeting - 2 §1】 |
| **11/6(금)** | 서비스 완성 목표 | 【사실: Meeting - 2 §6】 |
| 11/6(금) 18:00~22:00 | Jeong 사회 일정으로 불가 | 【사용자】. 허들 회의록엔 "이정: 목요일 외 전부 가능"이라 적혀 있어 요일 【미확인】 |

- 예전 일정안 B(11/1 범위 동결, 11/5 데모 동결)는 위 팀 일정으로 대체됐다고 본다 【추정】.
| **11/7(토) 10:00** | 코드·설계 문서·발표 자료 링크 제출 (Slack 팀 채널 @mentors) | 【사실: 10, p28-29】 |
| 11/7(토) | Day1 중간 보고 7분 (설계 문서 + 아키텍처 그림) | 【사실】 |
| **11/8(일) 13:00** | 발표 언어 + Notion 토크 스크립트 제출 | 【사실】 |
| 11/8(일) | Day2 최종 발표 5분, 슬라이드 금지 | 【사실】 |

- 장소: 라마다 동대문 B1 【사실】. 현장 개발 시간 약 7.5h(Day1 10:30~14:00, Day2 10:00~14:00) 【사실: p51】.
- 지원금 ₩500,000/팀. 일본어판은 "인프라 + AI 요금", 한국어판은 "인프라 사용료"라 AI 포함 여부는 【미확인】(Q6).

---

## 2. 팀 Iron

| 이름 | 배경 (요약) | 잠정 역할 (Meeting - 2 §5, 10/31 확정 예정) |
|---|---|---|
| 이정 (Jeong, GitHub `Pionia5375`) | 컴공 3학년, 서울 예선(camellia). 예선 담당 = 백엔드 API + IR → 어댑터. 예선 후 KCNA·SAA 취득. 진행·Notion·GitHub 관리(전원 동의). 피드백: 말 속도 줄이기 | **API 서버·오케스트레이터·IR·어댑터** (백엔드 골격) |
| 강윤주 | 정보통신 졸업, KT Cloud 인프라 부트캠프. 부산 예선 Terraform 담당. Argo CD·블루그린·Rollouts 경험, 카나리는 개념만. AWS 위주. Claude Pro만 있음. 자신감 낮지만 이정은 충분히 맡길 수 있다고 봄 | **이전·롤백 핸들러, Argo Rollouts·카나리(p95 등 SRE 지표 롤백), Terraform** |
| 박소정 | 숭실대 전자과 4학년. k8s 위주 + AWS 공부, 졸작은 연구실 서버 온프레. 예선 담당 = CI/CD 인프라·Terraform. **11/3(화)까지 졸작으로 바쁨** | **Terraform·CI/CD** (강윤주와 함께) |
| 오채건 | 웹 보안 → 블록체인 보안 → 시스템 → AI 보안. CTF 출제 때 k8s로 학생별 인스턴스 운영. 예선 Notion 담당. 예선 시스템(모듈 + 오케스트레이터, JSON 스키마, 모듈별 정책 게이트)이 확장 베이스 후보 | **온프레 전환 + 보안 전반** (클라우드 보안 서비스의 온프레 구현, 에이전트 샌드박스 격리, 시크릿) |
| 박승준 | KAIST, AI·LLM·KV 캐시 연구. 개발은 Swift 앱(프론트) 위주, 인프라 경험 적음. 회의 2~3시간 전 문서 업로드 원함 | **프론트 + AI 에이전트 지원** (10/31 확정) |

- 팀원 전원이 처음엔 "남는 거" 하겠다고 해서, 이정이 영역을 제안하는 방식으로 잠정 배분했다 【사실: Meeting - 2 §1】.
- 우리 팀은 현직자 비중이 높은 다른 팀보다 경험이 적고, 시간으로 메운다는 인식 【사실: Meeting - 2 §2】.
- SoftBank 김택근 님이 회의에 잠깐 참관. **해커톤 끝날 때까지 개인 연락 금지** 【사용자】.

---

## 3. 어디에 무엇이 있나 (원본 위치)

### 레포 (이 레포, main 직푸시, PR 없음)

| 파일 | 내용 |
|---|---|
| `notes/research/10-finals-kickoff-brief.md` | 킥오프 PDF 70쪽 분석, 모든 항목 쪽수 병기 |
| `notes/research/11-finals-requirements.md` | **요구사항 명세 v3** (OUT/FR/NFR/CON/Q/WP). ID는 결정 로그가 참조하니 **번호 바꾸지 말 것** |
| `notes/research/12-prelim-repos-architecture.md` | 예선 7팀 레포 조사 (camellia만 환경 간 트래픽 전환 있음, 상태 있는 이전은 아무도 안 함) |
| `notes/research/13-kyverno-in-architecture.md` / `14-security-services-mapping.md` | 정책·보안 서비스 매핑 |
| `notes/research/15-fastify-zod-pgboss.md` | 컨트롤 플레인 스택 비교 (결정 3개 TODO(human)) |
| `decisions/2026-10-30.md` | 오늘 결정 전부 (선택/대안/이유/측정값/심사 항목) + "가정 (팀 확정 대기)" |
| `notes/architecture/finals-architecture-v0.3-k8s.html`, `arch-v0.3-k8s.svg` | 최신 아키텍처 그림 (SVG는 Notion 업로드용) |
| `notes/guide/finals-architecture-guide.md` + `img/` | 팀 공유용 아키텍처 가이드 Markdown 사본 |
| `starter-pack/` | 킥오프 전 준비물 (schedule, meeting-01-agenda, github 전략, notion 설계, infra-prep 드릴) |
| `poc/01~07` | 10월 PoC (Argo CD, Rollouts, 테넌트 격리, FaaS, 컨트롤 플레인+MCP, 장애 주입, EC2 k3s) |
| `STATUS.md` | ⚠️ **10/20에서 멈춰 있음**. 본선 체제로 다시 써야 함 (§7) |

### 레포 밖

| 이름 | 위치 | 메모 |
|---|---|---|
| 팀 Notion (공식 팀 페이지) | https://app.notion.com/p/SoftBank-Hackathon-2026-Team-Iron-4098bee9ada4810a9e74ffbe9bc84fca | 1차 회의에서 팀 페이지로 확정 |
| Notion "요구사항 명세" | https://app.notion.com/p/4077a82c52e2806eb4dada461b3ebfad | v3 전문, 표를 항목 블록으로 풀어 씀 |
| Jeong의 이전 Notion 초안 | https://app.notion.com/p/3867a82c52e280c68e3fd6148d6cf0cb | 구조 참고용. Notion 페이지·속성은 **묻지 않고 추가 금지** 【사용자】 |
| Google Doc "킥오프 자료 분석" | https://docs.google.com/document/d/1-5eYxFLZIEuPxv8F2Xpx4NGOcoKivKFwDJPCVFEwzDY/edit | 탭: t.0 요구사항 명세 / t.pvbzmrm8llr 킥오프 분석 / t.xmbi7tzeu9n0 15. 컨트롤 플레인 스택 |
| 아키텍처 v0.3-k8s 아티팩트 | https://claude.ai/artifact/7YKb66BRg16akXJ3m1WLgV | |
| 팀 공유용 아키텍처 가이드 (Claude Doc, 편집 원본) | https://claude.ai/artifact/FHQx1MRPzK4Mgzru8s3mez | 팀원 공유를 켜야 열림 【추정】 |
| 아키텍처 v0.1 (k8s 없는 안) | https://claude.ai/artifact/AcnpuBvv2GXSQc8oK7uN2W | 버린 대안 설명용 |
| 팀 GitHub 조직 | https://github.com/Softbank-Hackathon-Team | Service 레포 = main에 README만 【사실, 10/30】 |
| 이슈/PR 템플릿 정갈본 + patch | 클라우드 프로젝트 파일 `github-templates/.github/`, `github-templates/service-templates.patch` | **CLI에서는 이 경로가 안 보인다.** claude.ai 프로젝트 Library에서 내려받아야 함 (§6) |

---

## 3.5 허들에서 나온 주최·대회 정보 (Meeting - 2 §2)

- 【사용자→팀 공유】 이번 주제는 **SoftBank 사내에서도 실제 도입을 검토 중**이라고 킥오프에서 언급됐다 → 출제 의도에 맞추기
- 부산 예선 때 SoftBank 측이 **보안을 중요시**했다 (강윤주). 요구사항 키워드 대부분이 안정성·보안·거버넌스(IAM, 시크릿, 데이터 이전, 롤백)
- 주최는 **넓게 말고 하나 특화**를 원함. 최종 발표 **데모 필수** 【추정】
- 예전에 문의했을 때 **리소스 사전 캐싱 OK, 결과만 보여 줘도 된다**는 답을 받았다 → 데모 시간 압박(이전 ≤ 90초)을 줄일 근거. 본선에도 같은지 【미확인】
- 업계 흐름: AI 에이전트가 샌드박스에서 코드 작성·테스트 후 배포 (Datadog 컨퍼런스 데모 예) → 주제와 일치
- 예선 비교: 서울은 대부분 퍼블릭 + 온프레 둘 다 구현, 원클릭 배포 UX가 좋았던 팀이 있음. 부산은 8팀 중 6팀이 로컬 배포
- QA 때 물을 것: 참가자 번호가 순위인지

---

## 4. 확정된 결정 (decisions/2026-10-30.md 요약)

"Jeong 확정"은 Jeong이 고른 것이고, 허들에서 팀이 초안을 봤지만 팀 전체가 항목별로 투표한 건 아니다. **⚠️ 표시는 허들 회의록과 어긋나거나 팀이 "미정"이라고 적은 것**이다.

| # | 결정 | 확정 수준 |
|---|---|---|
| 0 | **특화 테마 = 보안** (가드레일 프레임워크 + 관제 대시보드 방향) | **팀 확정** (Meeting - 2 §4, 전원 동의) |
| 1 | **운영 모델 = 관리형 멀티 테넌트 플랫폼**. 모든 테이블 `tenant_id` + Postgres RLS, 테넌트별 Argo CD AppProject | Jeong 확정 (FR-BASE-09) |
| 2 | **고객 연결 = 원클릭 템플릿**: AWS CloudFormation 빠른 생성 / GCP Cloud Shell 스크립트 / 온프레 Agent 한 줄. 고객 키를 보관하지 않고 역할(observe·operate) 위임, 테넌트별 ExternalId | Jeong 확정, 1차 회의에서 강윤주 납득, 허들에서 External ID 없으면 거부까지 설명 (FR-BASE-08) |
| 3 | **가져오기(import)**: observe 역할 → 벤더 인벤토리(Resource Explorer/Config, Cloud Asset Inventory) → 빈 칸만 describe → 공통 명세(IR) 초안 → AI는 확신 낮은 칸 표시만 → 사람 확인. 범위 = 컨테이너 서비스 + k8s | Jeong 확정 (FR-MIG-10) |
| 4 | **실환경 = AWS · GCP · 온프레(노트북 VM k3s)**. Azure는 어댑터 코드 + Mock(녹화 응답 계약 테스트)만, 화면에 "Mock" 표시, 데모 경로 아님 | Jeong 확정 10/30 19:45 (18:02 "3사 대칭"을 수정) |
| 5 | **온프레 FR-ONP 6개 전부 MUST**: IAM = k8s RBAC / 시크릿 = ESO + Vault / 감사 = k8s audit log / 모니터링 / 백업 등 | Jeong 확정. ⚠️ 허들 회의록은 "시크릿 저장소 Vault 고려, **미정**". 온프레 구현은 오채건 담당 |
| 6 | **환경 어댑터 = 우리 코드(번역기)**: 공통 명세 → ① Terraform 입력값(클라우드 층) ② Helm values(k8s 층) | Jeong 확정. 허들 설명: 클러스터 내부는 Helm/**Velero**, IR 재생성 시 캐시로 변경분만 적용, 코드베이스 규칙 기반 1차 필터(yaml·toml·Dockerfile·매니페스트) |
| 7 | **k8s 사용**: 플랫폼 계정에 관리 EKS + vCluster 샌드박스 + Argo CD 허브. 이유는 vCluster와 Argo CD뿐(web·api·worker는 컨테이너면 충분) | Jeong 확정, 팀 반대 없음. 온프레 노트북 부하 우려 남음 |
| 8 | **작업 큐 = Postgres(pg-boss)** + 교체 가능 인터페이스. tfstate = S3 `use_lockfile` | Jeong 확정. 스택 세부(Fastify/Zod)는 §5-6 |
| 9 | **트래픽 전환 = Cloudflare Load Balancing 가중치** 10→50→100 | Jeong 확정 10/30 19:22. ⚠️ 허들 회의록엔 Cloudflare 언급 없이 "롤백: Argo Rollouts"로 적힘 → 역할 구분(클러스터 안 카나리 = Rollouts, 환경 간 전환 = Cloudflare)을 팀에 설명 필요 |
| 10 | **자동 롤백** = 도착 쪽 5xx > 1% 또는 p95 > 출발 p95의 2배가 30초 지속. DB 복제 lag는 롤백 기준이 아니라 **컷오버 전 관문** | Jeong 확정. ⚠️ 허들: "추가 롤백 기준 고민 필요"로 미정 목록에 있음 (강윤주 담당) |
| 11 | **보안 서비스**: 데모 경로 2곳만 실제로 켬(AWS GuardDuty 30일 체험, GCP SCC 무료 등급). Azure Mock·온프레는 Prowler/Kyverno/Trivy/kube-bench 결과를 같은 스키마로. Falco는 EXTRA | Jeong 확정 |
| 12 | **AI 에이전트 = 자체 도구 루프**: 좁은 도구 4~5개(vCluster 안 kubectl, GitOps 레포 읽기·수정, kyverno test, PR 생성). 프로덕션 도구 없음, 모든 호출은 오케스트레이터 경유 | Jeong 확정 (FR-AGT-07·09) |
| 13 | **샌드박스 단계**: k8s 층 vCluster(MUST) → 클라우드 층 plan·정적 점검(MUST) → 도착 클라우드 전체 재현(EXTRA) | Jeong 확정 |

---

## 5. 열린 결정 (누가 언제 정하나)

| # | 질문 | 현재 안 | 정할 곳 |
|---|---|---|---|
| ~~Q16~~ | ~~특화 테마~~ | **보안으로 결정** (Meeting - 2 §4). 남은 일: 특화 포인트 고르기. 후보 = 온프레 이전 시 IAM·시크릿 구현 / 데이터 이전 / AI 샌드박스 격리 / 테넌트 격리 / 네트워크 정책. 오채건 안 = 이전 1~4단계별 취약점 → 가드레일(예: 클라우드가 폴백으로 `0.0.0.0` 개방 → 지정 경로만), 컨테이너 탈출 대응(user namespace UID 매핑, gVisor). 커널 풀체인은 시나리오당 1주라 제외, 네트워크 위주 | 10/31 회의 |
| Q-보안 | **보안 특화를 명세에 어떻게 반영하나** | 명세 11 §11.1 결정 1(D1 이전 + D2 보안)의 무게를 보안 쪽으로 옮기고 "가드레일 프레임워크"를 새 FR로 넣을지. ID는 바꾸지 말고 새 번호 추가 | Jeong (명세 갱신) |
| Q1 | **확장 베이스**: 누구 예선 시스템을 키우나 | 1차 회의에서 Jeong이 **오채건 시스템** 제안. 허들에선 Jeong 아키텍처 초안(Fastify+Zod+IR+어댑터)을 기준으로 이야기함. 가이드 §13은 camellia 설계 추천 → 정리 필요 | 10/31 22:00 회의 |
| Q-역할 | **역할 확정** | 잠정안은 §2 표. 박승준만 "내일 확정"으로 남음 | 10/31 회의 |
| Q17 | **이전 범위**: 같은 클라우드 안 빠른 이전 vs 어느 환경이든 깨지지 않는 이전 (DB 호환) | 허들: "이전 과정은 빨리 구현하고 보안에 힘 싣기"(오채건). 오채건 예선은 DB를 Redis로 통일했었음 | 10/31 회의 |
| Q-DB | **DB 이전 로직** | 허들 회의록: **미설계**. 원리는 스냅샷 선이전 → 양쪽 쓰기 → 싱크 맞으면 원본 차단(CDC 계열). 데모 앱에 DB를 넣을지는 시간 측정 후 결정(박소정 팀은 예선 때 DB 포함 앱으로 시연) | 강윤주 + 이정 |
| Q-시크릿 | **시크릿 저장소** | Jeong 결정은 ESO + Vault, 허들 회의록은 "Vault 고려, 미정" | 오채건 |
| Q18 | ~~온프레 담당~~ + 노트북 k3s 부하 | 담당은 **오채건**(잠정). 노트북 부하 문제는 남음 | 오채건 |
| Q19 | 출제 의도 (상용 솔루션이 이미 있는데 왜 이 주제?) | 발표 "왜 이 테마" 30초. 【사실: 10 §2.6】 SoftBank 법인 MSP·Cloud PF Type A가 "Beyond Lock-In" 사업 자체 | 각자 조사 |
| D-경로 | **데모 이전 경로** ⚠️ | 결정 로그 가정 = AWS ECS+RDS → GCP GKE+Cloud SQL (Jeong 19:19 "일단 상정"), Jeong 제안 = → 온프레까지 2단. **그런데 허들 회의록은 "우선순위: 온프레 ↔ AWS 전환 우선, GCP는 여유 시"**. 보안 특화 + 온프레 IAM·시크릿 재현이 핵심이 됐으니 온프레 ↔ AWS가 자연스러움 【추정】. 단 킥오프 필수 데모가 "클라우드 간 이전"(p20)이라 GCP를 빼면 그 장면이 약해짐. 결정 로그·명세(실환경 AWS·GCP·온프레)와 맞춰야 함 | 10/31 회의 |
| D-앱 | 관리 대상 앱 | DB 1개 가진 단순 웹앱 제안 (11 §11.1 결정 2) | 팀 |
| D-원본 | 요구사항 명세 **원본을 어디로** (레포 md / Google Doc / Notion) | 지금은 레포 md를 고친 뒤 나머지 둘에 복사하는 중. 3곳 동시 유지는 어긋날 위험 큼 | **Jeong** |
| D-스택 | 컨트롤 플레인 스택 3개 (15번 문서 TODO(human)) | Fastify 유지 / Zod = IR 원본 + `z.toJSONSchema()`로 내보내기 / pg-boss + 직접 짠 이전 상태 머신, Temporal은 "검토한 대안". 예선 레포의 실제 pg-boss 메이저 버전 【미확인】 | Jeong → 팀 |
| D-템플릿 | 에픽을 GitHub에 둘지 Notion 카드로 둘지, 아키텍처 파트를 라벨로 할지 드롭다운만 할지 | 템플릿은 드롭다운 16개로 만들어 둠 | Jeong |
| ~~D-일정~~ | ~~일정안~~ | 팀 일정으로 대체: 10/31 설계 확정 → 11/1 개발 시작 → 11/6 완성 (Meeting - 2 §6) | 끝 |
| Q-QA | 참가자 번호가 순위인가 | QA 때 질문 | 아무나 |

킥오프에서 운영에 물으려던 질문(Q6~Q15: AI 비용 포함 여부, 회장 네트워크, 제출 링크 갱신 가능 여부 등)은 11 §8.2에 있고, Slack `#final_all_question`에 **아직 안 물어봤다** 【추정】.

---

## 6. 대기 중인 일 (막힌 것)

| 일 | 막힌 이유 | 푸는 방법 |
|---|---|---|
| Service 레포에 이슈/PR 템플릿 푸시 | 클라우드 세션은 Softbank-Hackathon-Team 조직에 Claude GitHub 앱이 없어 403 | **CLI에서 Jeong 본인 권한으로 푸시**: patch를 Library에서 받아 `git am` (§9 프롬프트 B). 또는 https://claude.ai/connect-github 에서 조직에 앱 설치 |
| 템플릿 라벨 `epic`·`feature`·`bug` | 레포에 라벨이 없으면 자동으로 안 붙음 | 푸시할 때 같이 생성 (`gh label create`) |
| 아키텍처 가이드 팀원 공유 | Claude Doc 공유 설정 | Jeong이 공유 켜기, 또는 레포 md 링크로 대체 |
| GitHub 프로필 README | 프로필 레포(`Pionia5375/Pionia5375`)는 Jeong이 직접 만들어야 함 | 초안은 프로젝트 파일 `github-profile/README.md` |

1차 회의 할 일 (Notion 「10/30 Meeting」 체크 상태 기준, 10/30 13:54Z):

- [x] 전원: when2meet 입력
- [x] 이정: Notion 템플릿 정리 / Slack에 미팅 일정 + 팀 페이지 링크 / 아키텍처 캡처 Slack 업로드 / GitHub org 초대
- [x] 회의록 2개 Notion 업로드 (「10/30 Meeting」, 「10/30 Meeting - 2」)
- [ ] 이정: 오채건 Linear식 템플릿 검토 후 반영
- [ ] 전원: Notion 개인 페이지에 경험·역량·가용 시간
- [ ] 오채건: 예선 때 받은 질문·코멘트 Slack 정리, 업계 사례 조사

허들 액션 아이템 (10/31 22:00 회의 전, Meeting - 2 §7):

- 이정: **담당 영역 PoC**(API·오케스트레이터·IR), 가능하면 어댑터까지 리서치 / 허들 메모 정리해 공유
- 강윤주: 이전·롤백 핸들러, Argo/카나리, Terraform 리서치
- 오채건: 온프레 보안 구현 방안 + AI 에이전트 샌드박스 보안 조사
- 박소정: 받은 자료로 아이디어 정리 (11/3 이후 본격 합류)
- 박승준: 역할 확정

---

## 7. 다음 할 일 (추천 순서)

10/31(토) 하루 기준. 22:00 회의가 기준점이다.

1. **오전**: Jeong 담당 영역 PoC 시작 — Fastify + Zod로 IR 스키마 1개 + `POST /migrations` 같은 API 하나 + pg-boss 작업 넣기. 11/1 개발 시작 전에 골격을 보여 줄 수 있게 (허들 액션 아이템)
2. **오전**: 허들 메모 정리해 Slack 공유. 특히 §4의 ⚠️ 항목(Cloudflare vs Rollouts 역할, Vault, 데모 경로)을 한 줄씩 설명
3. **오후**: 2차 회의 안건 짜기. 순서 제안: 보안 특화 포인트 고르기 → 데모 경로(온프레↔AWS vs AWS→GCP) → 확장 베이스 → 역할 확정 → DB 이전 담당. 항목마다 "기본안 + 대안 + 버릴 때 이유"
4. **오후**: 명세 11번에 보안 특화 반영안 만들기 (가드레일 프레임워크 FR 신설 후보, ID는 새 번호로)
5. **틈틈이**: Service 레포 템플릿 푸시 (CLI, 15분)
6. **19~20시 이후**: 팀원 리서치 읽고 회의 전에 요약
7. **회의 후**: 결정 → `decisions/2026-10-31.md`, 명세 우선 칸 수정, Notion 반영
8. **틈틈이**: `STATUS.md`를 본선 체제(D-8 카운트다운)로 다시 쓰기. 10/20 학습 로드맵 항목은 대부분 이제 안 해도 됨

---

## 8. CLI 세션에서 지킬 규칙 (프로젝트 메모리에서 옮김)

클라우드 프로젝트의 메모리는 CLI에서 안 보이니, 여기 핵심만 옮긴다. 전체 지침은 `notes/project-instructions.md`.

- **말투**: 한국어 반말, 할 일은 개조식. 【사실】【추정】【미확인】【사용자】 표기.
- **가르치는 방식**: 명령이나 TODO(human)를 주기 전에 개념을 0부터. 처음 나오는 명령은 한 줄씩 무엇을 하는지 설명. Spring 비유 쓰지 말 것. 한 단계 → 확인 질문 1개 → 출력 붙여 달라고.
- **역할 분담**: Claude가 문서·ADR·PoC를 쓰고 Jeong은 리뷰. 설계 결정은 TODO(human)로 남김.
- **산출물 형식**: 첫 줄 `로드맵 위치: ...`, 끝에 핵심 결정 3개(+대안) · 셀프 연습 1개 · 검증 명령과 기대 출력. 결정은 `decisions/YYYY-MM-DD.md`.
- **Git**: 이 레포는 1인 레포라 PR 없이 main 직푸시. 팀 레포(Softbank-Hackathon-Team)는 팀 규칙을 따를 것 (starter-pack/github/02-strategy.md 추천안: squash, 1 이슈 = 1 PR. 팀 미확정).
- **AWS 금지 규칙**: 리소스 생성, `terraform apply/destroy`는 **Jeong 승인 후, 로컬 세션에서만**. CLI는 로컬이라 할 수는 있지만 매번 승인 받기. AWS 쓰는 날은 **예산 알람 먼저**, 당일 destroy. 계정 725072160743(ap-northeast-2), 10/28 기준 과금 리소스 없음 【사실】.
- **Notion**: 페이지·속성·뷰를 묻지 않고 추가하지 말 것. Notion에 시크릿 값 쓰지 말 것.
- **일본어 연습 없음** 【사용자】.
- **연락 금지**: 김택근 님(해커톤 끝날 때까지).

---

## 9. CLI에서 바로 붙여 넣을 첫 프롬프트

### A. 추천: 2차 회의 준비부터

```
HANDOFF.md를 처음부터 끝까지 읽고, decisions/2026-10-30.md와 notes/research/11-finals-requirements.md의 §8.1a·§11도 읽어 줘.
그다음 오늘(10/31) 22:00 2차 팀 회의 안건을 notes/meetings/2026-10-31-agenda.md로 만들어 줘.
- 특화 테마는 이미 "보안"으로 정했어. 결정 순서: 보안 특화 포인트 → 데모 이전 경로(§5 D-경로의 충돌 정리) → 확장 베이스(Q1) → 역할 확정 → DB 이전·시크릿 저장소 담당
- 항목마다: 기본안 / 대안 2개 / 버리면 왜 버리는지 / 정할 사람 / 타임박스(분)
- 30분 안에 끝나게. 팀원이 처음 읽어도 이해되게 평이하게.
쓰기 전에 HANDOFF.md §5 표에서 빠진 열린 질문이 있는지 먼저 말해 줘. 커밋은 내가 확인한 뒤에.
```

### B. Service 레포 템플릿 푸시 (patch를 받은 뒤)

먼저 claude.ai 프로젝트 Library에서 `github-templates/service-templates.patch`를 내려받아 `~/Downloads/`에 둔다.

```
~/Downloads/service-templates.patch를 Softbank-Hackathon-Team/Service 레포에 적용하려고 해.
1) 레포를 클론하고(이미 있으면 git pull), 2) patch 내용을 먼저 보여 주고 무엇이 바뀌는지 설명한 다음, 3) 내가 OK하면 git am으로 적용해서 main에 푸시해 줘.
그리고 gh로 epic·feature·bug 라벨이 없으면 만들어 줘. 처음 쓰는 명령은 한 줄씩 무엇을 하는지 설명해 줘.
```

### C. STATUS.md 갈아엎기

```
HANDOFF.md를 읽고, 10/20에서 멈춘 STATUS.md를 본선 체제로 다시 써 줘.
- 맨 위: D-day 카운트다운(본선 11/7까지), 오늘 할 일 3개
- 마일스톤 표는 HANDOFF.md §1 일정 기준
- 10월 학습 로드맵 항목은 지우지 말고 "아카이브" 접기 섹션으로 내려
diff를 보여 주고 내가 OK하면 main에 커밋·푸시해 줘.
```

---

## 핵심 결정 3개 (+대안)

1. **이 handoff의 원본 위치 = 레포 루트 `HANDOFF.md`** — 대안: Notion 페이지 / Claude Doc. CLI가 바로 읽고 git으로 갱신 이력이 남아서 레포를 골랐다. 팀원용이 아니라 Jeong + Claude용이라 Notion에는 안 올림.
2. **"확정"을 두 단계로 나눠 표기 (Jeong 확정 / 팀 확정)** — 대안: 전부 "확정"으로. 10/31 회의에서 오채건 시스템이 베이스가 되면 일부 결정(어댑터·큐 등)이 다시 열릴 수 있어서, 무엇이 흔들릴 수 있는지 보이게 했다.
3. **첫 작업 추천 = 2차 회의 안건(A)** — 대안: 템플릿 푸시(B) / STATUS 정리(C). 특화 테마는 정해졌지만 데모 경로가 허들 회의록과 결정 로그 사이에서 어긋나 있어서, 오늘 회의에서 이걸 먼저 풀어야 이전·보안 담당이 움직인다. B는 15분짜리라 틈에 끼울 수 있다.

## 셀프 연습 1개

데모 경로를 **온프레 ↔ AWS**로 바꾸면 §4 결정 중 다시 손봐야 하는 것 3개를 골라 "왜"를 한 줄씩 적어 봐. (힌트: GCP SCC, Cloudflare 오리진 풀, 킥오프 필수 데모 "클라우드 간 이전" p20.)

## 검증 명령과 기대 출력

```bash
# 1) handoff 갱신본인지 (main에는 02:20 첫 버전만 있음)
grep -c "Meeting - 2" HANDOFF.md
# 기대: 1 이상 (0이면 갱신 전 버전)

# 2) handoff가 가리키는 레포 파일이 전부 있는지
for f in notes/research/10-finals-kickoff-brief.md notes/research/11-finals-requirements.md \
         notes/research/15-fastify-zod-pgboss.md decisions/2026-10-30.md \
         notes/architecture/arch-v0.3-k8s.svg notes/guide/finals-architecture-guide.md \
         notes/project-instructions.md STATUS.md; do
  test -f "$f" && echo "OK  $f" || echo "MISSING  $f"
done
# 기대: 8줄 모두 OK

# 3) 명세 v3인지
grep -c "FR-MIG-10" notes/research/11-finals-requirements.md
# 기대: 1 이상
```
