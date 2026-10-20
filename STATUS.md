# STATUS

**2026-10-20 (화) · Day 16/33 · W3 (10/19~10/25) 둘째 날**

**오늘 과제:** 로드맵상 D16은 P1-1 (2/2) DSF Quickstart + Scoring API(Spring Boot) → 재배치 측정값이다. 그런데 10/19(D15)에도 커밋이 없다 ⚠️. OCM hub·managed join도, Lab 07 첫 `apply`도, 모의 #1 회고와 W3 결정도 남지 않았다. 마지막 커밋은 여전히 48e46bc(10/6)이고 10/7부터 열사흘 연속 커밋이 없다. DSF와 Scoring API는 OCM `Placement` 위에 얹는 것이고, OCM은 kind 클러스터 3개 위에 서므로 오늘 D16 분량은 바로 시작할 수 없다. 그래서 오늘도 **"바닥 → OCM → 점수" 순서로, 한 칸씩만**을 제안한다. ① 오전 1시간: Lab 07 `envs/dev` apply → `curl` 200 + 걸린 시간. `docker stats --no-stream`으로 Lab 05 메모리 칸, hello `wait` 주석 정리 → **바로 커밋** (열사흘 만의 첫 커밋, 오늘의 최소 성공 기준). ② 20분: 모의 #1 회고 + W3 결정을 `notes/`에 남긴다. 이틀째 결정이 없으므로 기본안을 좁힌다: "W3는 OCM + 점수 배치 한 줄만 세우고, Knative·KEDA·SpinKube(D17·D18)는 하루로 합치거나 W4로 미룬다. v1 마무리(Argo CD + Rollouts)는 모의 #2 직전(10/27)에 몰아서." 최종 결정은 Jeong이 한다. ③ 오후: OCM `clusteradm` hub + managed 2개 join → `Placement` 1개로 배치 확인 + 시간 (10/19 분량). ④ 시간이 남을 때만: `AddOnPlacementScore` 하나를 손으로 넣고 `Placement`가 점수 따라 다른 클러스터를 고르는지 확인 (DSF·Scoring API의 맛보기). DSF Quickstart·Spring Boot Scoring API는 내일 이후로, 자리는 ②에서 정한다. 밀린 것: OCM hub + managed 2개 join + `Placement` 배치 + 시간 ⚠️ (10/19 D15), `AddOnPlacementScore` ⚠️ (10/19 D15), Lab 07 `envs/dev` apply + `curl` 200 + 시간 ⚠️ (10/11 D7부터), Lab 05 메모리 칸 ⚠️ (10/7부터), Lab 07 hello `wait` 확정 ⚠️ (10/11부터), 모의 #1 회고 + W3 재판단 ⚠️ (10/18 D14부터), Argo CD + hello `Application` sync 초 ⚠️ (10/14 D10부터), Argo Rollouts 카나리 + 수동 `abort` 초 ⚠️ (10/15 D11부터), 예선 앱을 `Application`으로 올리기 ⚠️ (10/16 D12), 최종 5분·데모 3분 녹화 ⚠️ (10/17 D13), Lab 06 1~5단계 + `RATE` 200 주석 + `AnalysisTemplate` 자동 롤백 ⚠️ (10/9부터), Lab 06 6단계 p95 표·PromQL 5개·대시보드 JSON ⚠️ (10/10부터), Lab 07 원격 state·lock + AWS `plan` + drill 2·3회차 ⚠️ (10/12부터), 일본어 2분 녹음 ⚠️ (10/6 스킵 후 미실행).

**본선 연결:** D16의 DSF·Scoring API는 본선 가설 "멀티 클러스터 점수 배치"의 핵심 장면이다. 점수가 바뀌면 `Placement`가 워크로드를 다른 클러스터로 옮기고, 그때 걸린 시간이 "재배치 측정값"이 된다. 10/28 모의 #2 Day1 주제 후보 중 하나가 바로 이것이라, W3 안에 "점수 → 재배치" 한 장면만 서도 모의 #2의 출발점이 생긴다. 그런데 그 장면은 OCM 위에, OCM은 kind 클러스터 3개 위에 선다. 그래서 오늘 ①의 Lab 07 `apply` 한 번이 D15·D16 전체의 바닥이다. 완성도·데모 30점은 "실제로 선 것"만큼 나온다. 본선까지 남은 학습일이 15일 남짓(10/30·31 제외)이라, ②에서 W3 범위를 좁혀 두지 않으면 D17~D21도 같은 방식으로 밀린다.

---

## 오늘 고정 루틴 (05 v0.5 4.1, 하루 12시간)

- [ ] 실습 8h
- [ ] 측정 + ADR 1개 2h
- [ ] 일본어: 2분 설계 설명 + 예상 Q&A 1~2개 녹음 1h
- [ ] 정리: `notes/` 커밋, 내일 할 일 1h

