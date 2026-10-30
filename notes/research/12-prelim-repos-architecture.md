로드맵 위치: 본선 직전 주(D-8) / 예선 팀 레포 전수 조사 + camellia 심층 분석 / 본선 연결점 = 오늘 밤 1차 회의 첫 쟁점 "누구 예선 시스템을 확장하나"의 근거

# 12. 2026 예선 팀 레포 조사와 camellia(우리) 시스템 분석

> 작성 2026-10-30 낮(킥오프 당일). 입력: `10-finals-kickoff-brief.md`(본선 주제 "Beyond Lock-In"), `11-finals-requirements.md`(FR/NFR).
> 방법: GitHub 검색(웹) + 공개 레포 shallow clone 후 README·코드·문서 직접 읽음. 비공개 레포·조직 멤버 목록은 못 봄.
> 표기: 【사실】(출처) / 【추정】 / 【미확인】 / 【사용자】

## 0. 한 장 요약

1. 예선 팀 레포는 **7개 팀**을 찾았다: camellia(우리), Crystal(부산 최우수), Gold, Diamond, Daisy, Amethyst, Freesia. 나머지 팀은 비공개거나 검색에 안 걸렸다 【미확인】.
2. 시스템은 크게 **두 계열**로 갈린다.
   - **"배포 엔진" 계열**: 앱 분석 → 빌드 → Terraform → 대상 환경 실행. camellia, Daisy, Freesia, Gold, Diamond.
   - **"GitOps + k8s" 계열**: PR → 검사 → GitOps 레포 → Argo CD가 여러 클러스터에 → Argo Rollouts 카나리/블루그린. Crystal, Amethyst.
3. 본선 주제(무중단 이전·보안 통합 시각화·AI 샌드박스)에 **가장 가까운 기능을 이미 가진 건 camellia다**: 같은 이미지 digest를 AWS·온프레에 띄우고, 새 쪽 검증이 통과해야만 Cloudflare 주소를 넘기는 "검증 후 전환", 검증 실패 시 기존 서비스 유지, 온프레 장애 시 AWS 자동 페일오버까지 있다 【사실: 레포 코드·리포트】.
4. camellia의 빈칸 = 본선의 핵심 질문 그대로: **(a) 상태 있는 앱(DB)의 데이터 동기화가 없다**(페일오버는 stateful이면 제외) (b) **전환 중 실패 요청 수를 잰 적이 없다**(잰 건 "전환 작업 시간") (c) 퍼블릭 클라우드가 **AWS 하나**(GCP·Azure는 P2로 미룸) (d) 보안·거버넌스 화면 없음 (e) AI는 분석·실패 진단까지, 샌드박스 없음.
5. 약점: **AWS 인프라를 10/6에 지워서 지금은 안 돈다**【사실: 메모리】, 코드가 TypeScript 3.5만 줄 규모라 새 팀원이 1주 안에 익히기 무겁다 【추정】.
6. GitOps 계열(Crystal)은 "3환경 같은 커밋 + 자동 롤백 + 실측"이 강하지만 **이전(migration) 개념이 없다**. 각 환경은 독립 배포일 뿐, 한 환경에서 다른 환경으로 트래픽·데이터를 옮기지 않는다 【사실: Crystal README】.
7. 결론 【추정】: 본선 팀에 camellia 출신이 Jeong 혼자라도, "**camellia의 전환 흐름(검증 후 주소 전환)을 설계 출발점으로 가져오고, 실행 엔진은 팀이 고른다**"가 가장 설득력 있는 제안이다. 이 결정은 인터뷰 Q1에서 Jeong이 고른다.

## 1. 찾은 예선 팀 레포

