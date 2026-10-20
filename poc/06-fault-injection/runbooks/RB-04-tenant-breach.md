로드맵 위치: 4주차 10/26 / 런북 RB-04 테넌트 간 침범 시도 / 본선 연결점: "남의 코드를 돌리는 플랫폼의 보안" 질문에 8개 시도 표로 답

# RB-04 테넌트 간 침범 시도

## 언제 이 문서를 여나
- 알림 `TenantPolicyDenied` (Pod Security 가 특권 파드·hostPath 를 거부)
- API 서버 403 이 한 서비스계정에서 몰려 나옴
- (Cilium) `hubble observe --verdict DROPPED` 에 한 테넌트에서 다른 테넌트로 가는 흐름이 반복

## 영향 (대역 실측)
- RBAC(R1·R2)·Pod Security(P1)·LimitRange(Q1): 4/4 막힘, 0.1~0.2초 (API 서버가 즉시 거절). `TenantPolicyDenied` 알림은 P1 뒤 28초.
- 네트워크(N1~N4): Calico 클러스터에서 4/4 막힘 (3.4초 타임아웃). 이 컨테이너의 kindnet 은 정책을 집행하지 못해 4/4 뚫림 → **CNI 가 정책을 실제로 집행하는지는 한 번 뚫어 봐야 안다.**
- tenant-b 정책만 지우면 N1·N2 는 tenant-a ingress 정책이 계속 막고, N3(API 서버)·N4(메타데이터) 는 뚫린다.

원본: `results/s4-tenant-breach*.csv`, README 8.4.

## 1분 안에 확인
```bash
kubectl get events -A --field-selector reason=FailedCreate | grep -i podsecurity | tail
#   PSA 가 거부한 기록 (어느 ns, 어떤 위반)
hubble observe --verdict DROPPED --from-namespace <의심 ns> --last 50     # Cilium 이면
#   어디로 가려다 막혔나 (목적지 ns/IP/포트)
kubectl auth can-i --list --as=system:serviceaccount:<ns>:<계정> -n <다른 ns>
#   그 계정이 다른 ns 에서 할 수 있는 게 정말 없나
kubectl get networkpolicy -A ; kubectl get ns -L pod-security.kubernetes.io/enforce
#   벽이 다 서 있나 (누가 지우지 않았나)
```

## 판단
| 보이는 것 | 뜻 | 할 일 |
|---|---|---|
| 거부·DROPPED 만 있고 성공한 흔적 없음 | 벽이 일했다. 하지만 누군가 시도 중 | 그 테넌트 함수 격리 (아래 1) |
| `s4-tenant-breach.sh` 에 FAIL 이 있다 | 벽이 빠져 있다 | 해당 벽 복구 (아래 2) 가 최우선 |
| 메타데이터(169.254.169.254) 접근이 성공 | EC2 에서 노드 IAM 자격 증명 노출 가능 | 즉시 2 + IMDSv2 hop limit 1 확인 (7단계) |

## 조치
1. 의심 테넌트 함수를 멈추고(scale 0) 이미지·코드를 보관. 그 서비스계정 토큰을 무효화하려면 서비스계정을 지우고 다시 만든다 (토큰은 계정에 묶여 있다).
2. 빠진 벽 복구는 Git 에서: 3단계 테넌트 리소스는 Argo CD 가 관리하므로 `kubectl -n argocd get application` 에서 OutOfSync 를 찾아 Sync. selfHeal 이 켜져 있으면 누가 지워도 몇 초 안에 다시 생긴다 (1단계 selfHeal 측정값이 곧 "벽 복구 시간").
3. `./scripts/s4-tenant-breach.sh` 를 다시 돌려 8/8 PASS 확인.

## 복구 확인
`s4-tenant-breach.sh` 마지막 줄 "결과: 전부 막힘 (8/8 PASS)"

## 재발 방지
- 벽 네 겹을 테넌트 생성 템플릿(3단계 ApplicationSet)에 묶어 두기: 테넌트를 만들면 벽이 같이 생기고, 벽만 따로 빠질 수 없게
- 네트워크 정책은 기본 거부(default-deny)부터. 열 것만 연다
- 4단계 gVisor: 위 벽을 다 넘어 커널 취약점을 쳐도 진짜 커널이 아니라 gVisor 를 친다 (다섯 번째 벽)
- `s4-tenant-breach.sh` 를 CI 나 일정 작업으로 매일 돌리기: 벽이 빠진 걸 공격자보다 먼저 안다

## 기록할 것
시도 시각, 어느 벽이 막았나, 감지 신호(알림·이벤트·hubble) 시각 → `results/s4-tenant-breach.csv`