## 마일스톤

| 날짜 | 내용 | 상태 |
|---|---|---|
| 10/15 (목) | 스타터 킷 v1 (로컬 kind) | ⚠️ (10/15~10/19 커밋 없음, 10/20 오전 Lab 07 apply 최소선 제안, 마무리 시점은 W3 결정 대기) |
| 10/16~17 | 모의 해커톤 #1 | ⚠️ (Day1·Day2 모두 커밋·녹음·녹화 기록 없음, 회고는 10/18·10/19 모두 기록 없음 → 10/20로) |
| 10/26 (월) 저녁 | 본선 진출 결과 메일 【사실】 | |
| 10/27 (화) 23:59 | 참가 회신 마감 【사실】 | |
| 10/27 (화) | 스타터 킷 v2 (AWS는 **승인 필요**) | |
| 10/28~29 | 모의 해커톤 #2 | |
| 10/30~31 | 학습 불가 (Techeer 보안 해커톤 운영) | |
| 10/30 (금) 또는 11/2 (월) | 본선 킥오프 【미확인】. 10/30이면 Techeer 운영과 겹침, 10/26 메일에서 확인 | |
| 11/7~8 (토·일) | **본선** | |

---

## 로드맵 (05 v0.5 4.2 기준)

v0.5는 기간 단위로 짜여 있다. 아래 일 단위 분할(`1/3` 등)은 STATUS용 제안이고, 범위가 서로 다르면 v0.5를 따른다.

### W1 · 10/5~10/11 · Day 1~7

- [x] **10/5 (월) D1** Lab 01 Docker 기초 (v0.4 밖, 사전 실습) ✅ (ADR은 10/6에 마감)
  - [x] `labs/01-docker-basics` 뼈대, A 빌드·실행 확인 ✅
  - [x] Dockerfile B TODO(human): JRE 베이스 선택, HEALTHCHECK ✅ (eclipse-temurin:21-jre, 3f0f4ed)
  - [x] `measure.sh single` / `multi` → README 측정표 ✅ (294.0 MB → 129.8 MB)
  - [x] ADR: 런타임 베이스 이미지 선택 ✅ ([decisions/2026-10-06.md](decisions/2026-10-06.md) ADR-001, 10/6 작성)
- [x] **10/6 (화) D2** P0-1 (1/3) kind 클러스터, 예선 샘플 앱(다중 서비스)을 Deployment·Service·Ingress로 ✅
  - [x] 밀린 것: Lab 01 ADR ✅ (ADR-001, Claude 작성 · Jeong 리뷰)
  - [x] `labs/02-k8s-basics` 뼈대 (kind + Deployment/Service/Ingress + Helm 차트) ✅ (0a93ccd, 10/5 선행)
  - [x] TODO(human): replicas 3, `values-demo.yaml` ✅ (c9d69ff)
  - [x] README 측정표 4칸 ✅ (b88be4b: 30.5s / Running 0s·응답 약 4~5s 추정 / 1→3 18s 안 / hello 175MB·K8s 510MB)
  - [x] replicas 3 이유 ✅ (b88be4b: 가용성 + 트래픽 분산, 분산 효과는 10/10 k6로 측정)
  - [x] README "큰 그림" 아래 흐름 네 문장 ✅ (e5cfdf6)
  - [x] 선행: probe + requests/limits ✅ ([Lab 03](labs/03-k8s-probes/README.md)): 롤아웃 중 실패 51% → 3%, 128Mi 90% 사용, 64Mi OOMKilled, 결정 requests 200Mi / limits 512Mi
  - [ ] ~~일본어 2분 녹음~~ 10/6 스킵 (Jeong 결정)
  - 다중 서비스 앱은 Lab 02 README 기준 10/7 이후로 미룸 → Lab 05 4단계 축소판(hello2)으로 10/6 처리 ✅ (48e46bc)
- [x] **10/7 (수) D3** P0-1 (2/3) 롤아웃·롤백·프로브·HPA·requests/limits → 10/6 진행: [Lab 04](labs/04-k8s-rollout-hpa/README.md) (프로브·limits 는 Lab 03 완료) ✅
  - [x] Lab 04 측정 ✅ (a33b4c5, 8007ec6: preStop 5s 롤아웃 실패 0/175, 잘못된 태그 → `helm rollback` 0.25s 무중단, HPA 2→6→2 약 75s 복귀)
  - Lab 04 측정표 남은 구멍: v2 롤아웃 시간·첫 scale up 정확한 시각 미측정, HPA 노드 2대 재측정은 Lab 06에서
  - [ ] Lab 05 측정표 "노드 3대 클러스터 메모리" 칸 ⚠️
  - [ ] Lab 06 TODO(human) `k6/hello.js` `RATE` (추천 200) ⚠️
  - [ ] Lab 06 1~5단계 (kube-prometheus-stack·Traefik 지표·Loki/Alloy·Grafana 대시보드·k6 스모크) ⚠️
  - [ ] Lab 06 6단계 A1~B2 튜닝 전/후 p95 표 (D6 분량, 남으면 10/8로) ⚠️
  - [ ] 일본어 2분 녹음 재개 (주제 후보: preStop으로 롤아웃 실패 4% → 0%) ⚠️
