로드맵 위치: 본선 D-8 (10/31 KST 새벽 기준) / 본선 킥오프 이후 현황 인수인계 / Claude Code CLI 세션이 바로 이어받기

# 본선 상황 handoff (2026-10-30 킥오프 직후)

> 이 파일 하나만 읽으면 CLI 세션이 지금까지의 맥락을 잡고 바로 일할 수 있게 정리했다.
> 작성: 2026-10-31 02:20 KST (클라우드 프로젝트 스레드 "본선 상황 handoff 문서 만들기").
> 표기: 【사실】(출처) / 【추정】 / 【미확인】 / 【사용자】(Jeong이 말한 것).
> 맨 아래 §9에 CLI에서 바로 붙여 넣을 첫 프롬프트가 있다.

---

## 0. 30초 요약

- 【사실: notes/research/10】 본선 주제는 **"Beyond Lock-In: Frictionless Cloud Management Across Platforms"**. 예선 배포 시스템을 멀티 클라우드 관리 플랫폼으로 키우고, 핵심은 **클라우드·온프레 사이 무중단 이전**.
- 【사실: 10 §1】 데모 필수 3장면: ① 클라우드 간 라이브 이전 ② 멀티 환경 보안·거버넌스 시각화 ③ AI 에이전트가 샌드박스에서 점검·수정. 배점 30/30/10/10/20. Day1(11/7) 중간 7분, Day2(11/8) 최종 5분, 슬라이드 금지.
- 【사실】 팀 **Iron** 5명 확정(이정·박승준·박소정·강윤주·오채건). 1차 회의 10/30 21:00~21:48. 정기 회의 **매일 22:00**, 다음 회의 **10/31(토) 22:00**.
- 【사실: decisions/2026-10-30.md】 아키텍처는 Jeong 쪽에서 v0.3-k8s까지 그렸고 큰 결정 대부분을 Jeong이 확정. 다만 **팀 차원 확정은 아직**(확장 베이스·특화 테마·데모 경로).
- 【사실】 요구사항 명세 v3가 레포·Google Doc·Notion **3곳**에 있다. 어느 쪽이 원본인지 Jeong이 아직 안 정했다.
- 【사실】 팀 GitHub 조직(Softbank-Hackathon-Team)의 Service 레포에 이슈/PR 템플릿을 올리려다 **403**(Claude GitHub 앱 미설치). CLI는 Jeong 본인 git 권한으로 푸시할 수 있으니 여기서 풀린다.

---

## 1. 일정·마감

| 날짜 (KST) | 내용 | 상태 |
|---|---|---|
| 10/30(금) 20:00~21:00 | 공식 킥오프 (Google Meet) | 【사실】 완료 |
| 10/30(금) 21:00~21:48 | 1차 팀 회의 | 【사실】 완료, 회의록은 스레드에만 있음(레포 미커밋) |
| **10/31(토) 19~20시** | 전원: 특화 테마 브레인스토밍을 Notion 개인 페이지에 업로드 | 【사실: 1차 회의 §12】 |
| **10/31(토) 22:00** | 2차 회의: 특화 테마·확장 베이스·역할 | 【사실】 |
| 11/1(일) 13:00~17:00 | 명세·범위 동결 (일정안 B) | 【추정】 B안은 추천일 뿐, 팀 미확정 (starter-pack/schedule.md) |
| 11/5(목) 21:00 | 데모 동결 | 【추정】 같은 B안 |
| 11/6(금) 18:00~22:00 | Jeong 사회 일정으로 불가 | 【사용자】 |
| **11/7(토) 10:00** | 코드·설계 문서·발표 자료 링크 제출 (Slack 팀 채널 @mentors) | 【사실: 10, p28-29】 |
| 11/7(토) | Day1 중간 보고 7분 (설계 문서 + 아키텍처 그림) | 【사실】 |
| **11/8(일) 13:00** | 발표 언어 + Notion 토크 스크립트 제출 | 【사실】 |
| 11/8(일) | Day2 최종 발표 5분, 슬라이드 금지 | 【사실】 |

- 장소: 라마다 동대문 B1 【사실】. 현장 개발 시간 약 7.5h(Day1 10:30~14:00, Day2 10:00~14:00) 【사실: p51】.
- 지원금 ₩500,000/팀. 일본어판은 "인프라 + AI 요금", 한국어판은 "인프라 사용료"라 AI 포함 여부는 【미확인】(Q6).

---

## 2. 팀 Iron

