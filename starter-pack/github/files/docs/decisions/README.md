# 설계 결정 기록 (ADR) — 사본

원본은 Notion **Decisions DB**: <!-- TODO(team): 링크 -->

이 폴더는 발표 전날(11/6) Notion에서 export한 Markdown 사본이다. 심사위원·채용 담당이 나중에 레포만 볼 때를 위한 것.
평소엔 이 폴더를 직접 고치지 않는다. 결정은 Notion에, PR에는 그 카드 링크를.

export 방법: Notion DB 우상단 `…` → Export → Markdown & CSV → 압축 풀어 `docs/decisions/`에 복사 → PR `docs(decisions): 11/6 export`.

| # | 결정 | 버린 대안 | 상태 |
|---|---|---|---|
| D-01 | 모노레포 + `main` 하나 + squash 병합 (이 레포 셋업 자체) | 멀티레포 / `dev` 브랜치 / merge 커밋 | 확정 (킥오프) |