- [ ] **10/8 (목) D4** P0-1 (3/3) taint/toleration·PriorityClass → 롤아웃·롤백·HPA 측정표 → 10/6 진행: [Lab 05](labs/05-k8s-scheduling/README.md) (노드 3대·셋업 드릴·다중 서비스 축소판) ⚠️ (메모리 칸 1개 남음)
  - [x] Lab 05 뼈대 ✅ (2805ccc, 2d846e4)
  - [x] 셋업 드릴·taint·선점·hello2 측정 ✅ (48e46bc: 드릴 1분 59초, taint 후 hello 3개 모두 worker, replicas 5 Running까지 35s)
  - [ ] 노드 3대 클러스터 메모리 칸 (10/7로 당김) ⚠️
  - [ ] 밀린 것 (10/7): Lab 05 측정표 "노드 3대 클러스터 메모리" 칸 (`docker stats --no-stream`) ⚠️
  - [ ] 밀린 것 (10/7): Lab 06 TODO(human) `k6/hello.js` `RATE` (추천 200) ⚠️
  - [ ] 밀린 것 (10/7): Lab 06 1~5단계 (kube-prometheus-stack·Traefik 지표·Loki/Alloy·Grafana 대시보드·k6 스모크) ⚠️
  - [ ] 밀린 것 (10/7): 일본어 2분 녹음 (주제 후보: preStop으로 롤아웃 실패 4% → 0%) ⚠️
  - [ ] 오늘(여유분): Lab 06 6단계 A1~B2 튜닝 전/후 p95 표 (D6 분량, 남으면 10/9로) ⚠️
- [ ] **10/9 (금) D5** P0-2 (1/2) kube-prometheus-stack, Loki + Grafana Alloy → 10/6 진행: [Lab 06](labs/06-observability-k6/README.md) ⚠️ (10/9 커밋 없음)
  - [x] Lab 06 뼈대 ✅ (e874ef0) · 측정표는 비어 있음 → 10/7 실행
  - [ ] Lab 06 TODO(human) `k6/hello.js` `RATE` (추천 200) (10/7·10/8에서 밀림) ⚠️
  - [ ] Lab 06 1~5단계 (kube-prometheus-stack·Traefik 지표·Loki/Alloy·Grafana 대시보드·k6 스모크) (10/7·10/8에서 밀림) ⚠️
  - [ ] 밀린 것 (10/8): Lab 05 측정표 "노드 3대 클러스터 메모리" 칸 (`docker stats --no-stream`) ⚠️
  - [ ] 밀린 것 (10/8): 일본어 2분 녹음 (주제 후보: preStop으로 롤아웃 실패 4% → 0%) ⚠️
  - Lab 06 6단계 A1~B2 p95 표는 D6(10/10) 본 분량으로 넘김
- [ ] **10/10 (토) D6** P0-2 (2/2) k6, PromQL 5개, 튜닝 전/후 p95 비교표, 대시보드 JSON → 10/6 진행: Lab 06 후반 ⚠️ (10/10 커밋 없음)
  - [ ] 밀린 것 (10/9): Lab 05 측정표 "노드 3대 클러스터 메모리" 칸 (`docker stats --no-stream`, 클러스터 올리자마자) ⚠️
  - [ ] 밀린 것 (10/9): Lab 06 TODO(human) `k6/hello.js` `RATE` 확정 (코드 기본값 200, 주석만 남음) ⚠️
  - [ ] 밀린 것 (10/9): Lab 06 1~5단계 (kube-prometheus-stack·Traefik 지표·Loki/Alloy·Grafana 대시보드·k6 smoke) + 설치 시간·관측 스택 메모리 칸 ⚠️
  - [ ] Lab 06 6단계 A1·A2·B1·B2 p95 표 + Traefik p95 vs k6 p95 비교 칸 ⚠️
  - [ ] PromQL 5개 확인 (`promql.md`), 대시보드 JSON 내보내기 (모자라면 10/11로) ⚠️
  - [ ] 밀린 것 (10/9): 일본어 2분 녹음 (주제 후보: preStop으로 롤아웃 실패 4% → 0%) ⚠️
