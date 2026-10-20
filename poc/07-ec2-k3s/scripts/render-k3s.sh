#!/usr/bin/env bash
# k3s 템플릿을 AWS 없이 미리 채워 보고, 결과가 올바른 bash·YAML 인지 검사한다.
#   ./scripts/render-k3s.sh              k3s/ (Jeong 이 쓴 것)
#   ./scripts/render-k3s.sh --solution   solution/k3s/
# 결과 파일: results/rendered/{server,exec,build,exec-gvisor}.sh  ← 이게 EC2 가 첫 부팅 때 실제로 실행할 스크립트
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
DIR="$HERE/k3s"; [ "${1:-}" = "--solution" ] && DIR="$HERE/solution/k3s"
OUT="$HERE/results/rendered"; mkdir -p "$OUT"
RC="$HERE/scripts/render-check"

terraform -chdir="$RC" init -input=false >/dev/null
# apply 지만 provider 가 없어서 만드는 것도 돈 드는 것도 없다. state 는 render-check 폴더 안에만 생긴다(gitignore)
terraform -chdir="$RC" apply -auto-approve -input=false -var "dir=$DIR" >/dev/null

fail=0
for role in server exec build; do
  terraform -chdir="$RC" output -raw "$role" > "$OUT/$role.sh"
  if bash -n "$OUT/$role.sh"; then echo "ok   bash 문법: $role.sh"; else echo "FAIL bash 문법: $role.sh"; fail=1; fi
  # heredoc 사이의 config.yaml 부분만 잘라서 YAML 검사
  awk "/<<'K3SCONFIG'/{f=1;next}/^K3SCONFIG/{f=0}f" "$OUT/$role.sh" > "$OUT/$role-config.yaml"
  if python3 -c "
import sys
try:
    import yaml
except ImportError:
    print('      (PyYAML 이 없어 YAML 검사는 건너뜀: pip3 install pyyaml)'); sys.exit(0)
d = yaml.safe_load(open(sys.argv[1]))
print('     ', {k: d[k] for k in ('node-label', 'node-taint') if k in d})
" "$OUT/$role-config.yaml"; then
    echo "ok   YAML: $role-config.yaml"
  else
    echo "FAIL YAML: $role-config.yaml"; fail=1
  fi
done
# (선택) gVisor 를 붙인 실행 노드 스크립트는 bash 문법만 본다 (config 부분은 exec 와 같음)
terraform -chdir="$RC" output -raw exec_gvisor > "$OUT/exec-gvisor.sh"
if bash -n "$OUT/exec-gvisor.sh"; then echo "ok   bash 문법: exec-gvisor.sh (enable_gvisor=true 일 때)"; else echo "FAIL bash 문법: exec-gvisor.sh"; fail=1; fi
exit $fail