| 팀 | 회차·결과 | 레포 | 한 줄 | 퍼블릭 클라우드 | 온프레 | 실행 방식 | AI |
|---|---|---|---|---|---|---|---|
| **camellia(우리)** | 예선1(10/3-4) 【사실: 레포 CLAUDE.md】 | [2026-Softbank-hackathon/Auto-Deployment-System](https://github.com/2026-Softbank-hackathon/Auto-Deployment-System) | 소스 업로드 → 분석·IR → 1회 빌드 → AWS·온프레 배포·전환 | AWS(ECS Fargate·Lambda·S3 정적) | Intel Mac VM + Docker Compose + Agent + Cloudflare Tunnel | 자체 API + Postgres 큐 워커 + Terraform CLI | Claude(Anthropic/Bedrock 전환 가능): 분석 보강·실패 진단·SQLite→PG 코드 수정안 |
| **Crystal** | 예선2 부산(10/10-11) **최우수** 【사실: 조직 README】 | [Crystal-SBHackathon2026](https://github.com/Crystal-SBHackathon2026/.github) (review-service, gitops, oneaction-infra 등) | PR → AI 검토(규칙 31개 + RAG + LLM) → GitOps → 3클러스터 | AWS EKS(서울) + GCP GKE(도쿄) | 부산 로컬 k3s | Argo CD + Argo Rollouts(카나리·블루그린), Prometheus 에러율 자동 중단 | LangGraph + Claude + Qdrant |
| **Gold** "CloudMorph" | 예선2 【사실: README】 | [SoftBank-Hackathon-2026-in-Korea-Gold/...](https://github.com/SoftBank-Hackathon-2026-in-Korea-Gold/SoftBank-Hackathon-2026-in-Korea) | 정적 분석 → 타깃 결정 → 배포 실패 시 Dockerfile 자가 패치 | GCP Cloud Run(+functions), GCP·AWS VM 노드 풀(SSH) | 서버 Docker, 에이전트 타깃 | FastAPI 오케스트레이터 | LangGraph healer(최대 3회) |
| **Diamond** "Paved Clouds" | 예선2 【사실: README】 | [JinnyLyn/SoftBank-Hackathon](https://github.com/JinnyLyn/SoftBank-Hackathon) | 비전공자용 관리형 배포 + 독립 도메인 | AWS 단일(ECS Fargate·ECR·ALB·RDS) | 없음 | FastAPI + Terraform | 분석 |
| **Daisy** "Unibloom" | 예선1 【사실: README】 | [Softbank-Hackathon-2026-Team-Daisy/unibloom](https://github.com/Softbank-Hackathon-2026-Team-Daisy/unibloom) | 환경 고르면 AI가 환경별 Terraform 생성·검증 → 승인 → 병렬 apply | AWS ECS + GCP Cloud Run + Azure Container Apps | Proxmox VM Docker | Spring Boot + Jenkins(ci·plan·apply) | Claude가 Terraform 생성·수정(최대 3회), 검증 스크립트 재사용 시 AI 0회 |
| **Amethyst** "완땃찌" | 【미확인: 회차】 | [SoftBank-Hackathon-2026-Team-Amethyst](https://github.com/SoftBank-Hackathon-2026-Team-Amethyst/.github) (one-tatchi-platform, demo-app) | "AI는 변수만 채우고 규칙은 템플릿이 지킨다", 출구전략 | AWS EKS + GCP | k3d | 재사용 워크플로 + Helm + Argo Rollouts 블루그린, Slack 승인 | Claude Code Agent Skills |
| **Freesia** | 【미확인: 회차】 | [softbank-hackathon-2026/Freesia-backend](https://github.com/softbank-hackathon-2026/Freesia-backend) | GitHub 레포 URL → AI 추천 → workflow_dispatch로 배포 | AWS(ECS·Lambda·EC2) | Proxmox VM(Ansible) | FastAPI + GitHub Actions(Terraform/Ansible) + 서명 콜백 | Bedrock 분석·템플릿 값 채우기, 검증 규칙 V1~V9 |

- Freesia API 도메인이 `howon.me` → 2025 본선 우승팀 멤버 정호원이 Freesia 소속이라는 기존 메모와 일치 【추정】.
- 작년 레포(Team Green, 우승 Blue)는 `01-last-year-winner-sh-final-blue.md` 참고. 올해와 주제가 달라 여기선 생략.
- 본선 팀 조직 [Softbank-Hackathon-Team/Service](https://github.com/Softbank-Hackathon-Team/Service)는 Jeong이 10/28에 만든 빈 레포(README 1줄) 【사실: clone】.

### 1.1 공통점과 차이 (본선 주제 기준)

| 본선 요구 | camellia | Crystal | Daisy | Gold | Amethyst | Freesia | Diamond |
|---|---|---|---|---|---|---|---|
| 같은 아티팩트를 여러 환경에 | ✅ 같은 digest | ✅ 같은 커밋 | ✅ 같은 커밋 | △ | ✅ | △ | ❌ |
| 환경 **간 전환**(트래픽을 A→B) | ✅ Cloudflare CNAME/Tunnel 전환 | ❌(환경별 독립) | ❌ | △ 노드 풀 라우터 | ❌ | ❌ | ❌ |
| 검증 실패 시 기존 유지 / 롤백 | ✅ 3/3 | ✅ 카나리 자동 중단 | △ 이전 커밋 재배포 | △ | ✅ 블루그린 | ❌ 명시 안 함 | ❌ |
| 데이터(DB) 이전 | △ SQLite→RDS 첫 시드만 | ❌(Crossplane 설계만) | ❌ | ❌ | ❌ | ❌ | ❌ |
| 퍼블릭 클라우드 2개 이상 | ❌ AWS만 | ✅ AWS+GCP | ✅ AWS+GCP+Azure | ✅ GCP+AWS VM | ✅ | ❌ | ❌ |
| 보안·정책 게이트 | △ API 인증·감사 로그 테이블 | ✅ 규칙 31개 + Trivy | △ 위험 설정 검사 | ❌ | ✅ Trivy·Gitleaks·IaC 검사 | △ V1~V9 | ❌ |
| AI가 고치기 | △ 실패 진단·코드 수정안 | ✅ 고쳐서 통과/사람 확인 | ✅ Terraform 수정 3회 | ✅ Dockerfile 패치 3회 | ✅ 3회 | ❌ | ❌ |
| 샌드박스에서 먼저 시험 | ❌ | ❌ | △ plan 단계 | ❌ | △ 블루그린 테스트 배포 | ❌ | ❌ |

【추정】 표는 README·코드 근거. △는 "비슷한 것은 있지만 본선 문구를 그대로 채우진 못함".

→ **어느 팀도 "가동 중 앱 + 데이터"를 클라우드 간 무중단으로 옮긴 적은 없다.** 본선은 모두에게 새 문제다. 그중 "트래픽 전환"까지 이미 가진 건 camellia뿐.

## 2. camellia 심층 분석

### 2.1 규모·팀 【사실: git log, README】
- 커밋 557개, PR #367까지, 기간 9/25~10/4. 비테스트 TypeScript 약 34,700줄 (apps + packages `src`).
- 6명: 이정(PM·아키텍처·컨트롤 플레인·분석기/IR·API·큐·상태 머신), 조서현(AWS 프로필·플랫폼 인프라), 안우진(인증), 신은영(빌드·프로비저닝·ECR·Terraform), 김민성(웹 콘솔·일본어), 김민서(검증·온프레 Agent·페일오버).
- 결정 기록 D-01~D-70 (`docs/decisions.md`), 대체된 결정 표까지 있음 → 팀 개발 20점 근거로 재사용 가능.

### 2.2 구조 【사실: README, docs/deploy-platform.md】

```
웹 콘솔(React) ─REST/SSE─▶ API(Fastify) ─▶ Postgres(상태 + pg-boss 작업 큐)
                                             ▲
                         Worker(analyze → build → provision → deploy → verify → origin 전환, failover monitor)
                           │ docker buildx → 사용자 ECR (linux/amd64, digest 고정)
                           │ terraform CLI → 사용자 AWS 계정 (ECS Fargate · Lambda · S3 · ALB · RDS)
                           │ Cloudflare API → service-{id}.camellia-deploy.app CNAME / Tunnel ingress
                           ▼
            On-Prem Agent(Intel Mac VM · Windows) — 롱 폴링 Job claim, ECR pull, Compose, cloudflared
```

- 플랫폼 자체 호스팅: EC2 t3.large 한 대 + Docker Compose(web·api·worker·Postgres·buildkit·cloudflared), 인바운드 포트 0, Cloudflare Tunnel `console.camellia-deploy.app`, 시크릿 SSM Parameter Store, CD는 GitHub Actions OIDC → SSM Run Command (D-54, D-55, D-57).
- 사용자 앱: "사용자 계정 방식"(사용자가 등록한 AWS 키로 그 계정에 생성, D-40).
- 핵심 개념 3개:
  - **IR**: 앱 요구사항만(서비스 유형·포트·헬스·env·시크릿·논리 리소스) — 환경 중립 명세 (D-35).
  - **프로필**: 환경별 검증된 인프라 골격 + capabilities (`aws-ecs-basic`, `aws-lambda-basic`, `aws-static-basic`, `onprem-docker-basic`) (D-36).
  - **어댑터**: IR 값을 프로필 변수로 매핑만.

### 2.3 "전환"이 실제로 어떻게 동작하나 【사실: docs/onprem-cloudflare-api.md, worker/src/origin-activation.ts】
1. 대상 환경에 **후보 배포**를 띄운다 (AWS면 ALB, 온프레면 Agent가 Compose + Tunnel, 후보 주소 `verify-d{id}.{domain}`).
2. Worker가 후보 endpoint를 헬스체크한다. Agent의 "됐다" 보고만으로 성공 처리하지 않는다.
3. 통과하면 고정 주소 `service-{project}.{domain}`의 CNAME(또는 Tunnel ingress)을 후보로 바꾼다 = **origin 활성화**.
4. 실패하면 고정 주소를 건드리지 않는다 → 기존 서비스 유지.
- 이건 개념상 **환경을 건너는 블루그린**이다. 본선 FR-MIG의 "단계적 트래픽 전환"은 아니고 "한 번에 전환"이다.
- 스스로 적어 둔 한계: Tunnel ingress 변경과 DNS 변경이 원자적이지 않음, 자동 롤백 없음(재시도로 수렴), 같은 프로젝트 양 환경 동시 전환은 직렬화 필요.

### 2.4 실측 숫자 (2026-10-02, 실서비스) 【사실: docs/performance-results/20261002-comprehensive/report.md】

| 시나리오 | 횟수 | 결과 | 중앙값 | 최대 |
|---|---|---|---|---|
| AWS → 온프레 전환 | 3 | 3/3 | 19.00초 | 19.39초 |
| 온프레 → AWS 전환 | 3 | 3/3 | 26.55초 | 2.19분 |
| 검증 실패 → 기존 유지 | 3 | 3/3 | 1.07분 | 3.01분 |
| AWS 동일 이미지 재배포 | 3 | 3/3 | 20.32초 | 22.92초 |
| 공개 헬스체크 | 20 | 20/20 | P95 144ms | |

- 주의: 여기서 "전환 시간"은 **작업 시작~완료 시간**이다. 전환 중 사용자 요청이 몇 건 실패했는지(본선 NFR-01 "실패 요청 0건")는 **잰 적 없다** 【사실: 리포트 열 구성】.

### 2.5 자동 페일오버 (migration 026) 【사실: worker/src/failover-monitor.ts】
- 조건: 활성 = 온프레, 대기 = AWS, 두 배포 모두 성공, **같은 digest**, **상태 있는 리소스 없음**.
- Agent heartbeat 끊김 + 공개 주소 실패가 임계치를 넘으면 대기(AWS)로 주소를 넘김, 후보 3회 연속 통과 필요, 쿨다운 5분.
- → 본선 "롤백 ≤ 60초"(NFR-05)의 재료. 다만 **DB가 있는 앱은 대상에서 빠진다**.

### 2.6 DB 처리 【사실: apps/samples/sqlite-web/README.md, D-43, D-64】
- 분석기가 SQLite 사용을 찾으면 IR에 PostgreSQL 리소스를 넣고 AI가 코드 수정안을 만든다 → AWS에선 RDS, 온프레에선 SQLite 그대로.
- 데이터: RDS가 비어 있으면 이미지 안의 `guestbook.db`로 **처음 한 번 시드**. 운영 중 쓰인 데이터의 동기화·복제는 없다. 온프레는 볼륨이 없어 재시작하면 데이터가 사라진다.
- → 본선 "RPO 0"(NFR-03)을 위해 **전부 새로 설계해야 하는 부분**.

### 2.7 보안·거버넌스 쪽 재료 【사실: migrations, D-50, docs】
- `010_audit_logs.sql`(감사 로그 테이블), 시크릿 AES-GCM 저장(D-50), API Key·세션·Agent Bearer 인증, 플랫폼 운영 대시보드(D-69: 플랫폼 자체 상태 한 화면).
- 없는 것: 클라우드 보안 서비스(GuardDuty/Security Hub/SCC) 연동, 정책 위반 매트릭스, 환경별 IAM 비교.

### 2.8 AI 쪽 재료 【사실: packages/analyzer/src/ai, D-56, D-68】
- 규칙 분석 + 애매한 부분만 AI(D-47), 실패 진단(diagnose 핸들러), 소스 패치 제안(020_source_patches), 한·일 구조화 출력.
- 제공자 `AI_PROVIDER=anthropic|bedrock` 한 곳에서 전환 → 본선 "AI 리소스 관리"(Bedrock) 이야기와 이어짐.
- 없는 것: 샌드박스 실행 환경, 에이전트 도구 루프, 사람 승인 게이트(배포 승인 화면은 있음: `approvals`).

### 2.9 그대로 재사용할 수 있나 【추정】

| 재사용 | 근거 | 리스크 |
|---|---|---|
| 전환 흐름(후보 → 검증 → origin 활성화 → 실패 시 유지) | 본선 FR-MIG의 뼈대와 같음 | DNS 전환이라 TTL·커넥션 드레이닝 측정 필요 |
| 상태 머신 + Postgres 큐 + 환경 락 | Jeong이 직접 만든 부분, 동시성 실측 있음 | 없음 |
| 온프레 Agent(아웃바운드 전용 + Tunnel) | 본선 "온프레 = 자기 PC/VM" 권장과 일치 | Intel Mac VM 전제, 회장 네트워크 미확인 |
| 결정 기록 D-01~70, 실측 리포트 | 팀 개발 20 "대안·고찰" | 본선 팀원 대부분은 이 맥락 모름 |
| 코드 전체를 베이스로 | 기능 많음 | 3.5만 줄 TS, 새 팀원 온보딩 비용, AWS 인프라 재구축 필요(지원금 50만 원 안) |

## 3. 본선 팀 1차 회의에 들고 갈 판단 재료

- 질문: "각자 예선에서 뭘 만들었고, **지금도 돌아가나**, 본선 주제의 3장면 중 무엇을 이미 갖고 있나?"
- camellia를 소개할 30초 문장(초안): "우리 예선 시스템은 같은 이미지를 AWS와 온프레에 띄우고, 새 쪽이 검증을 통과해야만 주소를 넘깁니다. 실패하면 기존이 유지되고, 온프레가 죽으면 AWS로 자동 페일오버합니다. 빠진 건 DB 데이터 이전과 두 번째 퍼블릭 클라우드입니다."
- GitOps 출신(Crystal·Amethyst류)이 섞이면: "환경별 배포는 Argo CD로 하고, **환경 간 트래픽·데이터 전환**을 컨트롤 플레인이 맡는다"는 합치기 그림이 자연스럽다 【추정】.

## 핵심 결정 3개 (+대안)
1. 확장 베이스 후보 = camellia 전환 흐름을 설계 출발점으로 (대안: 팀원 시스템 그대로 / 새로 얇게 / Crystal식 GitOps). → 인터뷰 Q1.
2. "이전"의 정의 = 트래픽 전환 + 데이터 동기화 둘 다 (대안: 무상태 앱만 옮기고 DB는 공용 외부 DB). → 인터뷰 Q2 후보.
3. 두 번째 퍼블릭 클라우드 = GCP(Crystal·Daisy·Gold 경험자 많음) (대안: NAVER Cloud, Azure). → 인터뷰 Q3 후보.

## 셀프 연습 1개
- camellia `apps/worker/src/origin-activation.ts`를 열어, "검증 통과 → CNAME 변경" 사이에 사용자 요청이 실패할 수 있는 순간을 2개 적어 보기. (힌트: Cloudflare 프록시 CNAME 반영 시간, 기존 origin의 진행 중 커넥션)

## 검증 명령과 기대 출력
```bash
# 1) camellia 레포 규모 확인
git clone --filter=blob:none https://github.com/2026-Softbank-hackathon/Auto-Deployment-System && cd Auto-Deployment-System
git log --oneline | wc -l            # 기대: 557
# 2) 전환 실측표 확인
sed -n 24,25p docs/performance-results/20261002-comprehensive/report.md   # 기대: 전환 2행, 3/3 PASS
# 3) 페일오버 대상 조건 확인
grep -n "hasStatefulResources" apps/worker/src/failover-monitor.ts        # 기대: !candidate.hasStatefulResources 줄
```