| 이름 | 배경 (요약) | 메모 |
|---|---|---|
| 이정 (Jeong, GitHub `Pionia5375`) | 컴공 3학년, 서울 예선(camellia) | 진행·Notion·GitHub 관리 담당(전원 동의). 목표 역할 = 컨트롤 플레인 API(WP1) + 설계·발표 리드(WP6) + 측정 한 조각(WP5). 피드백: 말 속도 줄이기 |
| 박승준 | KAIST, AI·LLM·KV 캐시 연구 | 웹·클라우드는 공부 중. 회의 2~3시간 전 문서 업로드 원함. 후보 WP4(에이전트) |
| 박소정 | 4학년, 클라우드 직무 준비, 서울 예선 | 후보 WP5(관측·측정) |
| 강윤주 | 정보통신 졸업, KT Cloud 부트캠프 7개월, AWS 가능, 부산 예선 | 예선 때 관리 플랫폼을 온프레에 둠(키 유출 우려). Claude Pro만 있음. 후보 WP2(이전 엔진) |
| 오채건 | 사이버보안, 서울 예선, 예선 Notion 담당 | 예선 시스템(모듈 + 오케스트레이터, JSON 스키마 입출력, 모듈별 정책 게이트, 데스크탑 온프레)이 확장 베이스 후보. 후보 WP3(보안·온프레) |

- 역할은 "아키텍처 나온 뒤 기능 단위로 배분"으로 합의 【사실: 1차 회의 §12】. 위 후보는 【추정】(notes/research/11 §11.3).
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

## 4. 확정된 결정 (decisions/2026-10-30.md 요약)

"Jeong 확정"은 Jeong이 고른 것이고, 팀 회의에서 반대는 없었지만 팀 전체가 투표한 건 아니다.

| # | 결정 | 확정 수준 |
|---|---|---|
| 1 | **운영 모델 = 관리형 멀티 테넌트 플랫폼**. 모든 테이블 `tenant_id` + Postgres RLS, 테넌트별 Argo CD AppProject | Jeong 확정 (FR-BASE-09) |
| 2 | **고객 연결 = 원클릭 템플릿**: AWS CloudFormation 빠른 생성 / GCP Cloud Shell 스크립트 / 온프레 Agent 한 줄. 고객 키를 보관하지 않고 역할(observe·operate) 위임, 테넌트별 ExternalId | Jeong 확정, 1차 회의에서 강윤주 납득 (FR-BASE-08) |
| 3 | **가져오기(import)**: observe 역할 → 벤더 인벤토리(Resource Explorer/Config, Cloud Asset Inventory) → 빈 칸만 describe → 공통 명세(IR) 초안 → AI는 확신 낮은 칸 표시만 → 사람 확인. 범위 = 컨테이너 서비스 + k8s | Jeong 확정 (FR-MIG-10) |
| 4 | **실환경 = AWS · GCP · 온프레(노트북 VM k3s)**. Azure는 어댑터 코드 + Mock(녹화 응답 계약 테스트)만, 화면에 "Mock" 표시, 데모 경로 아님 | Jeong 확정 10/30 19:45 (18:02 "3사 대칭"을 수정) |
| 5 | **온프레 FR-ONP 6개 전부 MUST**: IAM = k8s RBAC / 시크릿 = ESO + Vault / 감사 = k8s audit log / 모니터링 / 백업 등 | Jeong 확정 |
| 6 | **환경 어댑터 = 우리 코드(번역기)**: 공통 명세 → ① Terraform 입력값(클라우드 층) ② Helm values(k8s 층) | Jeong 확정 |
| 7 | **k8s 사용**: 플랫폼 계정에 관리 EKS + vCluster 샌드박스 + Argo CD 허브. 이유는 vCluster와 Argo CD뿐(web·api·worker는 컨테이너면 충분) | Jeong 확정, 팀 반대 없음. 온프레 노트북 부하 우려 남음 |
| 8 | **작업 큐 = Postgres(pg-boss)** + 교체 가능 인터페이스. tfstate = S3 `use_lockfile` | Jeong 확정. 스택 세부(Fastify/Zod)는 §5-6 |
| 9 | **트래픽 전환 = Cloudflare Load Balancing 가중치** 10→50→100 | Jeong 확정 10/30 19:22 |
| 10 | **자동 롤백** = 도착 쪽 5xx > 1% 또는 p95 > 출발 p95의 2배가 30초 지속. DB 복제 lag는 롤백 기준이 아니라 **컷오버 전 관문** | Jeong 확정 |
| 11 | **보안 서비스**: 데모 경로 2곳만 실제로 켬(AWS GuardDuty 30일 체험, GCP SCC 무료 등급). Azure Mock·온프레는 Prowler/Kyverno/Trivy/kube-bench 결과를 같은 스키마로. Falco는 EXTRA | Jeong 확정 |
| 12 | **AI 에이전트 = 자체 도구 루프**: 좁은 도구 4~5개(vCluster 안 kubectl, GitOps 레포 읽기·수정, kyverno test, PR 생성). 프로덕션 도구 없음, 모든 호출은 오케스트레이터 경유 | Jeong 확정 (FR-AGT-07·09) |
| 13 | **샌드박스 단계**: k8s 층 vCluster(MUST) → 클라우드 층 plan·정적 점검(MUST) → 도착 클라우드 전체 재현(EXTRA) | Jeong 확정 |

