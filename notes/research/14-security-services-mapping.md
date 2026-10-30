로드맵 위치: 본선 직전 주(D-8) / 클라우드 보안 서비스 ↔ 온프레 대응 + 수집·통일 방법 / 본선 연결점 = 장면 2 "여러 환경의 보안·거버넌스 상태를 한 화면에" (FR-SEC-01~06, FR-ONP-01~06)

# 14. 보안 서비스 구현 정리 — AWS · GCP · 온프레를 같은 기준으로 한 화면에

> 작성 2026-10-30. 입력: `11-finals-requirements.md` FR-SEC·FR-ONP, `13-kyverno-in-architecture.md` 4.1(Kyverno가 못 보는 것).
> 표기: 【사실】(출처) / 【추정】 / 【미확인】. 가격·무료 기간은 바뀌니 계정 만들기 전에 다시 확인.

## 0. 한 장 요약

1. 보안 서비스는 이름이 많지만 **하는 일은 7가지**다: 신원·권한 / 시크릿·암호화 / 감사 로그 / 위협 탐지 / 설정 점검 / 취약점 스캔 / 네트워크. 매트릭스 4항목(권한·암호화·감사·위반)은 이 7가지를 묶은 것.
2. 각 클라우드는 같은 일을 다른 서비스로 한다(GuardDuty ↔ Event Threat Detection ↔ Falco). 그래서 **서비스를 맞추는 게 아니라, 결과를 같은 모양(공통 스키마)으로 모으는 게** 핵심이다.
3. 구현 방식은 셋: A. 각 클라우드 네이티브 서비스 결과 수집 / B. 오픈소스 스캐너 하나(Prowler)로 전 환경 같은 규칙 / C. 섞기.
4. **추천 = C**: "설정 점검"은 Prowler + Kyverno로 **같은 규칙**을 세 환경에 돌리고(= "같은 기준"을 가장 확실히 증명), "위협 탐지"만 네이티브(GuardDuty·SCC)와 Falco(온프레)를 쓰고, 감사 로그는 각 환경 로그를 플랫폼 감사 저장소로 모은다. 공통 스키마 = **OCSF**.
5. 정직하게 적을 것: 온프레의 위협 탐지(Falco)는 GuardDuty보다 보는 범위가 좁다. "동일"이 아니라 "같은 목적, 다른 탐지 범위"로 설명하고 차이를 표로 남긴다.

## 1. 0부터: 보안 서비스가 하는 일 7가지

| # | 하는 일 | 쉬운 말 | 매트릭스 항목 |
|---|---|---|---|
| S1 | 신원·권한 (IAM) | 누가 무엇을 할 수 있나 | 권한 |
| S2 | 시크릿·암호화 (KMS·Secrets) | 비밀번호·키를 어디 두고, 데이터가 암호화돼 있나 | 암호화 |
| S3 | 감사 로그 (Audit) | 누가 언제 무엇을 바꿨나 기록이 남나 | 감사 |
| S4 | 위협 탐지 (Threat detection) | 지금 이상한 행동(침입·채굴·이상 API 호출)이 일어나나 | 위반 |
| S5 | 설정 점검 (Posture / CSPM) | 설정이 규칙을 어겼나 (공개 버킷, MFA 없음, 암호화 꺼짐) | 위반 (+권한·암호화 일부) |
| S6 | 취약점 스캔 (Vulnerability) | 이미지·패키지에 알려진 CVE가 있나 | 위반 |
| S7 | 네트워크 (Firewall·NetworkPolicy) | 열면 안 되는 포트·경로가 열려 있나 | 위반 |

- S4(지금 일어나는 일)와 S5(설정이 틀렸나)를 헷갈리지 말 것. S4는 **행동**, S5는 **상태**다.
- CSPM = Cloud Security Posture Management. "설정 점검"을 파는 제품군 이름.

## 2. 영역별 대응표

