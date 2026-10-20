로드맵 위치: 4주차 10/27 (화) / EC2 + 스팟 + k3s 당일 런북 / 본선 연결점: 본선 첫날 팀 계정에서 같은 순서로 환경을 세운다. 클라우드 활용 30점의 "실측 숫자"가 여기서 나온다

# 10/27 런북: 예산 → 만들기 → 측정 → 지우기

> ⚠️ 이 문서의 `apply`·`destroy`·`start-experiment` 는 전부 **Jeong 이 로컬 맥에서 직접** 실행한다. 클라우드 스레드는 실행하지 않는다.
> 시작 전 조건: README 4.1·4.2 빈칸 다 채움 + **main 에 push 완료** (Argo CD 는 GitHub 에서 읽는다).

시간 계획 (합계 약 4시간 【추정】, 켜져 있는 시간 ≈ 3시간 → 약 $0.5)

| 시각 | 단계 | 켜져 있는 EC2 |
|---|---|---|
| 09:00 | A. 사전 점검 + 예산 | 0 |
| 09:30 | B. apply + 노드 확인 | 4 |
| 10:15 | C. Argo CD + 배치 확인 | 4 |
| 11:00 | D. 스팟 회수 실험 ×3 | 4~5 |
| 12:00 | E. 깨뜨렸다 고치기 + 셀프 연습 | 3~4 |
| 12:45 | F. destroy + 잔여 확인 | 0 |
| 다음 날 | G. 실제 청구액 기록 | 0 |

모든 명령은 이 폴더에서: `cd ~/softbank_study_1/Softbank_Study_1/poc/07-ec2-k3s`

---

## A. 사전 점검 + 예산 (돈 안 드는 것부터)

```bash
git pull --rebase origin main            # 다른 단계 변경까지 최신으로
aws sts get-caller-identity              # 어느 계정·사용자로 붙어 있나. Account 번호를 확인
aws configure get region                 # 비어 있거나 다르면: export AWS_REGION=ap-northeast-2
grep -rn ___ k3s gitops                  # 빈칸 0 확인
./scripts/render-k3s.sh                  # 템플릿 최종 검사 (README 4.1)
```

예산 알람 (한 번만, 지우지 않는다)
```bash
cd terraform/budget
cp terraform.tfvars.example terraform.tfvars   # 그다음 alert_email 을 내 메일로 고친다
terraform init                                  # aws provider 내려받기
terraform plan                                  # 만들 것: aws_budgets_budget 1개. "1 to add" 인지 본다
terraform apply                                 # yes 입력. 예산 하나 생성 (무료 【추정】)
aws budgets describe-budgets --account-id "$(aws sts get-caller-identity --query Account --output text)" \
  --query 'Budgets[].[BudgetName,BudgetLimit.Amount]' --output table   # 생겼나 확인
cd ../..
```
- 이미 10/6 에 만든 $1 예산이 있으면 그대로 두고 이건 추가로 둔다(둘 다 메일 옴).

NTH 차트 버전 고정 (README 4.2) → 바뀌었으면 commit + push.

현재 스팟 가격 확인 → README 7절 표 숫자 고치기 (README 7절 "확인 명령").

**체크**: 예산 생성됨 / 빈칸 0 / push 됨. 하나라도 아니면 B 로 가지 않는다.

---

## B. 만들기 (여기서부터 과금)

```bash
cd terraform/cluster
cp terraform.tfvars.example terraform.tfvars
# ingress_cidrs 를 내 IP/32 로:  curl -s https://checkip.amazonaws.com
terraform init
terraform plan -out=day.tfplan
```
plan 에서 볼 것 (아니면 멈춘다)
- `Plan: N to add, 0 to change, 0 to destroy` — 처음이면 change·destroy 가 0
- `aws_instance.server` 1개, `aws_autoscaling_group` 2개, `aws_nat_gateway` 는 **없어야** 함
- `aws_vpc_security_group_ingress_rule` 에 22, 6443 이 **없어야** 함

```bash
cd ../..
./scripts/measure.sh up            # = terraform apply -auto-approve + 시간 기록. 기대 2~4분 【추정】
```
바로 이어서 (다른 터미널 창 두 개)
```bash
# 창 1: 터널 (켜 둔다)
./scripts/tunnel.sh
# 창 2:
./scripts/get-kubeconfig.sh                       # SSM 등록 + k3s 설치 끝날 때까지 기다렸다가 ./kubeconfig 저장
export KUBECONFIG=$PWD/kubeconfig
./scripts/measure.sh ready 4                      # 4대 Ready 까지 시간
kubectl get nodes -L pool,capacity-type -o wide   # 라벨 확인
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints[*].key
kubectl -n kube-system get pods -o wide           # coredns·traefik·metrics-server 가 어느 노드에 떴나 (1.4절 【추정】 확인)
```
**출력 붙여 주기**: `kubectl get nodes -L pool,capacity-type` 결과.