- [ ] **10/11 (일) D7** P0-4 (1/3) Terraform: kind·docker 프로바이더로 모듈 작성 → 10/6 진행: [Lab 07](labs/07-terraform-kind/README.md) (dev/demo 두 환경, drill 3회) ⚠️ (10/11 커밋 없음)
  - [x] Lab 07 뼈대 ✅ (1b28113, fmt/validate 통과) · TODO(human) hello `wait`, drill 측정표 남음
  - [ ] Lab 07 TODO(human) `modules/platform/main.tf` hello `wait` (추천 `true`) ⚠️ (코드는 `true`, 주석 정리·확정만 남음)
  - [ ] Lab 07 `envs/dev`·`envs/demo` apply → `curl` 200 → destroy 각 1회 + 시간 기록 (3회 drill은 10/12 D8) ⚠️
  - [ ] 밀린 것 (10/10): Lab 05 측정표 "노드 3대 클러스터 메모리" 칸 (`docker stats --no-stream`, demo apply 직후) ⚠️
  - [ ] 밀린 것 (10/10): Lab 06 TODO(human) `k6/hello.js` `RATE` 200 확정 (주석 정리) ⚠️
  - [ ] 밀린 것 (10/10): Lab 06 1~5단계 (관측 스택 설치·smoke, 설치 시간·관측 스택 메모리 칸) ⚠️
  - [ ] 밀린 것 (10/10): Lab 06 6단계 A1~B2 p95 표·PromQL 5개·대시보드 JSON (오늘 못 하면 W2 자리 재배치) ⚠️
  - [ ] 밀린 것 (10/10): 일본어 2분 녹음 (주제 후보: preStop으로 롤아웃 실패 4% → 0%) ⚠️

### W2 · 10/12~10/18 · Day 8~14

- [ ] **10/12 (월) D8** P0-4 (2/3) plan/apply/destroy 3회, 매번 시간 기록, 모듈 output → input → [Lab 07](labs/07-terraform-kind/README.md) drill ⚠️ (10/12 커밋 없음, `results/` 비어 있음)
  - [ ] Lab 07 `envs/dev`·`envs/demo` plan/apply/destroy 3회 + 매번 시간 기록 (1회차 = 10/11 밀린 1회) ⚠️
  - [ ] Lab 07 `cluster` 모듈 output → `platform` 모듈 input 연결 확인 ⚠️
  - [ ] 밀린 것 (10/11): Lab 07 TODO(human) hello `wait` 확정 (코드 `true`, 주석 정리) ⚠️
  - [ ] 밀린 것 (10/11): Lab 05 측정표 "노드 3대 클러스터 메모리" 칸 (`docker stats --no-stream`, demo apply 직후) ⚠️
  - [ ] 밀린 것 (10/11): Lab 06 TODO(human) `k6/hello.js` `RATE` 200 확정 (코드 기본값 200, 주석 정리) ⚠️
  - [ ] 밀린 것 (10/11): Lab 06 1~5단계 (관측 스택 설치·smoke) — 10/15 Argo Rollouts 자동 롤백 전제라 늦어도 10/13 ⚠️
  - [ ] 밀린 것 (10/11): Lab 06 6단계 A1~B2 p95 표·PromQL 5개·대시보드 JSON — 10/18 D14 버퍼로 이동 제안 ⚠️
  - [ ] 밀린 것 (10/11): 일본어 2분 녹음 (주제 후보: preStop으로 롤아웃 실패 4% → 0%) ⚠️
  - 참고: 커밋은 안 됐지만 untracked `exam.yaml`(10/12 00:39, Gateway API `Gateway`+`HTTPRoute` HTTPS 연습)이 있다. 로드맵 밖 항목이다
- [ ] **10/13 (화) D9** P0-4 (3/3) 원격 state·lock, AWS는 plan까지 ⚠️ (10/13 커밋 없음, `results/` 비어 있음)
  - [ ] 밀린 것 (10/11·10/12): Lab 07 `envs/dev` apply → `curl` 200 → destroy 1회 + 시간 기록 (최우선, 원격 state 전제) ⚠️
  - [ ] 밀린 것 (10/11): Lab 07 hello `wait` 확정 (코드 `true`, 주석 정리) ⚠️
  - [ ] 밀린 것 (10/11): Lab 05 측정표 "노드 3대 클러스터 메모리" 칸 (`docker stats --no-stream`, demo apply 직후) ⚠️
  - [ ] 밀린 것 (10/9부터): Lab 06 1~5단계 (관측 스택 설치·smoke) + `RATE` 200 주석 정리 — **오늘 마감** (10/15 자동 롤백 전제) ⚠️
  - [ ] Lab 07 원격 state·lock 구성 (시간 남으면) ⚠️
  - [ ] AWS 프로바이더 `terraform plan`까지 (apply 금지) ⚠️
  - [ ] 밀린 것 (10/12): Lab 07 drill 2·3회차 + `cluster` output → `platform` input 확인 — 10/18 D14 버퍼로 이동 제안 ⚠️
  - [ ] 밀린 것 (10/10): Lab 06 6단계 A1~B2 p95 표·PromQL 5개·대시보드 JSON — 10/18 D14 버퍼로 이동 제안 ⚠️
  - [ ] 밀린 것 (10/6부터): 일본어 2분 녹음 (주제 후보: preStop으로 롤아웃 실패 4% → 0%) ⚠️