| 영역 | AWS | GCP | 온프레 (k3s VM) | k8s 층 (세 클러스터 공통) | 플랫폼이 수집하는 방법 |
|---|---|---|---|---|---|
| S1 권한 | IAM, IAM Access Analyzer | Cloud IAM, (Policy Analyzer) | Keycloak(OIDC) + Linux 계정 | RBAC, ServiceAccount | 클라우드 API 조회 / Prowler 체크 / Kyverno(RBAC 위험 설정) |
| S2 암호화·시크릿 | KMS, Secrets Manager | Cloud KMS, Secret Manager | Vault/OpenBao (또는 SOPS) | Secret, ESO, TLS Ingress | Prowler(저장 암호화 체크) / Kyverno(TLS·Secret 사용 강제) |
| S3 감사 로그 | CloudTrail | Cloud Audit Logs | k8s audit log + 호스트 auditd → Loki | k8s audit log | 각 로그에서 "켜져 있나" 체크 + 플랫폼 조작은 우리 감사 테이블 |
| S4 위협 탐지 | GuardDuty (EKS 보호 포함) | SCC Event/Container Threat Detection | **Falco** | Falco DaemonSet (선택) | 네이티브 finding API / Falco 이벤트 → 공통 스키마 |
| S5 설정 점검 | Security Hub CSPM, AWS Config | SCC Security Health Analytics | kube-bench(CIS), Lynis(호스트) | Kyverno PolicyReport | **Prowler(AWS·GCP·k8s 공통)** + Kyverno |
| S6 취약점 | Inspector, ECR 스캔 | Artifact Analysis | Trivy | Trivy Operator | Trivy 결과 (세 환경 동일 도구) |
| S7 네트워크 | Security Group, NACL, VPC Flow Logs | Firewall rules, VPC Flow Logs | nftables/ufw | NetworkPolicy | Prowler(0.0.0.0/0 체크) + Kyverno(NetworkPolicy 존재 강제) |

근거:
- 【사실: https://aws.amazon.com/free/security/ 10/30 확인】 GuardDuty 30일 무료 체험, Security Hub 30일 무료 체험(Essentials 포함), **Security Hub CSPM**도 30일 무료(= 예전 Security Hub의 설정 점검 기능이 이름이 갈라짐), Inspector 15일, CloudTrail 관리 이벤트 트레일 1개/리전 상시 무료(S3 비용 별도), KMS 월 20,000요청 무료.
- 【사실: https://docs.cloud.google.com/security-command-center/docs/activate-scc-project-level-limitations 】 SCC는 Standard·Premium 등 티어가 있고 프로젝트 단위 활성화가 가능. Event Threat Detection 대부분 범주는 **조직 단위 Premium** 활성화가 필요.
- 【사실: https://pypi.org/project/prowler-cloud/4.5.2 】 Prowler는 Apache 2.0 오픈소스, AWS·GCP·Azure·Kubernetes 지원, 체크 수 AWS 553 / GCP 77 / Azure 138 / Kubernetes 83(4.5.2 기준), 출력은 **OCSF JSON**과 CSV.
- 【사실: 메모리 finals-requirements-spec】 AWS Security Hub는 OCSF 1.6을 표준 finding 형식으로 사용. GCP SCC는 자체 스키마(Pub/Sub·BigQuery·Logging으로 내보냄).
- 【추정】 GCP는 개인 계정(조직 없음)일 가능성이 높아 SCC Premium의 위협 탐지를 못 쓸 수 있다 → Q로 확인하거나, GKE에도 Falco를 깔아 대체.

## 3. 구현 방식 3안

| 안 | 내용 | 장점 | 단점 | 비용·시간 【추정】 |
|---|---|---|---|---|
| **A. 네이티브 수집** | GuardDuty·Security Hub CSPM·SCC를 켜고, 각 finding API를 불러 공통 스키마로 변환 | "진짜 클라우드 보안 서비스를 통합했다"가 심사 문구(p16-17 "GuardDuty, SCC 등을 어떻게 통일·시각화")에 정면으로 맞음 | 서비스마다 규칙이 달라 **"같은 기준"이 아님**. 온프레엔 대응 서비스가 없음. SCC 위협 탐지는 조직 필요. 첫 finding이 나오기까지 시간이 걸릴 수 있음 | 무료 체험으로 5일은 커버 가능, 연동 코드 클라우드당 0.5~1일 |
| **B. 공통 스캐너 하나** | Prowler(AWS·GCP·k8s) + Kyverno + Trivy를 세 환경에 같은 규칙으로 | 같은 체크 ID가 모든 환경에서 평가됨 → FR-SEC-03 "같은 기준"을 가장 확실히 증명. OCSF로 바로 나옴. 클라우드 비용 거의 0 | 위협 탐지(S4)가 빠짐. "GuardDuty·SCC를 통합했나"라는 질문에 약함 | 설치·변환 1일 |
| **C. 섞기 (추천)** | 설정 점검(S5)·취약점(S6)·네트워크(S7) = B 방식, 위협 탐지(S4) = 네이티브(GuardDuty·SCC 가능한 범위) + Falco(온프레·GKE 보완), 감사(S3) = 각 로그 → 플랫폼 | 두 질문("같은 기준인가", "클라우드 서비스를 통합했나") 모두에 답이 있음 | 소스가 많아 변환기가 4~5개 | 2일 (WP2 담당 1명 기준) |

