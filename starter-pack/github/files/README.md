# <팀 이름> — SoftBank Hackathon 2026 Finals

> TODO(team): 주제 공개 후 한 줄 소개. "무엇을, 왜, 어떻게 다르게"

## 바로 실행
```sh
bash scripts/up.sh      # 로컬 kind 클러스터 + dev overlay
bash scripts/smoke.sh   # 응답 확인 → "OK"
```

## 문서 지도
| 무엇 | 어디 |
|---|---|
| 설계 문서(발표용) | `docs/architecture.md` ← TODO |
| 설계 결정과 버린 대안 | Notion Decisions DB (링크 TODO) · 사본 [`docs/decisions/`](docs/decisions/README.md) |
| 데모 순서·장애 대응 | `docs/runbook.md` ← TODO |
| 측정 결과 | `docs/measurements/` ← TODO |
| 작업 규칙(사람·AI 공통) | [`AGENTS.md`](AGENTS.md) |
| 기능 계획·회의록 | Notion (링크 TODO) |

## 구조
```
apps/        서비스 코드
infra/       Terraform (apply는 로컬에서 승인 후에만)
manifests/   kustomize base + overlays/{dev,demo}
scripts/     up.sh · smoke.sh
docs/        설계·결정·런북·측정
```

## 팀
| 이름 | 역할 | GitHub |
|---|---|---|
| TODO | | |