- [ ] **10/14 (수) D10** P1-3 (1/2) Argo CD + Application 선언 파일 ⚠️ (10/14 커밋 없음, `results/` 비어 있음)
  - [ ] 밀린 것 (10/11~10/13): Lab 07 `envs/dev` apply → `curl` 200 → destroy 1회 + 시간 기록 (최우선, Argo CD 올릴 클러스터) ⚠️
  - [ ] 밀린 것 (10/11~10/13): Lab 07 hello `wait` 확정 (코드 `true`, 주석 정리) ⚠️
  - [ ] 밀린 것 (10/7~10/13): Lab 05 측정표 "노드 3대 클러스터 메모리" 칸 (`docker stats --no-stream`, demo apply 직후) ⚠️
  - [ ] 밀린 것 (10/9~10/13): Lab 06 1~5단계 (관측 스택 설치·smoke) + `RATE` 200 주석 정리 — 10/13 마감 넘김, 10/15 자동 롤백 전제 ⚠️
  - [ ] Argo CD 설치 + hello `Application` 선언 파일 1개 → Git push 후 sync까지 걸린 시간 기록 ⚠️
  - [ ] 밀린 것 (10/13): Lab 07 원격 state·lock + AWS `plan` (apply 금지) — 10/18 D14 버퍼로 이동 제안 ⚠️
  - [ ] 밀린 것 (10/12): Lab 07 drill 2·3회차 + `cluster` output → `platform` input 확인 — 10/18 D14 버퍼로 이동 제안 ⚠️
  - [ ] 밀린 것 (10/10): Lab 06 6단계 A1~B2 p95 표·PromQL 5개·대시보드 JSON — 10/18 D14 버퍼로 이동 제안 ⚠️
  - [ ] 밀린 것 (10/6부터): 일본어 2분 녹음 (주제 후보: preStop으로 롤아웃 실패 4% → 0%) ⚠️
  - 판단 필요 (10/14 밤): 결정 기록 없음 → 10/15 아침 블록에서 범위 축소안 제시
- [ ] **10/15 (목) D11** P1-3 (2/2) Argo Rollouts 카나리 + 메트릭 기반 자동 롤백 → **스타터 킷 v1**, 자동 롤백까지 걸린 초 ⚠️ (10/15 커밋 없음, `results/` 비어 있음)
  - [ ] 밀린 것 (10/11~10/14): Lab 07 `envs/dev` apply → `curl` 200 → destroy 1회 + 시간 기록 (최우선, 스타터 킷 v1의 바닥) ⚠️
  - [ ] 밀린 것 (10/14): Argo CD 설치 + hello `Application` 1개 → Git push 후 sync까지 걸린 시간 기록 ⚠️
  - [ ] 스타터 킷 v1 축소판: Argo Rollouts 카나리 1개 + 잘못된 이미지로 수동 `abort`/롤백 → 되돌아오기까지 걸린 초 ⚠️
  - [ ] 밀린 것 (10/7~10/14): Lab 05 측정표 "노드 3대 클러스터 메모리" 칸 (`docker stats --no-stream`, demo apply 직후, 1분이면 끝남) ⚠️
  - [ ] 밀린 것 (10/11~10/14): Lab 07 hello `wait` 확정 (코드 `true`, 주석 정리) ⚠️
  - [ ] 시간 남으면: Lab 06 1~5단계(관측 스택) + `RATE` 200 주석 → `AnalysisTemplate`으로 메트릭 기반 자동 롤백 (안 되면 10/18 D14로) ⚠️
  - [ ] 밀린 것 (10/10~10/14): Lab 06 6단계 A1~B2 p95 표·PromQL 5개·대시보드 JSON — 10/18 D14 버퍼 ⚠️
  - [ ] 밀린 것 (10/12~10/14): Lab 07 원격 state·lock + AWS `plan`, drill 2·3회차 + `cluster` output → `platform` input — 10/18 D14 버퍼 ⚠️
  - [ ] 밀린 것 (10/6부터): 일본어 2분 녹음 (주제 후보: preStop으로 롤아웃 실패 4% → 0%) — 내일 모의 해커톤 발표 연습을 겸해 오늘 밤 1회 ⚠️
  - 판단 필요 (10/15 밤): 결정 기록 없음 → 10/16 아침 블록에서 "Day1 오전을 v1 최소선에" 안 제시
- [ ] **10/16 (금) D12** 모의 해커톤 #1 Day1: 예선 "One Click Infinity Cloud"를 스타터 킷 위에서. 10:00~14:00 개발 → 중간 보고 3분 + Q&A 4분 ⚠️ (10/16 커밋 없음, `results/` 비어 있음, 녹음 기록 없음)
  - [ ] 밀린 것 (10/11~10/15): Lab 07 `envs/dev` apply → `curl` 200 + 시간 기록 (10:00~11:00, v1의 바닥) ⚠️
  - [ ] 밀린 것 (10/7~10/15): Lab 05 측정표 "노드 3대 클러스터 메모리" 칸 (`docker stats --no-stream`, apply 직후 1분) ⚠️
  - [ ] 밀린 것 (10/14~10/15): Argo CD 설치 + hello `Application` 1개 → push부터 sync까지 걸린 초 (11:00~12:30) ⚠️
  - [ ] 예선 앱을 Argo CD `Application`으로 올리기 (12:30~14:00) + v1 만드는 데 걸린 총 시간 기록 ⚠️
  - [ ] 중간 보고 3분 + Q&A 4분 (v1 미완 사실 + ①② 숫자 그대로), 녹음 → 일본어 2분 녹음 밀린 것을 겸함 ⚠️
  - [ ] 밀린 것 (10/11~10/15): Lab 07 hello `wait` 확정 (코드 `true`, 주석 정리) ⚠️
  - 10/17 Day2 오전으로: Argo Rollouts 카나리 1개 + 잘못된 이미지 → 수동 `abort` 되돌아오기까지 걸린 초 (v1 데모 장면)
  - 10/18 D14 버퍼로: Lab 06 1~5단계 + `RATE` 200 + `AnalysisTemplate` 자동 롤백, Lab 06 6단계 p95 표·PromQL·대시보드 JSON, Lab 07 원격 state·lock + AWS `plan` + drill 2·3회차
- [ ] **10/17 (토) D13** 모의 해커톤 #1 Day2: 최종 5분 (설계 문서 2분 + 데모 3분), 녹화 ⚠️ (10/17 커밋 없음, `results/` 비어 있음, 녹화 기록 없음)
  - [ ] 밀린 것 (10/11~10/16): Lab 07 `envs/dev` apply → `curl` 200 + 시간 기록 (오전 1h, 열흘 만의 첫 커밋 목표) ⚠️
  - [ ] 밀린 것 (10/7~10/16): Lab 05 측정표 "노드 3대 클러스터 메모리" 칸 (`docker stats --no-stream`, apply 직후 1분) ⚠️
  - [ ] 밀린 것 (10/14~10/16): Argo CD 설치 + hello `Application` 1개 → push부터 sync까지 걸린 초 (오전 1.5h) ⚠️
  - [ ] 시간 남으면 (10/15~10/16에서 밀림): Argo Rollouts 카나리 + 잘못된 이미지 → 수동 `abort` 되돌아오기까지 걸린 초 ⚠️
  - [ ] 최종 5분 녹화: 설계 문서 2분 + 데모 3분 (서 있는 것만, v1까지 걸린 실제 시간 숫자 포함) → 일본어 2분 녹음 밀린 것을 겸함 ⚠️
  - [ ] 밀린 것 (10/11~10/16): Lab 07 hello `wait` 확정 (코드 `true`, 주석 정리, 1분) ⚠️
  - 포기: 10/16 중간 보고 3분 + Q&A 4분은 다시 하지 않고 오늘 최종 5분으로 갈음. 예선 앱 `Application` 배포는 ② 이후 시간 남을 때만
  - 10/18 D14로: 모의 #1 회고 + **W3 일정 재판단**(v1 완성에 하루 더 쓸지), Lab 06 관측 스택·자동 롤백, Lab 06 p95 표, Lab 07 원격 state·AWS `plan`·drill 2·3회차