---

## C. Argo CD + 배치 확인

```bash
./scripts/bootstrap-argocd.sh          # 막히면 --solution
./scripts/measure.sh argo              # 모든 Application Synced+Healthy 까지 시간
kubectl -n argocd get applications
kubectl -n argocd get pods -o wide     # 전부 시스템 노드인지
kubectl -n placement-check get pods -o wide
kubectl -n kube-system get ds -l app.kubernetes.io/name=aws-node-termination-handler -o wide   # NTH 가 스팟 노드 수만큼(2)
```
함수 호출
```bash
EXEC_IP=$(aws ec2 describe-instances --filters Name=tag:Pool,Values=exec Name=instance-state-name,Values=running \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)   # 실행 노드 하나의 퍼블릭 IP
curl -s http://$EXEC_IP/fn | head -3                                       # whoami 응답
for i in 1 2 3 4 5 6; do curl -s http://$EXEC_IP/fn | grep Hostname; done   # 두 파드가 번갈아 응답하나
```
Argo UI (선택): `kubectl -n argocd port-forward svc/argocd-server 8080:80` → http://localhost:8080 (비밀번호는 1단계와 같은 방법).

**출력 붙여 주기**: `kubectl -n placement-check get pods -o wide`.

---

## D. 스팟 회수 실험 (3회)

```bash
./scripts/measure.sh spot http://$EXEC_IP/fn
```
- 하는 일: FIS 실험 시작(실행 노드 1대에 "2분 뒤 회수") → NTH 가 cordon 할 때까지 → fn-sample 2개가 다른 노드에서 Ready 일 때까지 → 교체 노드가 붙어 실행 노드 수가 원래대로 될 때까지 시간 + 그동안 0.5초마다 호출한 실패 수.
- 주의: `EXEC_IP` 노드가 회수 대상이 되면 그 IP 로의 curl 이 전부 실패한다(노드 자체가 사라지니까). 이건 "외부 진입점이 노드 IP 하나" 라서 생기는 실패다. 숫자를 그대로 적고, 설계 문서에 "본선에선 앞단에 NLB/ALB 를 둔다" 한 줄 (대안 비교 거리).
- 실험 사이에 남은 NotReady 노드 정리: `kubectl get nodes | grep NotReady` → `kubectl delete node <이름>`.
- 지켜보기(선택, 다른 창): `kubectl get nodes -w`, `kubectl -n placement-check get pods -o wide -w`, `kubectl -n kube-system logs -l app.kubernetes.io/name=aws-node-termination-handler -f`.

**출력 붙여 주기**: `grep spot results/times.csv`.

---

## E. 깨뜨렸다 고치기 + 셀프 연습

README 6절(toleration 지우기) → README 셀프 연습(빌드 풀 0 → 1 콜드 스타트). 둘 다 숫자 한 줄씩 남긴다.

---

## F. 지우기 (당일 필수)

```bash
./scripts/measure.sh down                     # = terraform destroy -auto-approve + 시간 기록
./scripts/check-leftovers.sh                  # 기대: == 통과: 과금 리소스 없음
```
- 실패 항목이 있으면: 그 ID 를 콘솔에서 확인 → 손으로 지우고 다시 `check-leftovers.sh`.
- `terraform/budget` 은 **지우지 않는다.**
- 터널 창(Ctrl+C), `unset KUBECONFIG`, `rm kubeconfig` (토큰이 든 파일).
- 측정 결과 커밋: `git add results/times.csv && git commit -m "poc07: 10/27 measurements" && git pull --rebase origin main && git push origin main`.

23:00 에 실행·빌드 풀이 자동으로 0대가 되는 예약은 destroy 와 함께 사라진다. **시스템 노드는 예약이 없다** → destroy 를 잊으면 그대로 과금된다.

---

## G. 다음 날

- Cost Explorer → 10/27, Service 별 → EC2-Instances, EC2-Other(EBS·IPv4), FIS 합계를 README 7절 아래에 "실측" 한 줄.
- 추정($0.17/h × 켜진 시간)과 차이가 20% 넘으면 이유 한 줄 (스팟가 변동, 크레딧, 데이터 전송 등).
