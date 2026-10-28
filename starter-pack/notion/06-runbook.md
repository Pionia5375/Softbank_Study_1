# 📚 Runbook (팀 내부용)

심사위원이 안 봐도 되는 것들. 작년 Yellow의 참고자료·정적분석·EC2 접속법은 전부 여기 한 페이지로.

## 1. 환경 접속

| 환경 | 접속 방법 | 담당 | 비고 |
|---|---|---|---|
| 로컬 kind | `scripts/kind-up.sh` (레포 README) | | 각자 노트북 |
| 클라우드 클러스터 | (주제 확정 후) | | 비용: 당일 destroy |
| Argo CD UI | URL / 초기 비번 위치 | | |
| Grafana | URL | | |
| 레지스트리 | | | |

(EC2 Session Manager 접속법 등은 실제로 쓰게 되는 날 여기 추가.)

## 2. 레포 · 브랜치 · PR 규칙

- 전체 규칙: 레포 `CONTRIBUTING.md` (출처: `starter-pack/github/02-strategy.md`)
- 한 줄 요약: 모노레포, `main` 하나 + squash, PR은 작게·하루 안에 머지, 리뷰 1명.
- 이슈 1 = PR 1. 이슈 첫 줄에 노션 Task URL, PR 첫 줄에 `Closes #N`. GitHub Projects·Wiki 안 씀.
- 정적 분석·린트: CI(`.github/workflows/ci.yml`)가 돌림. 정책 문서 따로 없음.

## 3. 공통 도구

| 도구 | 버전 | 설치 |
|---|---|---|
| docker | | |
| kind | | |
| kubectl | | |
| helm | | |
| terraform | | |

## 4. 비용 규칙

- 클라우드 리소스는 만든 사람이 그날 지운다. 예산 알람 먼저.
- 지원금: ₩300,000 네이버페이 【사실, 안내 메일】, 11/23 23:59까지 신청.

## 5. 참고 자료

| 제목 | 링크 | 한 줄 |
|---|---|---|
| 작년 우승팀 Blue (WASM, kOps 1클러스터) | https://github.com/Joyeongbinnn/2025softbank-hackathon-final-round | 심사평 5개 있음 — "문제 정의 명확, 팀 내 반대 의견+PoC로 결정" |
| 작년 2위 Green (Knative + k3s + gVisor, 레포 4개) | https://github.com/Softbank-Hackathon-2025-Team-Green | infra/web/codebuild/manifest 분리, Argo CD app-of-apps |
| 심사 기준 정리 | (notes/research/04 링크) | 완성도·데모 30 / 클라우드 30 / 팀 개발 20 / 독창성 10 / AI 10 |

## 6. 막혔을 때

1. 30분 룰: 30분 넘으면 슬랙에 "막힘: 무엇 · 뭘 해봤나 · 로그".
2. Tasks 카드 Blocked로.
3. 부담당과 허들 15분.
