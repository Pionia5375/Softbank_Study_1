# ✅ Tasks DB

"모든 진행 상황을 확인할 수 있을 것"을 담당하는 보드. 기능 단위(15~30개)만. 코드 수준 세부는 GitHub 이슈·PR에 두고 링크만 건다.

## 속성

| 속성 | 타입 | 선택지 / 메모 |
|---|---|---|
| 제목 | Title | 동사로. `함수 배포 API POST /functions 구현` |
| 담당 | Person | 1명. 둘이면 쪼갠다 |
| 상태 | Status | Todo / Doing / Review / Blocked / Done |
| 우선순위 | Select | Must / Should / Could |
| 마감 | Date | |
| 링크 | URL | GitHub 이슈 URL (이슈 본문 첫 줄엔 이 카드 URL — 양방향). PR은 `Closes #N`으로 이슈에 붙음 |

(Lite 10/28: 파트·메모·회의 관계는 뺐다. 파트는 제목 앞 `[인프라]` 식으로, 막힌 이유는 본문 첫 줄에.)

## 뷰

- **보드 (상태별 그룹, compact)** — 홈에 임베드. 담당·우선순위·마감 표시. 11/5 이후는 보드에서 Must 필터만 켠다.

## 상태 규칙

- Todo → Doing: 시작할 때 본인이.
- Doing → Review: PR 올릴 때 (PR 첫 줄 `Closes #N`).
- Review → Done: 머지될 때. 이슈는 자동으로 닫히고, 노션 카드는 작업자가 Done으로 옮긴다.
- GitHub Projects 보드는 만들지 않는다. 진행 상황은 이 보드 한 군데.
- Blocked: 30분 넘게 막히면. 메모에 "무엇·뭘 해봤나". 슬랙에도 올린다.
- 마감 지난 Todo는 회의에서 Could로 내리거나 지운다. 보드에 죽은 카드를 남기지 않는다.

## 처음 넣어 둘 카드 (주제와 무관)

첫 3개는 GitHub 스레드의 Day-1 이슈 3개와 1:1 (`starter-pack/github/02-strategy.md` 체크리스트 9번). 스크립트·CI 파일은 `starter-pack/github/files/`에 있음.

| 제목 | 파트 | 우선순위 | 마감 | 레포 쪽 |
|---|---|---|---|---|
| GitHub 조직·레포·브랜치 규칙 세팅 | 문서·데모 | Must | 10/31 | `files/scripts/day1-setup.sh` |
| 로컬 kind 클러스터 부팅 스크립트 공유 | 인프라 | Must | 10/31 | `files/scripts/up.sh` |
| 각자 아키텍처 초안 1장 (회의 #1 전) | 문서·데모 | Must | 10/31 | 이슈만 |
| CI 스켈레톤 (빌드·린트) | 배포 | Should | 11/1 | `files/.github/workflows/ci.yml` |
| Argo CD 설치 + 샘플 앱 sync | 배포 | Should | 11/1 | |
| Prometheus/Grafana 설치 + 기본 대시보드 | 관측 | Should | 11/2 | |
| 데모 시나리오 초안 (3분) | 문서·데모 | Must | 11/4 | |
| Decisions DB → 레포 `docs/decisions/` export | 문서·데모 | Must | 11/6 | |
| 통역용 토크 스크립트 | 문서·데모 | Must | 11/7 | |
