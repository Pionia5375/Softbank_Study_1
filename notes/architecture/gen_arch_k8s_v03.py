# -*- coding: utf-8 -*-
"""본선 아키텍처 v0.3-k8s 다이어그램 생성기 (camellia v5.5 SVG 스타일을 따름)."""
import html

W, H = 1900, 2850
out = []
def E(s): out.append(s)
def t(x, y, cls, s, anchor=None, extra=""):
    a = f' text-anchor="{anchor}"' if anchor else ""
    E(f'<text x="{x}" y="{y}" class="{cls}"{a}{extra}>{html.escape(s)}</text>')

def tw(s, fs):
    return sum((fs * 0.98 if ord(c) > 0x2E7F else fs * 0.56) for c in s)

BADGE = {"MUST": "bm", "EXTRA": "bx", "예선": "bp", "신규": "bn", "결정": "bq"}
def badge(x, y, kind):
    w = {"MUST": 46, "EXTRA": 50, "예선": 40, "신규": 40, "결정": 62}[kind]
    label = {"결정": "TODO(h)"}.get(kind, kind)
    E(f'<rect x="{x}" y="{y}" width="{w}" height="20" rx="10" class="{BADGE[kind]}"/>')
    t(x + w / 2, y + 14.5, "newt", label, "middle")
    return x + w + 6

