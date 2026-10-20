#!/usr/bin/env bash
# 정답본(solution/)이 실제로 테스트를 통과하는지 확인한다 (Claude 작성, 완성본).
# 원래 자리는 건드리지 않는다: 임시 폴더에 복사 → solution 파일을 덮어씀 → 테스트.
#   사용: scripts/check-solution.sh          정답본 검사
#         scripts/check-solution.sh --mine   내가 채운 원래 자리 그대로 검사 (빈칸 남았는지 + 테스트)
set -euo pipefail
cd "$(dirname "$0")/.."
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
# 필요한 폴더만 복사 (빌드 결과물·가상환경은 빼고)
cp -R control-plane mcp-server k8s "$TMP/"
rm -rf "$TMP/control-plane/target" "$TMP/mcp-server/.venv"; find "$TMP" -name __pycache__ -prune -exec rm -rf {} +
if [[ "${1:-}" != "--mine" ]]; then
  cp -R solution/. "$TMP/"
  echo "== solution/ 을 덮어쓴 복사본을 검사"
else
  echo "== 원래 자리(내가 채운 것)를 검사"
fi

echo "== 1) 빈칸(___)이 남았나"
# 주석 줄(#, //)은 빼고 찾는다
if grep -rnE '___' "$TMP/control-plane/src/main/resources" "$TMP/k8s" | grep -vE ':[0-9]+:\s*#'; then echo "빈칸 남음"; exit 1; fi
grep -rnI 'TODO(human): scale' "$TMP/mcp-server/ops_mcp" && { echo "scale 아직 안 씀"; exit 1; }
echo "없음"

echo "== 2) 컨트롤 플레인 테스트"
(cd "$TMP/control-plane" && ./mvnw -B -q test) && echo "통과"

echo "== 3) MCP 서버 테스트"
PY=${PY:-python3}
(cd "$TMP/mcp-server" && "$PY" -m venv .venv && .venv/bin/pip install -q -e '.[test]' && .venv/bin/pytest -q)

echo "== 4) 매니페스트 문법 (kubectl 이 클러스터에 물어봄, 실제로 만들지는 않음)"
if kubectl version --request-timeout=3s >/dev/null 2>&1; then
  kubectl apply --dry-run=server -R -f "$TMP/k8s/platform" >/dev/null && echo "통과 (server dry-run)"
else
  echo "클러스터가 없어 건너뜀"
fi