---

## 5. 열린 결정 (누가 언제 정하나)

| # | 질문 | 현재 안 | 정할 곳 |
|---|---|---|---|
| Q1 | **확장 베이스**: 누구 예선 시스템을 키우나 | 1차 회의에서 Jeong이 **오채건 시스템** 제안, 오채건 "괜찮다, 막판에 급히 만든 부분 있음". 가이드 §13은 camellia 설계 추천이었음 → 충돌 정리 필요 | 10/31 22:00 회의 |
| Q16 | **특화 테마**: 성능 / 보안 / 완전 멀티 클라우드 중 어디를 깊게 | 명세 제안 = D1 이전 + D2 보안, D3 에이전트는 D1의 사전 점검으로 묶기 (11 §11.1) | 10/31 회의 (각자 19~20시 브레인스토밍 업로드) |
| Q17 | **이전 범위**: 같은 클라우드 안 빠른 이전 vs 어느 환경이든 깨지지 않는 이전 (DB 호환) | 명세는 "클라우드 간"(p20) 전제. 오채건 예선은 DB를 Redis로 통일했었음 | 10/31 회의 |
| Q18 | **온프레 담당 + 노트북 k3s 부하** | FR-ONP 전부 MUST인데 k8s 익숙한 담당이 없음. 오채건 데스크탑 온프레 경험 | 10/31 회의 |
| Q19 | 출제 의도 (상용 솔루션이 이미 있는데 왜 이 주제?) | 발표 "왜 이 테마" 30초. 【사실: 10 §2.6】 SoftBank 법인 MSP·Cloud PF Type A가 "Beyond Lock-In" 사업 자체 | 각자 조사 |
| D-경로 | **데모 이전 경로** | 가정 = AWS ECS+RDS → GCP GKE+Cloud SQL (Jeong 19:19 "일단 상정"). Jeong은 → 온프레까지 2단 이전 제안. 5분 안에 이전 2회(각 ≤ 90초)는 빠듯, 온프레 구간은 회장 네트워크 위험 | 팀 확인 대기 |
| D-앱 | 관리 대상 앱 | DB 1개 가진 단순 웹앱 제안 (11 §11.1 결정 2) | 팀 |
| D-원본 | 요구사항 명세 **원본을 어디로** (레포 md / Google Doc / Notion) | 지금은 레포 md를 고친 뒤 나머지 둘에 복사하는 중. 3곳 동시 유지는 어긋날 위험 큼 | **Jeong** |
| D-스택 | 컨트롤 플레인 스택 3개 (15번 문서 TODO(human)) | Fastify 유지 / Zod = IR 원본 + `z.toJSONSchema()`로 내보내기 / pg-boss + 직접 짠 이전 상태 머신, Temporal은 "검토한 대안". 예선 레포의 실제 pg-boss 메이저 버전 【미확인】 | Jeong → 팀 |
| D-템플릿 | 에픽을 GitHub에 둘지 Notion 카드로 둘지, 아키텍처 파트를 라벨로 할지 드롭다운만 할지 | 템플릿은 드롭다운 16개로 만들어 둠 | Jeong |
| D-일정 | 일정안 B(11/1 범위 동결, 11/5 데모 동결)와 "2명 이상 주말 8h 불가 → C안" 규칙 | 추천만 하고 미확정 | 팀 |

킥오프에서 운영에 물으려던 질문(Q6~Q15: AI 비용 포함 여부, 회장 네트워크, 제출 링크 갱신 가능 여부 등)은 11 §8.2에 있고, Slack `#final_all_question`에 **아직 안 물어봤다** 【추정】.