def card(x, y, w, h, title, lines, badges=(), cls="card", tag=None, ttl="ttl"):
    E(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="12" class="{cls}"/>')
    t(x + 22, y + 38, ttl, title)
    bx = x + 22 + tw(title, 19 if ttl == "ttl" else 16) + 12
    for b in badges:
        bx = badge(bx, y + 22, b)
    if tag:
        t(x + w - 20, y + h - 14, "tag", tag, "end")
    yy = y + 68
    for ln in lines:
        cls2 = "sub"
        if ln.startswith("!"):
            cls2, ln = "subd", ln[1:]
        if ln.startswith("?"):
            cls2, ln = "qt", ln[1:]
        t(x + 22, yy, cls2, ln)
        yy += 25

def env(x, y, w, h, code, bd, title, badges, head, cols):
    E(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="14" class="env env-{bd}"/>')
    E(f'<rect x="{x+22}" y="{y+24}" width="56" height="30" rx="7" class="bd-{bd}"/>')
    t(x + 50, y + 44, "bdt", code, "middle")
    t(x + 92, y + 47, "ttl", title)
    bx = x + 92 + tw(title, 19) + 12
    for b in badges:
        bx = badge(bx, y + 31, b)
    t(x + 22, y + 86, "pt", head)
    cw = (w - 44) / len(cols)
    for ci, col in enumerate(cols):
        cx = x + 22 + ci * cw
        yy = y + 118
        for ln in col:
            if ln.startswith("#"):
                t(cx, yy, "lbl", ln[1:], extra=f' fill="var(--{bd})"')
            else:
                E(f'<circle cx="{cx+6}" cy="{yy-5}" r="3.2" class="dot-{bd}"/>')
                t(cx + 18, yy, "sub", ln)
            yy += 26

def arrow(d, cls, start=False, end=True):
    ms = f' marker-start="url(#m-{cls})"' if start else ""
    me = f' marker-end="url(#m-{cls})"' if end else ""
    E(f'<path d="{d}" class="{cls}"{ms}{me}/>')

def label(x, y, s, w=None):
    w = w or len(s) * 13.6 + 16
    E(f'<rect x="{x - w/2}" y="{y - 18}" width="{w}" height="26" rx="4" class="bg"/>')
    t(x, y, "lbl", s, "middle")

# ---------- header ----------
E(f'<rect width="{W}" height="{H}" class="bg"/>')
t(48, 70, "h1", "멀티 클라우드 관리 플랫폼 — 본선 아키텍처 v0.3-k8s")
t(48, 106, "h2", "운영 모델 A: 고객 계정은 고객 것 · 플랫폼은 역할만 빌림 | 실환경 AWS · GCP · 온프레 + Azure 어댑터(Mock) | 멀티 테넌트 | 2026-10-30 인터뷰 반영")

legend = [
    (980, 52, "e-api", "API 호출 (HTTPS · SSE)"), (980, 86, "e-prov", "GitOps 동기화 (Argo CD)"),
    (980, 120, "e-obs", "관측 데이터 (OTel)"), (1280, 52, "e-async", "비동기 작업 (Postgres 큐)"),
    (1280, 86, "e-user", "사용자 트래픽"), (1280, 120, "e-sync", "데이터 복제"),
]
for x, y, cls, s in legend:
    E(f'<line x1="{x}" y1="{y}" x2="{x+50}" y2="{y}" class="{cls}"/>')
    t(x + 66, y + 5, "leg", s)
bl = [(1580, 42, "MUST", "데모 필수 3장면 (먼저 완주)"), (1580, 70, "EXTRA", "시간 남으면 · 설계 문서로 커버"),
      (1580, 98, "예선", "camellia에서 가져옴"), (1580, 126, "신규", "본선에서 새로 만듦")]
for x, y, k, s in bl:
    badge(x, y, k)
    t(x + 72, y + 15, "leg", s)
badge(1200, 142, "결정"); t(1272, 157, "leg", "팀이 정할 결정 (인터뷰 Q)")

# ---------- left entry ----------
card(48, 180, 310, 150, "웹 콘솔", ["환경 목록 · 상태 일원 화면 (FR-BASE-04)", "이전 계획 · 승인 · 진행 · 롤백 버튼", "보안 매트릭스 · 에이전트 승인 화면"], ["MUST", "예선"])
card(48, 348, 310, 120, "CLI · CI", ["PR → kubeconform · Kyverno CLI · Trivy", "앱 레포 push → 이미지 태그 → GitOps 레포"], ["EXTRA"], cls="optc")
card(48, 486, 310, 120, "조직 · 역할", ["사용자 = 조직(테넌트) 소속", "admin · approver · viewer는 조직 안에서만"], ["MUST", "신규"])
card(48, 624, 310, 250, "고객 환경 연결", [
    "!AWS: 원클릭 템플릿(CloudFormation)",
    "→ observe(읽기) · operate(변경) 역할",
    "ExternalId 미리 채움 · 고객이 승인",
    "GCP: 서비스 계정 impersonation",
    "온프레: Agent 설치 한 줄 (예선)",
    "플랫폼은 키 저장 0 · 이전 후 회수",
    "!확정: 원클릭 + 계정 ID 검증",
], ["MUST", "신규"])
for y in (205, 373, 511, 649):
    E(f'<line x1="358" y1="{y}" x2="380" y2="{y}" class="e-api"/>')
E('<line x1="380" y1="205" x2="380" y2="649" class="e-api"/>')

# ---------- control plane ----------
E('<rect x="405" y="170" width="940" height="1250" rx="18" class="cp"/>')
t(439, 212, "cpt", "컨트롤 플레인 (플랫폼 계정 · 관리 EKS)")
t(1315, 212, "lbl", "api · worker · web = Deployment · Argo CD 허브", "end")

card(440, 232, 870, 150, "API 서버 + 오케스트레이터", [
    "Fastify + Zod + pg-boss · REST · SSE · 상태: import → plan → precheck → sync → shift → cutover → cleanup | rollback",
    "실제 변경은 kubectl 아님 → GitOps 레포 커밋 → Argo CD 동기화 (변경 이력 = git log)",
    "모든 요청에 tenant_id · 감사 로그(FR-BASE-07) · 고객 계정 호출은 세션 이름에 tenant 표시",
], ["MUST", "예선"], tag="API · STM · LCK · AUD")
arrow("M380 257 L436 257", "e-api")

card(440, 412, 420, 200, "가져오기 + 이전 플래너", [
    "!가져오기: 출발 환경의 앱·LB·DB 설정을 읽기만 함",
    "AI가 초안 → 확신 낮은 칸 표시 → 사람 확인 → Helm values",
    "사전 점검: 대상에 대응 없는 서비스·버전·권한 (FR-MIG-06)",
    "계획: 단계·예상 시간·롤백 조건 → 승인 후 실행 (FR-MIG-07)",
    "!확정: 컨테이너 + k8s · TF 장부는 확장 지점",
], ["MUST", "신규"], tag="IMP · PLN · CHK")
card(890, 412, 420, 200, "AI 에이전트 (플랫폼 통합)", [
    "입력: Kyverno 위반 · 이전 계획 · 매니페스트 diff",
    "행동: vcluster 샌드박스에서 매니페스트·코드 수정 → 테스트",
    "권한: 샌드박스 쓰기 · 프로덕션 읽기 · 반영은 사람 (FR-AGT-06)",
    "출력: GitOps 레포 PR (근거 · diff · 테스트) → 승인 (FR-AGT-08)",
    "!확정: 자체 도구 루프 (좁은 도구 4~5개)",
], ["MUST", "신규"], cls="agent", tag="AGT · SBX")
arrow("M650 382 L650 408", "e-api"); arrow("M1100 382 L1100 408", "e-api")

card(440, 640, 420, 176, "보안 수집기 (같은 기준)", [
    "점검: Kyverno · Prowler · Trivy = 같은 통제 ID",
    "위협: GuardDuty·SCC·Defender → OCSF (Falco EXTRA)",
    "매트릭스: 통제 12개 × 환경 3개(+Azure Mock), 빈칸 0",
    "!확정: 데모 2곳 실제로 켬 (GuardDuty·SCC)",
], ["MUST", "신규"], tag="SEC · POL")
card(890, 640, 420, 176, "환경 추상화 (Helm)", [
    "앱 = Helm chart 하나 · values-aws/gcp/azure/onprem",
    "테넌트마다 AppProject: 자기 레포·클러스터에만 배포",
    "Helm = k8s 층 · Terraform = 클라우드 층(VPC·클러스터·DB)",
    "?가정: 데모 = AWS ECS → GCP GKE (팀 확정)",
], ["MUST", "예선"], tag="IR · PRF · ADP")
arrow("M650 612 L650 636", "e-api"); arrow("M1100 612 L1100 636", "e-api")

# worker pool
E('<rect x="425" y="846" width="900" height="548" rx="14" class="pool"/>')
t(450, 878, "stt", "통합 워커 (Postgres 큐 · 교체 가능한 enqueue/consume 인터페이스)")
t(1315, 878, "lbl", "멱등 · 테넌트별 동시 실행 상한 · 폴링은 큐 밖", "end")
card(445, 898, 410, 230, "이전 핸들러", [
    "1 deploy: Terraform 기반 → B 라벨 추가 → Argo sync",
    "2 sync: DB 복제 시작 → lag 0 확인 (FR-MIG-02)",
    "3 shift: Cloudflare 가중치 10 → 50 → 100 % (클러스터 간)",
    "4 cutover: 쓰기 전환 · 출발 DB 읽기 전용 · 헬스 후",
    "5 measure: 실패 요청 수 · 전환 시각 자동 기록 (FR-OBS-04)",
    "!클러스터 안 = Argo · 클러스터 사이 = 우리 워커",
], ["MUST", "예선"], tag="MIG")
card(895, 898, 410, 230, "롤백 핸들러", [
    "버전 롤백: Argo Rollouts 카나리 + AnalysisTemplate",
    "환경 롤백: 에러율 · p95 초과 → 출발 100 %",
    "목표: 장애 주입 → 60초 안에 복귀 (NFR-05)",
    "!두 층: 클러스터 안(도구) / 클러스터 사이(직접)",
    "제약: stateful이면 복제 방향 되돌린 뒤에만 쓰기 허용",
    "!확정: 5xx > 1% 또는 p95 > 출발 2배, 30초 창",
], ["MUST", "예선"], tag="RBK")
card(445, 1148, 410, 226, "보안 스캔 핸들러", [
    "PolicyReport · Trivy 결과 주기 수집 → 공통 스키마",
    "이전 전후 보안 동등성 비교 출발 vs 도착 (FR-SEC-06)",
    "빨간 칸 → 에이전트 수정안 작업 생성 (FR-SEC-05)",
    "온프레 k3s도 같은 Kyverno → 매트릭스 행 (FR-SEC-04)",
], ["MUST", "신규"], tag="SCN")
card(895, 1148, 410, 226, "에이전트 작업 핸들러 (샌드박스)", [
    "vcluster 생성 → 에이전트 실행 → 테스트·Kyverno 게이트",
    "통과 + 사람 승인 → GitOps PR 머지 (FR-AGT-03)",
    "실패 1건 차단 · 성공 1건 반영, 둘 다 기록",
    "실행 1회 ≤ 60초 목표 (NFR-19)",
    "!확정: 1단계 vCluster · 2단계 plan만",
], ["MUST", "신규"], cls="agent", tag="SBX")
arrow("M1310 330 L1328 330 L1328 926 L1330 926", "e-async")

# ---------- right stores ----------
stores = [
    ("Postgres (플랫폼)", ["상태 · 측정표 · 감사 로그 + 작업 큐(pg-boss)", "모든 테이블 tenant_id + 행 수준 보안(RLS)", "Multi-AZ · PgBouncer · 한계는 부하 테스트로 측정"], ["MUST", "예선"], "st-pg"),
    ("증거 저장소 (오브젝트)", ["단계 로그 · 스캔 결과 · 에이전트 diff · 테스트 출력", "데모 직후 ‘근거 보기’ 링크의 원천"], ["MUST", "신규"], "st-ob"),
    ("IaC State (Terraform 장부)", ["S3 · use_lockfile 잠금 · 버전 관리 (예선)", "경로 tfstate/<tenant>/<env> · 암호화", "드리프트 점검: 주기적 plan만 (EXTRA)"], ["MUST", "예선"], "st-ob"),
    ("시크릿 (External Secrets)", ["값은 고객 저장소에 그대로 · 플랫폼은 이름만", "ESO: Secrets Manager·Secret Manager·Key Vault·Vault"], ["MUST", "신규"], "st-vt"),
    ("LLM API", ["Anthropic 직접 또는 Bedrock (AI_PROVIDER 한 곳, 예선)", "AI 리소스 현황: 모델·리전·호출량·비용 (FR-AIR-01)"], ["MUST", "예선"], "st-ai"),
    ("레지스트리 · 고정 진입점", ["GHCR 하나: 같은 digest를 모든 클러스터 pull", "Cloudflare LB: URL 불변 · 클러스터 간 가중치"], ["MUST", "예선"], "st-rg"),
    ("GitOps 레포 (원천)", ["Helm values · ApplicationSet · Kyverno 정책", "모든 변경 = PR, Argo CD가 당겨 감(pull)", "테넌트별 폴더 + AppProject로 범위 제한"], ["MUST", "신규"], "st-rg"),
]
y = 180
for title, lines, bd, cls in stores:
    card(1392, y, 464, 155, title, lines, bd, cls=cls)
    E(f'<line x1="1368" y1="{y+77}" x2="1392" y2="{y+77}" class="e-api"/>')
    y += 171
E('<line x1="1368" y1="257" x2="1368" y2="1283" class="e-api"/>')
E('<line x1="1310" y1="257" x2="1368" y2="257" class="e-api"/>')
E('<line x1="1325" y1="1283" x2="1368" y2="1283" class="e-api"/>')

# ---------- data plane ----------
t(48, 1500, "cpt", "데이터 플레인")
t(48, 1530, "sub", "컨트롤이 멈춰도 앱은 계속 동작")
card(48, 1550, 310, 84, "앱 사용자 · 심사위원", ["URL 하나: app.<domain> (이전 전후 동일)"], ttl="ttl")
arrow("M203 1634 L203 1660", "e-user")
card(48, 1664, 310, 176, "트래픽 전환", [
    "Cloudflare LB → 각 클러스터 Ingress",
    "단계마다 에러율 · p95 확인 후 승격",
    "헬스체크 통과 후에만 전환 (FR-MIG-09)",
    "!확정: Cloudflare LB 가중치 (Q2)",
], ["MUST", "예선"])
arrow("M358 1724 L401 1724", "e-user")

ENV_Y = 1470
def env4(x, code, bd, title, badges, head, rows, w=347, cls=None, q=None):
    E(f'<rect x="{x}" y="{ENV_Y}" width="{w}" height="330" rx="14" class="{cls or "env env-" + bd}"/>')
    E(f'<rect x="{x+18}" y="{ENV_Y+22}" width="48" height="30" rx="7" class="bd-{bd}"/>')
    t(x + 42, ENV_Y + 42, "bdt", code, "middle")
    t(x + 78, ENV_Y + 45, "ttl", title)
    bx = x + 78 + tw(title, 19) * 1.25 + 14
    for bb in badges:
        bx = badge(bx, ENV_Y + 29, bb)
    t(x + 18, ENV_Y + 84, "pt", head)
    for i, (k, v) in enumerate(rows):
        yy = ENV_Y + 116 + i * 26
        t(x + 18, yy, "lbl", k, extra=f' fill="var(--{bd})"')
        t(x + 88, yy, "sub", v)
    if q:
        t(x + 18, ENV_Y + 308, "qt", q)

ENV = [
    (405, "AWS", "aws", "AWS", ["MUST", "신규"], "예: 출발 (고객이 이미 운영 중)", [
        ("앱", "ECS·ALB (출발) / EKS (도착)"), ("DB", "RDS PostgreSQL"), ("보안", "GuardDuty · Security Hub"),
        ("감사", "CloudTrail"), ("시크릿", "Secrets Manager"), ("연결", "CloudFormation → AssumeRole"), ("점검", "Prowler · Kyverno · Trivy")], None),
    (773, "GCP", "gcp", "GCP", ["MUST", "신규"], "예: 도착 (operate 역할로 생성)", [
        ("앱", "Cloud Run (출발) / GKE (도착)"), ("DB", "Cloud SQL PostgreSQL"), ("보안", "SCC"),
        ("감사", "Cloud Audit Logs"), ("시크릿", "Secret Manager"), ("연결", "SA impersonation · WIF"), ("점검", "Prowler · Kyverno · Trivy")], None),
]
for x, code, bd, title, bdg, head, rows, q in ENV:
    env4(x, code, bd, title, bdg, head, rows)
env4(1141, "ON", "on", "온프레", ["MUST", "신규"], "노트북 VM · k3s 1노드 · Tunnel로 등록", [
    ("앱", "Compose (출발) / k3s (도착)"), ("DB", "CloudNativePG + 백업"), ("보안", "kube-bench · Falco(EXTRA)"),
    ("감사", "k8s audit log"), ("시크릿", "Vault (ESO)"), ("연결", "Agent 설치 한 줄 (예선)"), ("점검", "kube-bench · Kyverno")],
    q="결정: FR-ONP 6개 중 어디까지 MUST")
env4(1509, "AZ", "az", "Azure", ["EXTRA", "신규"], "어댑터 코드 + Mock 응답 (실계정 X)", [
        ("앱", "Container Apps / AKS"), ("DB", "Azure DB for PostgreSQL"), ("보안", "Defender for Cloud"),
        ("감사", "Activity Log"), ("시크릿", "Key Vault"), ("연결", "ARM 템플릿 → Lighthouse"), ("검증", "계약 테스트 (녹화 응답)")],
    cls="optc", q="화면엔 'Mock' 표시 · 데모 경로 아님")

# provisioning arrows from worker to envs
E('<path d="M650 1394 L650 1440" class="e-prov"/>')
E('<line x1="578" y1="1440" x2="1314" y2="1440" class="e-prov"/>')
for x in (578, 946, 1314):
    arrow(f"M{x} 1440 L{x} {ENV_Y-4}", "e-prov")
label(1130, 1450, "operate 역할: Terraform = 클라우드 층 → Argo CD = k8s 층 (어느 환경이든 같은 방식)")
# data replication source -> target
arrow(f"M752 {ENV_Y+200} L769 {ENV_Y+200}", "e-sync")
label(762, ENV_Y + 356, "DB 논리 복제 출발 → 도착 (RPO 0)", 300)
# user traffic to envs
arrow(f"M203 1840 L203 1860 L578 1860 L578 {ENV_Y+334}", "e-user")
arrow(f"M203 1860 L946 1860 L946 {ENV_Y+334}", "e-user")
label(1180, 1878, "가중치 전환 중 출발·도착 동시 서빙 → 실패 요청 0건 측정 (NFR-01)", 560)

# ---------- sandbox strip ----------
SB = 1900
E(f'<rect x="405" y="{SB}" width="1451" height="150" rx="14" class="agent" style="stroke-dasharray:6 4"/>')
t(431, SB + 40, "ttl", "샌드박스 (플랫폼 소유 · 단계별)")
badge(800, SB + 24, "MUST"); badge(852, SB + 24, "신규")
t(1832, SB + 38, "lbl", "관리 EKS + 3사 샌드박스 계정 = 플랫폼 것 · 고객 수고 0 · 반영은 승인 → PR", "end")
for i, (ttl_, s) in enumerate([("1 k8s 층 · MUST", "vCluster: 매니페스트·Helm 수정 → Kyverno"),
                               ("2 클라우드 층 · MUST", "plan + 정적 점검만 (실제로 안 띄움)"),
                               ("3 전체 재현 · EXTRA", "도착 1곳: 이전 모듈을 샌드박스 계정에"),
                               ("4 3사 전체 재현", "설계 문서만 (시간·비용 문제)")]):
    x = 431 + i * 356
    E(f'<rect x="{x}" y="{SB+58}" width="340" height="74" rx="12" class="card"/>')
    t(x + 18, SB + 86, "ttl-s", ttl_)
    t(x + 18, SB + 112, "sub", s)
arrow(f"M1100 1374 L1100 1400 L1880 1400 L1880 {SB+75} L1860 {SB+75}", "e-gate")
label(1760, 1412, "에이전트 작업 → 샌드박스", 220)

# ---------- observability ----------
OB = 2080
E(f'<rect x="405" y="{OB}" width="1451" height="150" rx="14" class="obsc" style="stroke-dasharray:6 4"/>')
t(431, OB + 40, "ttl", "횡단 관측 · 이전 측정 (OpenTelemetry)")
badge(830, OB + 24, "MUST"); badge(882, OB + 24, "신규")
t(1832, OB + 38, "lbl", "이전 1회마다 자동 표: 시작·단계·컷오버·롤백 시각 · 실패 요청 수 · 복제 lag (FR-OBS-04)", "end")
for i, (ttl_, s) in enumerate([("OTel Operator", "모든 클러스터 자동 계측 · env 라벨"),
                               ("Prometheus", "Rollouts 분석 + 클러스터 간 롤백 입력"),
                               ("Grafana", "한 그래프에 A·B 선 교차 (FR-OBS-01)"),
                               ("OpenCost", "클러스터별 비용 · 50만 원 예산 (EXTRA)")]):
    x = 431 + i * 356
    E(f'<rect x="{x}" y="{OB+58}" width="340" height="74" rx="12" class="card"/>')
    t(x + 18, OB + 86, "ttl-s", ttl_)
    t(x + 18, OB + 112, "sub", s)
for x in (640, 1132, 1620):
    arrow(f"M{x} {ENV_Y+330} L{x} {ENV_Y+360} L{x+40} {ENV_Y+360}", "e-obs", end=False) if False else None
arrow(f"M412 {ENV_Y+330} L412 {OB-4}", "e-obs")
t(48, OB + 40, "cpt", "관측 · 측정")
t(48, OB + 72, "sub", "숫자가 곧 심사 근거:")
t(48, OB + 96, "sub", "실패 요청 0 · p95 ≤ 2배 · RPO 0")
t(48, OB + 120, "sub", "롤백 ≤ 60초 · 이전 ≤ 90초")

# ---------- principles strip ----------
FL = 2260
E(f'<rect x="48" y="{FL}" width="1808" height="180" rx="14" class="strip"/>')
t(72, FL + 38, "cpt", "이전 흐름 9단계 (장면 1)")
t(1832, FL + 36, "lbl", "1~3 = 읽기만(observe) · 4~9 = 승인 후 operate · 실패하면 어느 단계든 출발 환경으로 롤백", "end")
STEPS = [("1 연결", "원클릭 템플릿", "역할 2개 생성"), ("2 가져오기", "출발 환경 읽기", "AI 초안 → 사람 확인"),
         ("3 계획·점검", "precheck · plan", "approver 승인"), ("4 기반 생성", "Terraform", "VPC·클러스터·DB"),
         ("5 배포", "Helm values", "Kyverno → Argo sync"), ("6 DB 복제", "출발 DB → 도착 DB", "lag 0 확인"),
         ("7 전환", "10 → 50 → 100 %", "이상 시 자동 롤백"), ("8 컷오버", "쓰기 전환", "실패 요청 수 기록"),
         ("9 정리", "출발 축소·삭제", "operate 역할 회수")]
for i, (a, b, c) in enumerate(STEPS):
    x = 72 + i * 196
    E(f'<rect x="{x}" y="{FL+58}" width="184" height="100" rx="12" class="card"/>')
    t(x + 14, FL + 86, "ttl-s", a)
    t(x + 14, FL + 112, "sub", b)
    t(x + 14, FL + 136, "sub", c)
    if i < 8:
        arrow(f"M{x+186} {FL+108} L{x+194} {FL+108}", "e-api")

TN = 2470
E(f'<rect x="48" y="{TN}" width="1808" height="180" rx="14" class="strip"/>')
t(72, TN + 38, "cpt", "멀티 테넌트 격리")
badge(272, TN + 22, "MUST"); badge(324, TN + 22, "신규")
t(1832, TN + 36, "lbl", "가장 큰 위험 = worker 하나가 모든 고객 역할을 빌림 → 작업의 tenant 역할만 · 짧은 세션 · 장기는 셀 구조", "end")
TEN = [("데이터", "tenant_id + RLS", "쿼리 실수도 DB가 막음"), ("사용자", "조직 소속 · 역할", "A로 로그인 → B 안 보임"),
       ("고객 계정", "고객별 ExternalId", "세션 이름에 tenant"), ("작업 큐", "테넌트별 상한", "한 고객이 독점 못 함"),
       ("배포", "Argo AppProject", "자기 클러스터만"), ("장부·샌드박스", "경로·라벨·할당량", "고객별 KMS = EXTRA")]
for i, (a, b, c) in enumerate(TEN):
    x = 72 + i * 295
    E(f'<rect x="{x}" y="{TN+58}" width="280" height="100" rx="12" class="card"/>')
    t(x + 16, TN + 86, "ttl-s", a)
    t(x + 16, TN + 112, "sub", b)
    t(x + 16, TN + 136, "sub", c)

PR = 2680
E(f'<rect x="405" y="{PR}" width="1451" height="130" rx="14" class="strip"/>')
t(48, PR + 40, "cpt", "데모 3장면 ↔ 구성")
t(48, PR + 72, "sub", "장면 1: 이전 → 진입점·이전·롤백")
t(48, PR + 96, "sub", "장면 2: 보안 → 수집기·매트릭스")
t(48, PR + 120, "sub", "장면 3: 에이전트 → 샌드박스")
cols = [
    ("v0.2 → v0.3 바뀐 것", "멀티 테넌트 격리(RLS·AppProject·큐 상한) · 큐는 Postgres 유지 + 교체 인터페이스 + 부하 측정 · 장부 경로 테넌트별 · 샌드박스 단계별"),
    ("k8s로 공짜로 얻는 것", "카나리·자동 롤백(Rollouts) · 같은 정책(Kyverno) · vcluster 샌드박스 · GitOps 이력 · OTel Operator"),
    ("대신 치르는 비용", "클러스터 3개 운영(EKS·GKE·k3s) · 예선 배포 엔진 대부분 폐기 · EKS·GKE 비용 · 노트북 메모리 · 팀원 k8s 숙련도"),
]
for i, (h, s) in enumerate(cols):
    x = 435 + i * 483
    t(x, PR + 46, "stt", h)
    lines_, cur = [], ""
    for w_ in s.split(" "):
        if len(cur) + len(w_) + 1 > 46 and cur:
            lines_.append(cur); cur = w_
        else:
            cur = (cur + " " + w_).strip()
    lines_.append(cur)
    for j, chunk in enumerate(lines_):
        if chunk.strip():
            t(x, PR + 74 + j * 22, "sub", chunk.strip())

svg = "\n".join(out)
STYLE = """
:root{--bg:#F6F8FA;--card:#FFFFFF;--line:#D5DBE3;--text:#1C2430;--muted:#5E6B7A;--edge:#7C8896;
--cp-fill:#EFF6F2;--cp-line:#7DB596;--cp-text:#2F7A55;--pool:#9AA7B5;
--ag-fill:#F3F0FD;--ag-line:#A99BE6;--async:#7B61D9;--prov:#D9731A;--user:#2F6FD1;--sync:#B4327A;
--pg-f:#EEF3FB;--pg-l:#BCCDEA;--ob-f:#F2F4F6;--ob-l:#D2D8DF;--vt-f:#FBF4E6;--vt-l:#E4CC9C;--ai-f:#F3F0FD;--ai-l:#CFC5F1;--rg-f:#EEF6F1;--rg-l:#BCDAC8;
--on:#5B6B7F;--obs:#1F9E89;--obs-f:#EAF6F4;--obs-l:#9FD3C8;--aws:#E07A1F;--gcp:#3B7BE0;--az:#0E8FB0;--strip:#FFFFFF;
--gate:#C98A12;--must:#2F7A55;--extra:#8A95A3;--prelim:#2F6FD1;--new:#C98A12;--q:#B4327A;
--font:'IBM Plex Sans KR','Apple SD Gothic Neo','Malgun Gothic','Noto Sans KR',system-ui,sans-serif;--mono:'IBM Plex Mono','DejaVu Sans Mono',monospace}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--bg:#13181F;--card:#1B222B;--line:#2E3843;--text:#E6ECF2;--muted:#A3AFBC;--edge:#8A96A4;
--cp-fill:#17221C;--cp-line:#4E8A68;--cp-text:#7CC79C;--pool:#5E6B7A;--ag-fill:#201C30;--ag-line:#6F62B0;--async:#A28FF0;--prov:#F0944A;--user:#6C9CF0;--sync:#E06AAE;
--pg-f:#1A2230;--pg-l:#3A4E6C;--ob-f:#1C2229;--ob-l:#3A444F;--vt-f:#2A2418;--vt-l:#7A6436;--ai-f:#221E33;--ai-l:#5E5490;--rg-f:#172219;--rg-l:#3C6B4C;
--on:#8E9DB0;--obs:#3FC9AF;--obs-f:#15261F;--obs-l:#2E6B5B;--aws:#F0944A;--gcp:#6C9CF0;--az:#3CC4CF;--strip:#1B222B;--gate:#E0A838;--must:#4FA574;--extra:#6B7684;--prelim:#6C9CF0;--new:#E0A838;--q:#E06AAE;color-scheme:dark}}
:root[data-theme="dark"]{--bg:#13181F;--card:#1B222B;--line:#2E3843;--text:#E6ECF2;--muted:#A3AFBC;--edge:#8A96A4;
--cp-fill:#17221C;--cp-line:#4E8A68;--cp-text:#7CC79C;--pool:#5E6B7A;--ag-fill:#201C30;--ag-line:#6F62B0;--async:#A28FF0;--prov:#F0944A;--user:#6C9CF0;--sync:#E06AAE;
--pg-f:#1A2230;--pg-l:#3A4E6C;--ob-f:#1C2229;--ob-l:#3A444F;--vt-f:#2A2418;--vt-l:#7A6436;--ai-f:#221E33;--ai-l:#5E5490;--rg-f:#172219;--rg-l:#3C6B4C;
--on:#8E9DB0;--obs:#3FC9AF;--obs-f:#15261F;--obs-l:#2E6B5B;--aws:#F0944A;--gcp:#6C9CF0;--az:#3CC4CF;--strip:#1B222B;--gate:#E0A838;--must:#4FA574;--extra:#6B7684;--prelim:#6C9CF0;--new:#E0A838;--q:#E06AAE;color-scheme:dark}
body{background:var(--bg);color:var(--text);font-family:var(--font);margin:0}
.wrap{padding-block:12px 24px;padding-left:max(16px,env(safe-area-inset-left,0px));padding-right:max(16px,env(safe-area-inset-right,0px))}
.bar{display:flex;flex-wrap:wrap;gap:8px 16px;align-items:center;font-size:13px;color:var(--muted);margin-bottom:8px}
.bar b{color:var(--text)}
.bar button{font:inherit;color:var(--text);background:var(--card);border:1px solid var(--line);border-radius:8px;padding:4px 10px;cursor:pointer}
.bar button:focus-visible{outline:2px solid var(--cp-line);outline-offset:2px}
.scroll{overflow:auto;border:1px solid var(--line);border-radius:12px;background:var(--bg)}
svg{display:block;min-width:1900px;font-family:var(--font)}
.bg{fill:var(--bg)}.card{fill:var(--card);stroke:var(--line);stroke-width:1}
.agent{fill:var(--ag-fill);stroke:var(--ag-line);stroke-width:1.5}
.st-pg{fill:var(--pg-f);stroke:var(--pg-l)}.st-ob{fill:var(--ob-f);stroke:var(--ob-l)}.st-vt{fill:var(--vt-f);stroke:var(--vt-l)}.st-ai{fill:var(--ai-f);stroke:var(--ai-l)}.st-rg{fill:var(--rg-f);stroke:var(--rg-l)}
.cp{fill:var(--cp-fill);stroke:var(--cp-line);stroke-width:1.5;stroke-dasharray:7 6}
.pool{fill:none;stroke:var(--pool);stroke-width:1.2;stroke-dasharray:5 5}
.env{fill:var(--card);stroke-width:1.5}.env-on{stroke:var(--on)}.env-aws{stroke:var(--aws)}.env-gcp{stroke:var(--gcp)}.env-az{stroke:var(--az)}
.bd-on{fill:var(--on)}.bd-aws{fill:var(--aws)}.bd-gcp{fill:var(--gcp)}.bd-az{fill:var(--az)}
.dot-on{fill:var(--on)}.dot-aws{fill:var(--aws)}.dot-gcp{fill:var(--gcp)}
.strip{fill:var(--strip);stroke:var(--line)}.obsc{fill:var(--obs-f);stroke:var(--obs-l)}
.optc{fill:var(--card);stroke:var(--pool);stroke-width:1.3;stroke-dasharray:6 4}
.bm{fill:var(--must)}.bx{fill:var(--extra)}.bp{fill:var(--prelim)}.bn{fill:var(--new)}.bq{fill:var(--q)}
.h1{font-size:34px;font-weight:700;fill:var(--text)}.h2{font-size:16px;fill:var(--muted)}
.ttl{font-size:19px;font-weight:700;fill:var(--text)}.ttl-s{font-size:16px;font-weight:700;fill:var(--text)}
.sub{font-size:14.5px;fill:var(--muted)}.subd{font-size:14.5px;fill:var(--text);font-weight:700}
.qt{font-size:14.5px;fill:var(--q);font-weight:700}
.tag{font-size:13px;fill:var(--muted);font-weight:700}.cpt{font-size:22px;font-weight:700;fill:var(--cp-text)}
.pt{font-size:14.5px;font-weight:700;fill:var(--muted)}.stt{font-size:17px;font-weight:700;fill:var(--cp-text)}
.lbl{font-size:13.5px;fill:var(--muted);font-weight:700}.leg{font-size:14.5px;fill:var(--muted)}
.bdt{font-size:12.5px;font-weight:700;fill:#fff}.newt{font-size:11px;font-weight:700;fill:#fff;letter-spacing:.04em}
.e-api{stroke:var(--edge);stroke-width:1.5;fill:none}.e-async{stroke:var(--async);stroke-width:1.6;stroke-dasharray:6 4;fill:none}
.e-prov{stroke:var(--prov);stroke-width:2;fill:none}.e-user{stroke:var(--user);stroke-width:2;fill:none}
.e-obs{stroke:var(--obs);stroke-width:1.8;stroke-dasharray:3 3;fill:none}.e-gate{stroke:var(--gate);stroke-width:2;fill:none}
.e-sync{stroke:var(--sync);stroke-width:2.2;stroke-dasharray:8 4;fill:none}
.mk-e-obs{fill:var(--obs)}.mk-e-api{fill:var(--edge)}.mk-e-async{fill:var(--async)}.mk-e-prov{fill:var(--prov)}.mk-e-user{fill:var(--user)}.mk-e-gate{fill:var(--gate)}.mk-e-sync{fill:var(--sync)}
"""
markers = "".join(
    f'<marker id="m-{c}" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M1 1L9 5L1 9z" class="mk-{c}"/></marker>'
    for c in ["e-api", "e-async", "e-prov", "e-user", "e-obs", "e-gate", "e-sync"])

page = f"""<title>본선 아키텍처 v0.3-k8s</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans+KR:wght@400;700&display=swap">
<style>{STYLE}</style>
<div class="wrap">
<div class="bar"><b>Beyond Lock-In · 아키텍처 v0.3-k8s</b><span>가로로 긴 그림이라 옆으로 스크롤해서 봐. 분홍 <b>TODO(h)</b>가 팀이 정할 지점.</span>
<button id="zoom-out" type="button">축소</button><button id="zoom-in" type="button">확대</button><button id="zoom-fit" type="button">폭 맞춤</button></div>
<div class="scroll" id="scroll"><svg id="dg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" xmlns="http://www.w3.org/2000/svg"><defs>{markers}</defs>
{svg}
</svg></div></div>
<script>
(function(){{var s=document.getElementById('dg'),box=document.getElementById('scroll'),z=1,W={W},H={H};
function ap(){{s.setAttribute('width',W*z);s.setAttribute('height',H*z);s.style.minWidth=(W*z)+'px';}}
document.getElementById('zoom-in').onclick=function(){{z=Math.min(2,z*1.2);ap();}};
document.getElementById('zoom-out').onclick=function(){{z=Math.max(.3,z/1.2);ap();}};
document.getElementById('zoom-fit').onclick=function(){{z=Math.max(.3,(box.clientWidth-2)/W);ap();}};
if(box.clientWidth<W){{z=Math.max(.3,(box.clientWidth-2)/W);ap();}}}})();
</script>
"""
open("/tmp/claude-0/-home-user-Softbank-Study-1/a18e2351-f5d1-51b1-b791-f6e48d440d54/scratchpad/finals-architecture-v0.3-k8s.html", "w").write(page)
print(len(page))