C를 고르는 이유 한 줄: 심사 문구가 "클라우드마다 다른 기능을 어떻게 **통일**하고 **시각화**하나"이므로, 통일(같은 규칙)은 공통 스캐너로, 다른 기능의 존재(네이티브 서비스)는 위협 탐지에서 보여 준다.

## 4. 공통 스키마 — OCSF로 모은다

OCSF(Open Cybersecurity Schema Framework) = 보안 이벤트·finding을 같은 필드로 쓰자는 오픈 표준. AWS Security Hub와 Prowler가 이미 이 형식을 쓰므로, 나머지(SCC, Falco, Kyverno PolicyReport, Trivy)만 변환하면 된다.

우리 플랫폼 DB에 남길 최소 필드 (OCSF Detection/Compliance Finding에서 필요한 것만):

| 필드 | 뜻 | 예 |
|---|---|---|
| `env` | 환경 | aws / gcp / onprem |
| `control_id` | **우리 공통 체크 ID** (매트릭스 키) | SEC-ENC-01 |
| `category` | 매트릭스 4항목 | 암호화 |
| `status` | pass / fail / unknown | fail |
| `severity` | info~critical | high |
| `resource` | 대상 | rds:camellia-db |
| `source` | 어느 도구가 봤나 | prowler / guardduty / scc / falco / kyverno / trivy |
| `evidence_url` | 원본 결과 링크 | 증거 저장소 경로 |
| `observed_at` | 시각 | 2026-11-07T11:02:03Z |

변환기(보안 스캔 핸들러) = 소스별로 원본 → 위 필드. `control_id` 매핑표를 `policies/controls.yaml`에 두고 GitOps로 관리.

## 5. 매트릭스 칸 정의 (빈칸 0을 위해 먼저 정한다)

"같은 기준"이 되려면 **칸마다 무엇을 보면 초록인지**를 미리 고정해야 한다. 아래는 초안 12개 — 팀 회의에서 줄이거나 바꿀 것 (TODO(human)).

| control_id | 항목 | 기준 | AWS 소스 | GCP 소스 | 온프레 소스 |
|---|---|---|---|---|---|
| SEC-IAM-01 | 권한 | 관리자 계정 MFA | Prowler | Prowler | Keycloak 설정 체크 (스크립트) |
| SEC-IAM-02 | 권한 | 와일드카드(*) 권한 0개 | Prowler | Prowler | Kyverno(RBAC `*` 금지) |
| SEC-IAM-03 | 권한 | 앱 Pod가 클러스터 관리자 권한 없음 | Kyverno | Kyverno | Kyverno |
| SEC-ENC-01 | 암호화 | DB 저장 암호화 | Prowler(RDS) | Prowler(Cloud SQL) | 디스크 암호화 체크 (스크립트) |
| SEC-ENC-02 | 암호화 | 외부 노출은 TLS만 | Kyverno(Ingress) | Kyverno | Kyverno |
| SEC-ENC-03 | 암호화 | 시크릿이 코드·이미지에 없음 | Trivy secret 스캔 | Trivy | Trivy |
| SEC-AUD-01 | 감사 | 클라우드 API 감사 로그 켜짐 | Prowler(CloudTrail) | Prowler(Audit Logs) | k8s audit 정책 존재 |
| SEC-AUD-02 | 감사 | 플랫폼 조작 100% 기록 | 플랫폼 감사 테이블 | 같음 | 같음 |
| SEC-VIO-01 | 위반 | 0.0.0.0/0 관리 포트 없음 | Prowler(SG) | Prowler(Firewall) | nftables 체크 |
| SEC-VIO-02 | 위반 | 이미지는 우리 레지스트리 + critical CVE 0 | Kyverno + Trivy | 같음 | 같음 |
| SEC-VIO-03 | 위반 | root 컨테이너 0 | Kyverno | Kyverno | Kyverno |
| SEC-VIO-04 | 위반 | 활성 위협 탐지 0건 | GuardDuty | SCC(가능 범위) 또는 Falco | Falco |

