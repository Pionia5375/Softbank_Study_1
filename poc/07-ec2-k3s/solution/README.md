# solution/ — 정답본 (30분 막혔을 때만)

빈칸 파일과 같은 경로 구조다. 한 칸만 보고 닫는다. 통째로 복사하면 6절(깨뜨렸다 고치기)에서 왜 Pending 인지 설명을 못 한다.

| 막힌 파일 | 정답본 | 정답본으로 바로 띄우는 법 |
|---|---|---|
| `k3s/*.tftpl` | `solution/k3s/` | `terraform/cluster/terraform.tfvars` 에 `k3s_template_dir = "../../solution/k3s"` |
| `gitops/bootstrap/*` | `solution/gitops/bootstrap/` | `./scripts/bootstrap-argocd.sh --solution` (1단계 values 도 정답본을 씀) |
| `gitops/apps/*`, `gitops/workloads/*` | `solution/gitops/apps/`, `solution/gitops/workloads/` | `--solution` 으로 띄운 root-ec2 가 `solution/gitops/apps` 를 본다 |

비교
```bash
./scripts/render-k3s.sh --solution && cp -r results/rendered /tmp/rendered-solution
./scripts/render-k3s.sh && diff -r /tmp/rendered-solution results/rendered   # 내 것과 정답본의 실제 user_data 차이
diff -r gitops solution/gitops                                                  # 매니페스트 차이 (경로 문자열 차이는 정상)
```

정답본에서 고른 값과 이유는 각 파일 주석과 README 10절 결정 표에 있다. 값이 달라도 이유를 말할 수 있으면 그게 답이다(예: `write-kubeconfig-mode` 는 0600/0644 둘 다 동작).