- [ ] **10/18 (일) D14** 버퍼 + 모의 #1 회고 반영 ⚠️ (10/18 커밋 없음, `results/` 비어 있음, 회고·W3 결정 기록 없음)
  - [ ] 밀린 것 (10/11~10/17): Lab 07 `envs/dev` apply → `curl` 200 + 시간 기록 → 바로 커밋 (오전 1h, 열하루 만의 첫 커밋) ⚠️
  - [ ] 밀린 것 (10/7~10/17): Lab 05 측정표 "노드 3대 클러스터 메모리" 칸 (`docker stats --no-stream`, apply 직후 1분) ⚠️
  - [ ] 밀린 것 (10/11~10/17): Lab 07 hello `wait` 확정 (코드 `true`, 주석 정리, 1분) ⚠️
  - [ ] 밀린 것 (10/14~10/17): Argo CD 설치 + hello `Application` 1개 → push부터 sync까지 걸린 초 (오전 1.5h) ⚠️
  - [ ] 모의 #1 회고 → `notes/`: 막힌 지점, 실제로 쓴 시간, "열하루 동안 첫 apply가 안 된 이유" (오후 1h) ⚠️
  - [ ] **W3 일정 재판단** (Jeong 결정): 제안 = 10/19 D15를 v1 마무리일(Rollouts 카나리 + 수동 `abort` 초)로, OCM은 10/20 하루로 축소, DSF·Scoring API는 W4 앞쪽 또는 D28로 (오후 30m) ⚠️
  - [ ] 시간 남으면 (10/17에서 밀림): 데모 3분 녹화 (①② 선 것만) → 일본어 2분 녹음 밀린 것을 겸함 ⚠️
  - 회고에서 자리 정하기: Lab 06 1~5단계 + `RATE` 200 + `AnalysisTemplate` 자동 롤백, Lab 06 6단계 p95 표·PromQL·대시보드 JSON, Lab 07 원격 state·lock + AWS `plan` + drill 2·3회차, 예선 앱 `Application` 배포

### W3 · 10/19~10/25 · Day 15~21

- [ ] **10/19 (월) D15** P1-1 (1/2) OCM hub + managed 2개, `Placement`·`AddOnPlacementScore` ⚠️ (10/19 커밋 없음, `results/` 비어 있음, 회고·W3 결정 기록 없음)
  - [ ] 밀린 것 (10/11~10/18): Lab 07 `envs/dev` apply → `curl` 200 + 시간 기록 → 바로 커밋 (오전 1h, 열이틀 만의 첫 커밋) ⚠️
  - [ ] 밀린 것 (10/7~10/18): Lab 05 측정표 "노드 3대 클러스터 메모리" 칸 (`docker stats --no-stream`, apply 직후 1분) ⚠️
  - [ ] 밀린 것 (10/11~10/18): Lab 07 hello `wait` 확정 (코드 `true`, 주석 정리, 1분) ⚠️
  - [ ] 밀린 것 (10/18): 모의 #1 회고 + **W3 재판단** (Jeong 결정) → `notes/`, "열이틀 동안 첫 apply가 안 된 이유" 한 단락 (30m) ⚠️
  - [ ] 결정이 "로드맵대로"면: OCM `clusteradm` hub + managed 2개 join → `Placement` 1개로 배치 확인 + 걸린 시간 기록 (`AddOnPlacementScore`는 남으면, 아니면 10/20) ⚠️
  - [ ] 결정이 "v1 먼저"면 (10/14부터 밀림): Argo CD 설치 + hello `Application` 1개 → push부터 sync까지 걸린 초 ⚠️
  - [ ] 시간 남으면 (10/6부터 밀림): 오늘 선 것으로 일본어 2분 녹음 ⚠️
  - 회고에서 자리 정하기: Argo Rollouts 카나리 + 수동 `abort`, 예선 앱 `Application` 배포, 최종 5분 녹화, Lab 06 1~5단계 + `RATE` 200 + `AnalysisTemplate`, Lab 06 6단계 p95 표·PromQL·대시보드 JSON, Lab 07 원격 state·lock + AWS `plan` + drill 2·3회차
- [ ] **10/20 (화) D16** P1-1 (2/2) DSF Quickstart, Scoring API를 Spring Boot로 → 재배치 측정값 **← 오늘**
  - [ ] 밀린 것 (10/11~10/19): Lab 07 `envs/dev` apply → `curl` 200 + 시간 기록 → 바로 커밋 (오전 1h, 열사흘 만의 첫 커밋, 오늘의 최소 성공 기준)
  - [ ] 밀린 것 (10/7~10/19): Lab 05 측정표 "노드 3대 클러스터 메모리" 칸 (`docker stats --no-stream`, apply 직후 1분)
  - [ ] 밀린 것 (10/11~10/19): Lab 07 hello `wait` 확정 (코드 `true`, 주석 정리, 1분)
  - [ ] 밀린 것 (10/18~10/19): 모의 #1 회고 + **W3 재판단** (Jeong 결정) → `notes/` (20m). 기본안: W3는 OCM + 점수 배치 한 줄만, D17·D18은 하루로 합치거나 W4로, v1 마무리(Argo CD + Rollouts)는 10/27 앞으로
  - [ ] 밀린 것 (10/19): OCM `clusteradm` hub + managed 2개 join → `Placement` 1개로 배치 확인 + 걸린 시간 기록 (오후)
  - [ ] 시간 남으면 (10/19에서 밀림): `AddOnPlacementScore` 하나를 손으로 넣고 `Placement`가 점수 따라 클러스터를 바꾸는지 확인 + 재배치까지 걸린 초
  - [ ] 시간 남으면 (10/6부터 밀림): 오늘 선 것으로 일본어 2분 녹음
  - 내일 이후로 (자리는 회고에서): DSF Quickstart, Scoring API (Spring Boot) → 재배치 측정값. 계속 회고 대기: Argo CD `Application`·Rollouts 카나리 + `abort`, 예선 앱 `Application`, 최종 5분 녹화, Lab 06 1~6단계, Lab 07 원격 state·AWS `plan`·drill 2·3회차
