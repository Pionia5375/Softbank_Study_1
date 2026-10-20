#!/usr/bin/env bash
# 배포 시간을 N 번 재고 요약한다 (Claude 작성, 완성본).
#   사용: scripts/measure-deploy.sh [N]   (기본 3)
#   매번 코드 끝에 주석 한 줄을 바꿔 붙여서 "진짜 새 빌드" 가 되게 한다 (같은 코드면 빌드를 재사용하니까)
#   마지막에 같은 코드를 한 번 더 보내서 "재사용(멱등) 배포" 시간도 잰다
set -euo pipefail
cd "$(dirname "$0")/.."
N=${1:-3}
TENANT=${TENANT:-tenant-a}
OUT=${OUT:-results/deploy-times.csv}
export OUT
TMP=$(mktemp -d)
for i in $(seq 1 "$N"); do
  cp samples/hello-v1.py "$TMP/hello.py"
  echo "# run $i $(date +%s)" >> "$TMP/hello.py"
  echo "== $i/$N (새 빌드)"
  scripts/deploy-fn.sh "$TENANT" hello "$TMP/hello.py"
done
echo "== 같은 코드 다시 (빌드 재사용)"
scripts/deploy-fn.sh "$TENANT" hello "$TMP/hello.py"
rm -rf "$TMP"

echo
echo "== 요약 (마지막 $((N+1))줄, 맨 끝은 재사용)"
tail -n $((N+1)) "$OUT" | python3 -c '
import csv, statistics, sys
rows = list(csv.reader(sys.stdin))
new, reuse = rows[:-1], rows[-1]
for col, i in (("build_s", 4), ("apply_s", 5), ("total_s", 6)):
    v = [float(r[i]) for r in new]
    print(f"{col:8s} 새 빌드 p50 {statistics.median(v):6.2f}  max {max(v):6.2f}   재사용 {float(reuse[i]):6.2f}")
'