---

## 6. 대기 중인 일 (막힌 것)

| 일 | 막힌 이유 | 푸는 방법 |
|---|---|---|
| Service 레포에 이슈/PR 템플릿 푸시 | 클라우드 세션은 Softbank-Hackathon-Team 조직에 Claude GitHub 앱이 없어 403 | **CLI에서 Jeong 본인 권한으로 푸시**: patch를 Library에서 받아 `git am` (§9 프롬프트 B). 또는 https://claude.ai/connect-github 에서 조직에 앱 설치 |
| 템플릿 라벨 `epic`·`feature`·`bug` | 레포에 라벨이 없으면 자동으로 안 붙음 | 푸시할 때 같이 생성 (`gh label create`) |
| 아키텍처 가이드 팀원 공유 | Claude Doc 공유 설정 | Jeong이 공유 켜기, 또는 레포 md 링크로 대체 |
| GitHub 프로필 README | 프로필 레포(`Pionia5375/Pionia5375`)는 Jeong이 직접 만들어야 함 | 초안은 프로젝트 파일 `github-profile/README.md` |
| 1차 회의록 | 스레드에만 있음, 레포·Notion 반영 여부 【미확인】 | Notion "10/30 Meeting" 페이지에 붙였는지 Jeong 확인 |

1차 회의 할 일 중 Jeong 몫 (완료 여부 전부 【미확인】):

- [ ] Notion 템플릿 정리해서 올리기 (박승준 요청, "오늘 자기 전")
- [ ] Slack에 미팅 일정 + 팀 페이지 링크 게시
- [ ] 아키텍처 HTML 캡처 Slack 업로드 (SVG는 `notes/architecture/arch-v0.3-k8s.svg`)
- [ ] 오채건 Linear식 템플릿 검토 후 반영
- [ ] GitHub org 초대 (이메일 받는 대로)
- [ ] 회의록(녹취 + 정리) 업로드

---

## 7. 다음 할 일 (추천 순서)

10/31(토) 하루 기준. 22:00 회의가 기준점이다.

1. **오전**: §6의 Jeong 몫 체크 (Slack 게시·Notion 템플릿이 아직이면 이것부터. 팀원이 19~20시까지 개인 페이지를 써야 하니까)
2. **오전**: Service 레포 템플릿 푸시 (CLI, 15분)
3. **오후**: 2차 회의 안건 짜기. 결정 순서 제안: Q16 특화 테마 → Q1 확장 베이스 → 데모 경로 → Q18 온프레 담당 → 역할(WP1~6). 각 항목에 "기본안 + 대안 + 버릴 때 이유" 한 줄씩
4. **오후**: 오채건 예선 레포 구조를 읽고 우리 v0.3-k8s와 맞는 곳/안 맞는 곳 표 만들기 (Q1 판단 근거)
5. **19~20시 이후**: 팀원 브레인스토밍 읽고 회의 전에 요약
6. **회의 후**: 결정 → `decisions/2026-10-31.md`, 명세 11번 우선 칸 수정(ID는 그대로), Notion 반영
7. **틈틈이**: `STATUS.md`를 본선 체제(D-8 카운트다운)로 다시 쓰기. 10/20 학습 로드맵 항목은 대부분 이제 안 해도 됨

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
- 결정 순서: 특화 테마(Q16) → 확장 베이스(Q1) → 데모 이전 경로 → 온프레 담당(Q18) → 역할(WP1~6)
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
3. **첫 작업 추천 = 2차 회의 안건(A)** — 대안: 템플릿 푸시(B) / STATUS 정리(C). 오늘 회의에서 특화 테마·베이스·역할이 정해져야 나머지 일이 움직이고, B는 15분짜리라 틈에 끼울 수 있다.

## 셀프 연습 1개

§4의 결정 13개 중 **오채건 예선 시스템이 베이스가 되면 다시 열리는 것**을 3개 골라, 각각 "왜 흔들리는지"를 한 줄로 적어 봐. (힌트: 오채건 시스템은 JSON 스키마 입출력 + 모듈별 정책 게이트 + DB를 Redis로 통일했다.)

## 검증 명령과 기대 출력

```bash
# 1) handoff가 main에 있는지
git fetch origin main && git log origin/main --oneline -1 -- HANDOFF.md
# 기대: "handoff: 본선 킥오프 이후 현황 ..." 커밋 한 줄

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