- [ ] **10/21 (수) D17** P1-2 (1/2) Knative·KEDA scale-to-zero
- [ ] **10/22 (목) D18** P1-2 (2/2) SpinKube(WASM) → 컨테이너 vs WASM 콜드 스타트 p50/p99 비교표
- [ ] **10/23 (금) D19** P1-4 (1/2) Postgres 앱 클러스터 간 이동 (Flyway, 덤프·복원, MinIO) → RPO·RTO
- [ ] **10/24 (토) D20** P1-4 (2/2) Terraform 모듈 합성 vs Crossplane Composition 비교 ADR
- [ ] **10/25 (일) D21** P1-5 CPU용 llama.cpp 또는 vLLM CPU + 라우터 → 동시 요청 수별 TTFT·처리량

### W4 · 10/26~11/1 · Day 22~28

- [ ] **10/26 (월) D22** P2 장애 주입(Pod kill·노드 drain·지연) + 런북 → MTTD·MTTR. 예선 IR 설명 1페이지 한국어·일본어판. 저녁에 결과 메일
- [ ] **10/27 (화) D23** 스타터 킷 AWS 배포: EKS 또는 kOps, 당일 destroy (**승인 필요**, 승인이 없으면 kind v1 다듬기) → **스타터 킷 v2**, 생성·파괴 시간, 실제 비용. 23:59 회신 마감
- [ ] **10/28 (수) D24** 모의 해커톤 #2 Day1: 이식성(상태 포함) 또는 멀티 클러스터 점수 배치
- [ ] **10/29 (목) D25** 모의 해커톤 #2 Day2: 최종 5분, 녹화
- **10/30 (금) D26** 학습 불가: Techeer 보안 해커톤 운영 (본선 킥오프가 이날 20:00이면 겹침)
- **10/31 (토) D27** 학습 불가: Techeer 보안 해커톤 운영
- [ ] **11/1 (일) D28** 모의 #2 회고 + 약한 역량 보강 (킥오프가 10/30이었다면 사전 개발 시작)

### W5 · 11/2~11/6 · Day 29~33 (본선 직전)

- [ ] **11/2 (월) D29** 본선 킥오프 후보일. 주제가 나오면 "한 줄 서사" 먼저 (→01 7절)
- [ ] **11/3 (화) D30** 사전 개발: 스타터 킷 위에 주제 기능만 얹기
- [ ] **11/4 (수) D31** 사전 개발 + 측정 스크립트
- [ ] **11/5 (목) D32** 사전 개발 + 설계 문서 초안
- [ ] **11/6 (금) D33** 설계 문서·측정 결과 마무리, 일본어 발표 리허설

---

## 갱신 규칙 (아침 루틴용)

- **Day N** = 오늘 − 2026-10-04 (10/5 = Day 1, 11/6 = Day 33)
- **주차** = ⌈N / 7⌉ (월요일 시작, W5는 5일)
- 맨 위 4줄(날짜·Day·주차, 오늘 과제, 본선 연결)을 오늘 항목으로 다시 쓴다. 본선 연결 문장은 05 v0.5 2.1 배점과 2.4 가설 표에서 근거를 찾는다
- 끝낸 항목: `- [x] ... ✅`
- 날짜가 지났는데 안 끝난 항목: `- [ ] ... ⚠️`. 하위 항목 중 남은 것만 다음 날 위에 한 줄로 옮긴다 (원래 줄은 지우지 않는다)
- **← 오늘** 표시를 오늘 줄로 옮기고, 오늘 줄 아래에 하위 체크박스를 단다
- "오늘 고정 루틴" 체크박스는 매일 아침 모두 `[ ]`로 되돌린다
- 마일스톤 표의 "상태" 칸에도 ✅ / ⚠️를 쓴다
- 05 갭 분석 일정이 바뀌면 로드맵을 그 버전 기준으로 다시 맞추고, 이 파일 "로드맵" 제목의 버전 표기를 바꾼다