→ 환경 3 × 12칸 = 36칸, 모든 칸에 소스가 있다(빈칸 0, NFR-09).
→ 데모용 "빨간 칸" 1개를 일부러 만든다: 예) GCP에 0.0.0.0/0 SSH 방화벽 → SEC-VIO-01 빨강 → 에이전트가 샌드박스에서 수정안 → 승인 → 초록 (장면 2 → 장면 3 연결, FR-SEC-05).

## 6. 이전 전후 보안 동등성 (FR-SEC-06)

이전 직후 같은 12개 체크를 B에서 다시 돌려 A 결과와 나란히 비교한다. "A에서 초록이던 칸이 B에서 빨강" = 이전이 보안을 떨어뜨렸다는 증거 → 이전 계획 승인 전에 사전 점검(FR-MIG-06)에서 미리 경고.

## 7. 비용·일정 【추정, 계정 생성 전 재확인】

- GuardDuty·Security Hub CSPM: 무료 체험 30일 안에 본선이 끝남(11/1 활성화 → 12/1 전 비활성화). 체험 종료일을 캘린더에 적을 것.
- Prowler·Kyverno·Trivy·Falco: 오픈소스, 비용 0. 실행 자원만.
- AWS Config: 기록 항목 수에 비례해 과금 【미확인: 단가】. Prowler가 대신하므로 **안 켠다**.
- SCC: Standard 범위만 쓰고 Premium은 쓰지 않는다(조직 필요 + 비용).
- 일정: Prowler 실행·변환 0.5일, Kyverno 정책 12개 중 k8s 체크 0.5일, 네이티브 GuardDuty 연동 0.5일, 매트릭스 UI 1일.

## 8. 정직하게 적을 한계

| 항목 | 한계 | 설계 문서에 쓸 문장 |
|---|---|---|
| 위협 탐지 범위 | Falco는 노드 시스템 콜만, GuardDuty는 VPC 흐름·DNS·위협 인텔까지 | "같은 목적(활성 위협), 다른 탐지 범위. 온프레는 네트워크 위협 탐지가 비어 있고 Suricata 등으로 보완 가능" |
| 실시간성 | Prowler는 주기 실행(스냅샷) | "설정 점검은 N분 주기, 위협 탐지는 이벤트 즉시" |
| GCP 위협 탐지 | 조직 없으면 SCC 위협 탐지 대부분 불가 | "개인 프로젝트 제약으로 GKE는 Falco로 대체" |
| 체크 수 | 12개만 매트릭스에 | "Prowler 전체 결과는 근거 보기에서, 매트릭스는 대표 12개" |

## 핵심 결정 3개 (+대안)
1. 보안 수집 방식 = C 섞기 (대안: A 네이티브만 → 같은 기준 증명 약함 / B 스캐너만 → 클라우드 서비스 통합 질문에 약함).
2. 공통 스키마 = OCSF 부분 집합 + 우리 control_id (대안: 자체 스키마 → 표준성 설명 불가 / Security Hub로 전부 모으기 → AWS 종속, 주제 "Lock-In" 반대).
3. 매트릭스 = 12개 control × 3환경, 칸마다 소스 고정 (대안: 서비스가 내는 모든 finding 나열 → 빈칸·불균형, 비교 불가).

## 셀프 연습 1개
- 5절 표에서 SEC-VIO-04(활성 위협 0건)의 온프레 소스를 Falco로 했다. Falco 기본 규칙 중 "컨테이너 안에서 셸 실행"을 데모용 빨간 칸으로 만들려면 어떤 행동을 하면 되는지 한 줄로 적어 보기.

## 검증 명령과 기대 출력 (로컬, AWS 리소스 생성 없음)
```bash
# Prowler를 k8s(로컬 kind)에 돌려 OCSF 출력 확인
pip install prowler                         # 또는 pipx
prowler kubernetes --output-formats json-ocsf
ls output/*.ocsf.json                        # 기대: 파일 1개, 안에 "class_name": "Detection Finding" 등 OCSF 필드
# Trivy 이미지 스캔
trivy image --format json nginx:latest | jq '.Results[].Vulnerabilities | length'   # 기대: 숫자 (CVE 개수)
```
(AWS·GCP 대상 Prowler 실행은 읽기 전용이지만 계정 자격 증명이 필요하므로 로컬 세션에서 Jeong 승인 후.)
