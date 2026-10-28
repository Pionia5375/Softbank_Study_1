# 드릴 기록 (Jeong 이 채운다)

스크립트가 `results/drill.csv` 에 자동으로 한 줄씩 남긴다. 여기엔 사람이 읽을 표와 한 줄 소감만.

## 30분 드릴 (kind + Argo CD + kube-prometheus-stack + podinfo)

| 회차 | 날짜 | 1-kind (s) | 2-argocd (s) | 3-kps (s) | 4-gitops (s) | 5-check (s) | 총 (s) | 어디서 샜나 / 다음에 바꿀 것 |
|---|---|---|---|---|---|---|---|---|
| 1 | 10/28 | | | | | | | |
| 2 | 10/29 | | | | | | | |
| 3 | 10/30 | | | | | | | |

목표: 3회차 총 1800s 이하. 첫 회는 이미지 다운로드(kindest/node, Argo CD, Prometheus, Grafana)가 들어가서 길다. 2회차부터 이미지 캐시가 남아 있으니 차이가 "진짜 부팅 시간" 이다.

## k3d / k3s 비교

| 방식 | 생성 ~ 노드 Ready (s) | 메모리 (k3s RSS 또는 docker stats) | 메모 |
|---|---|---|---|
| kind (드릴 1-kind) | | | |
| k3d (`k3d-boot.sh`) | | | |
| k3s multipass VM 2대 (`k3s-multipass.sh`) | VM 생성: / server: / agent join: | | 첫 회는 Ubuntu 이미지 다운로드 포함 |

## 알림 실험 (03-monitoring-basics.md 4절)

| 회차 | 에러 넣기 시작 | PENDING 보인 시각 | FIRING 보인 시각 | 걸린 시간 (s) | 에러 멈춘 뒤 해제까지 (s) |
|---|---|---|---|---|---|
| 1 | | | | | |

## 소감 (각 회차 한 줄)

- 1회차:
- 2회차:
- 3회차:
