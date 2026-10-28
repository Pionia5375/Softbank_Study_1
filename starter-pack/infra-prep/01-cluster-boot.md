로드맵 위치: 본선 D-10 / 쿠버네티스 클러스터는 어떻게 "부팅" 되나 (kind · k3d · k3s · EKS) / 본선 연결점: 1일차에 "로컬은 뭘로, 데모는 뭘로" 를 비용·시간·운영 부담으로 말하기 (클라우드 활용 30, 팀 개발 20)

# 01. 클러스터 부팅 원리: kind / k3d / k3s / EKS

읽는 순서: 1절(클러스터가 뭐로 되어 있나) → 2절(kind) → 3절(k3d) → 4절(k3s 손으로) → 5절(EKS 읽기만) → 6절(kubeconfig) → 7절(비교표와 1일차 할 말).
손으로 하는 건 2절(드릴로 대신), 3절(15분), 4절(90분) 이다.

---

## 1. 클러스터는 무엇으로 되어 있나 (0부터)

"쿠버네티스 클러스터를 띄운다" = 아래 프로그램들을 켜고 서로 연결한다. 도구(kind, k3s, EKS)가 다른 건 **누가, 어디에, 어떻게 이 프로그램들을 켜느냐** 뿐이다.

| 프로그램 | 하는 일 | 어디에 |
|---|---|---|
| **kube-apiserver** | 모든 명령이 들어오는 문. `kubectl apply` 는 여기에 HTTP 요청을 보내는 것 | 컨트롤 플레인 |
| **etcd** (또는 대체 DB) | 클러스터의 "현재 상태 전부" 가 들어 있는 저장소. apiserver 만 여기 쓴다 | 컨트롤 플레인 |
| **kube-scheduler** | "이 파드를 어느 노드에 놓을까" 결정만 한다 (실행은 안 함) | 컨트롤 플레인 |
| **kube-controller-manager** | "원하는 상태(3개) ≠ 지금 상태(2개)" 를 계속 비교하고 맞추는 루프 묶음 (Deployment, ReplicaSet, Node 등) | 컨트롤 플레인 |
| **kubelet** | 노드마다 1개. apiserver 를 보고 "내 노드에 놓인 파드" 를 컨테이너 런타임에게 시킨다. 프로브도 kubelet 이 찌른다 | 모든 노드 |
| **컨테이너 런타임** (containerd) | 실제로 이미지를 받고 컨테이너를 켠다 | 모든 노드 |
| **kube-proxy** | Service 의 가상 IP 로 온 패킷을 파드 IP 로 돌리는 규칙(iptables/ipvs)을 노드마다 만든다 | 모든 노드 |
| **CNI 플러그인** (kindnet, flannel, Cilium, VPC CNI) | 파드에 IP 를 주고, 노드가 달라도 파드끼리 통하게 한다. **클러스터 만들 때 정한다** | 모든 노드 |
| **CoreDNS** | `podinfo.podinfo.svc` 같은 이름 → IP. 파드로 돈다 | 파드 |

부팅 순서는 항상 같다: ① 컨트롤 플레인 노드에서 etcd → apiserver → scheduler/controller-manager 를 켠다 ② 그 노드의 kubelet 이 apiserver 에 자기를 등록한다 ③ CNI 를 깔아야 노드가 `Ready` 가 된다 ④ 워커 노드의 kubelet 이 **토큰** 을 들고 apiserver 에 "나도 끼워 줘"(join) 한다 ⑤ CoreDNS 같은 기본 파드가 뜬다.

이 순서를 알면 "노드가 NotReady" 는 거의 CNI, "join 이 안 됨" 은 토큰·네트워크·시간 차이, "apiserver 에 못 붙음" 은 kubeconfig 주소·인증서 문제라고 바로 좁힐 수 있다.

---

## 2. kind: 노드 = Docker 컨테이너

**무엇**: `kindest/node` 라는 이미지 안에 containerd + kubelet + kubeadm 이 들어 있다. `kind create cluster` 는
1. 노드 수만큼 그 이미지로 컨테이너를 켠다 (`docker ps` 에 `prep-control-plane`, `prep-worker` 로 보인다)
2. 컨트롤 플레인 컨테이너 안에서 `kubeadm init` 을 돌려 1절의 컨트롤 플레인 프로그램들을 **그 컨테이너 안의 파드(static pod)** 로 띄운다
3. 워커 컨테이너 안에서 `kubeadm join` 을 돌린다 (토큰은 kind 가 알아서 넘긴다)
4. CNI(kindnet)와 local-path 스토리지를 깐다
5. `~/.kube/config` 에 `kind-prep` 컨텍스트를 써 준다

【사실: https://kind.sigs.k8s.io/docs/design/initial/ 】

**왜 연습 기본으로 쓰나**: 가장 가볍고(노드 추가 = 컨테이너 1개), 설정 파일 하나로 노드 수·포트·CNI 끄기·taint 까지 재현되고, 이미 Lab 02~05 로 손에 익었다. 【사실: `labs/02` 측정, 클러스터 생성 30.5초】

**한계**: 노드가 "진짜 꺼지는" 일이 없다(장애 연습은 `docker stop` 으로 흉내). LoadBalancer 타입 Service 가 기본으로는 안 된다(NodePort + extraPortMappings 로 대신). 맥 바깥에서 접근할 주소가 없다(GitHub webhook 못 받음).

**손으로 볼 것** (드릴 1회차 때, 2분):
```bash
docker ps --format '{{.Names}}\t{{.Image}}'            # 노드 = 컨테이너 3개
docker exec prep-control-plane crictl ps | head         # 컨테이너 안에서 도는 apiserver·etcd·scheduler 컨테이너들
kubectl -n kube-system get pods -o wide                 # 같은 것을 파드로 본 모습 + kindnet·coredns
kubectl get nodes -o wide                               # INTERNAL-IP 가 Docker 네트워크 IP
```

확인 질문 1개: `kubectl -n kube-system get pods` 에서 `etcd-prep-control-plane` 처럼 노드 이름이 붙은 파드 4종은 무엇이고, 왜 Deployment 가 아닐까? (답: static pod. kubelet 이 `/etc/kubernetes/manifests/` 파일을 보고 직접 띄운다. apiserver 가 아직 없을 때도 떠야 하니까.)

---

## 3. k3d: k3s 를 Docker 안에 (15분)

**무엇**: kind 와 같은 발상(노드 = 컨테이너)인데 안에서 도는 게 kubeadm 이 아니라 **k3s** 다. 추가로 앞에 작은 로드밸런서 컨테이너(nginx)를 하나 세워서 `-p 9899:80@loadbalancer` 같은 포트 매핑을 받아 준다. 【사실: https://k3d.io/stable/ 】

**언제**: "k3s 의 기본 부품이 뭐가 깔리나" 를 빨리 보고 싶을 때, 그리고 본선에서 로컬을 k3s 로 맞춰야 할 때 (EC2 에 k3s 를 쓰면 로컬도 k3d 로 맞추는 게 차이가 적다).

할 일:
- `brew install k3d` (없으면)
- `starter-pack/infra-prep/scripts/k3d-boot.sh` 를 **먼저 읽고** (주석이 명령 한 줄씩 설명) 돌린다
- 출력의 `kube-system` 파드 목록을 드릴(kind) 의 `kubectl -n kube-system get pods` 와 나란히 놓고 차이를 본다
- `starter-pack/infra-prep/scripts/k3d-boot.sh delete`

확인 질문 1개: k3d 클러스터의 `kube-system` 에는 있고 kind 에는 없는 파드가 3~4개 있다. 무엇이고, 그게 왜 k3s 의 "배터리 포함" 이라는 말과 이어지나? (답: metrics-server, local-path-provisioner, (끄지 않았다면) traefik, svclb-*. k3s 는 "설치하면 바로 쓸 수 있게" 가 설계 목표라 인그레스·스토리지·지표를 기본으로 넣었다.)

---

## 4. k3s: 진짜 노드 2대를 토큰으로 묶기 (90분, 핵심)

### 4.1 k3s 가 뭔가

**무엇**: 쿠버네티스 전체를 **바이너리 하나(약 70MB)** 에 넣은 배포판. `k3s server` 프로세스 하나가 apiserver·scheduler·controller-manager·kubelet·containerd·flannel(CNI)·kube-proxy 를 **한 프로세스 안에서** 돌린다. etcd 대신 기본은 SQLite(1대일 때), 여러 대면 내장 etcd 를 켤 수 있다. `k3s agent` 는 kubelet·containerd·flannel·kube-proxy 만 돌린다. 【사실: https://docs.k3s.io/architecture 】

**왜 EC2 에 많이 쓰나**: 설치가 `curl | sh` 한 줄 + systemd 서비스라 user_data 에 그대로 들어간다. 메모리가 적게 든다(서버 512MB 권장 【사실: https://docs.k3s.io/installation/requirements 】). 작년 본선 우승팀(kOps)과 예선 부산 우승팀(k3s)은 둘 다 "EC2 위에 직접 k8s" 였다【사실: notes/research/career/03】. 매니지드(EKS)가 아니라서 컨트롤 플레인도 내 책임이지만, 그만큼 "직접 세웠다" 를 보여 줄 수 있고 시간당 과금이 없다.

**poc/07 과의 관계**: `poc/07-ec2-k3s/k3s/install.sh.tftpl` 의 마지막 줄이 정확히 아래 4.2 의 명령이다. 다만 거기서는 옵션을 `/etc/rancher/k3s/config.yaml` 파일에 모아 두고, 토큰을 Terraform 이 미리 정해서 server·agent 양쪽에 넣는다 (그래야 agent 가 server 의 토큰 파일을 읽으러 갈 필요가 없다). 여기서는 "server 가 만든 토큰을 읽어서 agent 에 넘기는" 가장 원시적인 순서로 한다. 둘 다 해 보면 왜 Terraform 쪽이 그렇게 생겼는지 이해된다.

### 4.2 손으로 (첫 번째는 스크립트 말고 한 줄씩)

사전: `brew install --cask multipass` (Ubuntu VM 을 한 줄로 띄우는 도구. VM 1대 = EC2 1대라고 생각). 첫 `launch` 는 이미지(약 700MB 【추정】)를 받느라 몇 분 걸린다.

```bash
# 1) VM 2대. --cpus/--memory/--disk 는 t3.small 비슷하게
multipass launch 24.04 --name k3s-server --cpus 2 --memory 2G --disk 10G
multipass launch 24.04 --name k3s-agent  --cpus 2 --memory 2G --disk 10G
multipass list                          # 둘 다 Running, IPv4 가 보인다

# 2) server 설치. multipass exec <VM> -- <명령> = VM 안에서 명령 실행 (EC2 라면 ssh 또는 SSM)
#    curl -sfL https://get.k3s.io  = 공식 설치 스크립트 받기 (-s 조용히, -f 실패면 에러, -L 리다이렉트 따라가기)
#    | sh -s - server ...            = 그 스크립트를 셸로 실행하면서 "server 로, 이 옵션으로" 를 넘긴다
#    --write-kubeconfig-mode 644     = kubeconfig 파일을 root 아닌 사용자도 읽게 (실습 편의)
#    --node-label pool=system        = 노드 라벨 (poc/07 server-config 와 같은 뜻)
multipass exec k3s-server -- bash -c 'curl -sfL https://get.k3s.io | sh -s - server --write-kubeconfig-mode 644 --node-label pool=system'

# 3) server 안에서 무슨 일이 났나 (여기서 1절 그림이 눈에 보인다)
multipass exec k3s-server -- systemctl status k3s --no-pager | head -5    # systemd 서비스 k3s 가 active
multipass exec k3s-server -- sudo k3s kubectl get nodes                    # 노드 1개 Ready (k3s 안에 kubectl 도 들어 있다)
multipass exec k3s-server -- sudo k3s kubectl -n kube-system get pods     # coredns, traefik, metrics-server, local-path, svclb
multipass exec k3s-server -- ps -o pid,rss,cmd -C k3s                      # 프로세스 '하나' 가 전부 돌린다. RSS = 메모리(KB)

# 4) agent 가 붙을 때 필요한 둘: server 의 토큰과 IP
multipass exec k3s-server -- sudo cat /var/lib/rancher/k3s/server/node-token     # K10...::server:... 모양
multipass info k3s-server | grep IPv4

# 5) agent 설치. 환경변수 K3S_URL 과 K3S_TOKEN 이 있으면 설치 스크립트가 "agent 로" 깐다
#    (아래 <IP>, <TOKEN> 을 4) 의 값으로 바꾼다)
multipass exec k3s-agent -- bash -c 'curl -sfL https://get.k3s.io | K3S_URL=https://<IP>:6443 K3S_TOKEN=<TOKEN> sh -s - agent --node-label pool=exec'

# 6) 묶였나
multipass exec k3s-server -- sudo k3s kubectl get nodes -o wide -L pool     # 2개 Ready, 라벨 system / exec

# 7) 맥에서 직접 kubectl 로 붙기: kubeconfig 를 가져오되 주소를 127.0.0.1 → VM IP 로
multipass exec k3s-server -- cat /etc/rancher/k3s/k3s.yaml | sed 's/127.0.0.1/<IP>/' > ~/.kube/k3s-multipass.yaml
export KUBECONFIG=~/.kube/k3s-multipass.yaml
kubectl get nodes
unset KUBECONFIG                        # 끝나면 원래(kind) 로

# 8) 지우기
multipass delete --purge k3s-server k3s-agent
```

두 번째부터는 `starter-pack/infra-prep/scripts/k3s-multipass.sh` 로 한 번에 돌리고 시간을 잰다 (스크립트도 같은 순서, 주석 포함).

### 4.3 일부러 깨뜨려 보기 (각 10분, 하나만 골라도 됨)

- **토큰 틀리게**: 5) 에서 TOKEN 끝 글자를 바꾼다 → agent 가 못 붙는다. `multipass exec k3s-agent -- sudo journalctl -u k3s-agent -n 20` 에서 무슨 메시지가 나오나. (본선에서 "노드가 안 붙어요" 의 1순위 원인)
- **server 를 끈다**: `multipass exec k3s-server -- sudo systemctl stop k3s` → 맥에서 `kubectl get nodes` 는 실패하지만, agent 의 파드는 계속 돈다 (`multipass exec k3s-agent -- sudo crictl ps`). 컨트롤 플레인이 죽어도 "이미 도는 것" 은 안 죽는다는 것을 눈으로 본다. 다시 `start`.
- **agent 를 통째로 지운다** (`multipass delete --purge k3s-agent`): 노드가 `NotReady` 가 되고, 기본 5분 뒤 그 노드의 파드가 다른 노드로 옮겨진다 (`poc/06` 시나리오 1 과 같은 상황. 5분이 `--pod-eviction-timeout` / taint 기반 축출 기본값).

### 4.4 꼭 남길 숫자

`results/drill.md` 의 k3s 표에: VM 2대 생성 시간, server 설치 ~ 노드 Ready, agent join ~ Ready, `ps` 의 k3s RSS(MB). 3~5회면 좋지만 1회라도.

확인 질문 1개: 4.2 의 2) 와 5) 는 둘 다 같은 스크립트(`get.k3s.io`)를 받는다. 무엇이 server 와 agent 를 가르나? (답: `sh -s - server|agent` 의 인자, 그리고 `K3S_URL` 환경변수가 있으면 agent 로 본다. 【사실: https://docs.k3s.io/reference/env-variables 】)

---

## 5. EKS: 읽기만 (30분, 생성 금지)

**무엇**: 1절의 **컨트롤 플레인(apiserver·etcd·scheduler·controller-manager)을 AWS 가 대신 운영** 한다. 내 계정 VPC 안에는 워커 노드(EC2)만 있고, 컨트롤 플레인은 AWS 계정 쪽에서 여러 AZ 에 걸쳐 돈다. 노드는 ① 매니지드 노드 그룹(ASG 를 EKS 가 관리) ② 셀프 매니지드(내가 ASG 를 만듦, k3s 처럼) ③ Fargate(노드 없이 파드만) ④ Auto Mode(노드까지 AWS 가 알아서) 중 고른다. 【사실: https://docs.aws.amazon.com/eks/latest/userguide/eks-compute.html 】

**어떻게 부팅되나**: `eksctl create cluster` 또는 Terraform(`aws_eks_cluster` + `aws_eks_node_group`) → AWS 가 컨트롤 플레인을 만들고(이 단계만 10분 안팎 【추정】) → 노드 그룹의 EC2 가 부팅하면서 user_data 의 `bootstrap.sh`/nodeadm 이 kubelet 을 그 apiserver 에 join 시킨다 → VPC CNI(파드가 VPC IP 를 직접 받음), CoreDNS, kube-proxy 가 애드온으로 깔린다. 인증은 IAM 이다: `aws eks update-kubeconfig` 가 써 주는 kubeconfig 는 "`aws eks get-token` 을 실행해서 토큰을 받아라" 는 exec 설정이라 kubectl 이 매번 IAM 자격으로 토큰을 받는다.

**비용**: 클러스터 1개당 시간당 $0.10 (컨트롤 플레인, 표준 지원) + 노드 EC2 값 【사실: https://aws.amazon.com/eks/pricing/ 기준; 최신 금액은 당일 확인】. 이틀 켜 두면 컨트롤 플레인만 약 $5. 노드가 더 든다.

**1일차에 할 말**: "EKS 는 컨트롤 플레인 운영을 안 해도 되고 IAM·VPC 통합이 좋다. 대신 만드는 데 15~20분, 지우는 데 10분이라 **실수하면 되돌리는 비용이 크고**, 우리가 '직접 세웠다' 를 보여 줄 부분이 줄어든다. 예산 30만원과 이틀이면 EC2 + k3s(또는 kubeadm)가 더 보여 줄 게 많다. 단, 팀에 EKS 운영 경험자가 있고 주제가 매니지드 전제라면 EKS." 어느 쪽이든 **Terraform 으로 세우고 Argo CD 로 올리는 것은 같다** 는 말을 붙인다.

읽을 것 (각 5분): eksctl 시작 페이지 https://eksctl.io/getting-started/ , EKS 요금 https://aws.amazon.com/eks/pricing/ , `poc/07/README.md` 1.3절(k3s vs EKS 비교, 이미 써 둠).

---

## 6. kubeconfig 와 컨텍스트 (사고 방지, 20분)

**무엇**: `kubectl` 은 `~/.kube/config`(또는 `KUBECONFIG` 환경변수가 가리키는 파일)를 읽어 "어느 apiserver 에, 어떤 인증으로" 를 정한다. 그 묶음 하나가 **컨텍스트** 다. kind 는 `kind-<이름>`, k3d 는 `k3d-<이름>`, EKS 는 ARN 모양 이름으로 컨텍스트를 만든다.

1일차에는 컨텍스트가 셋 이상 된다(내 kind, 내 k3d, 팀 공용 EC2). **`kubectl delete` 를 엉뚱한 클러스터에 치는 사고** 가 여기서 난다.

습관 3개:
```bash
kubectl config get-contexts                 # * 가 지금 컨텍스트
kubectl config current-context              # apply/delete 전에 한 번
kubectx                                     # brew install kubectx. 이름만 쳐서 전환, kubectx - 로 직전으로
```
- 셸 프롬프트에 컨텍스트 표시 (starship 이나 kube-ps1). 데모 화면에서도 보여서 좋다.
- 팀 공용 클러스터 kubeconfig 는 **Slack 에 파일로 올리지 않는다** (admin 인증서가 들어 있다). 1Password 공유나 직접 전달. 여유가 있으면 사람마다 ServiceAccount + RBAC 토큰(`poc/03` 에서 해 본 것).
- `KUBECONFIG=a.yaml:b.yaml kubectl config view --flatten > merged.yaml` 로 합칠 수 있다.

---

## 7. 비교표와 결론

| | kind | k3d | k3s (VM/EC2) | EKS |
|---|---|---|---|---|
| 노드의 정체 | Docker 컨테이너 | Docker 컨테이너 | 진짜 머신(VM/EC2) | EC2 (컨트롤 플레인은 AWS) |
| 컨트롤 플레인 | kubeadm, 내 맥 | k3s, 내 맥 | k3s server, 내 머신 | AWS 운영 |
| 기본 CNI | kindnet | flannel | flannel | VPC CNI |
| 생성 시간 | 약 30초~1분 【사실: labs/02 30.5s】 | 약 30초 【추정】 | VM 포함 3~5분, 첫 회는 이미지 받기 추가 【추정】 | 15~20분 【추정】 |
| 메모리 | 노드당 수백 MB 【추정】 | 비슷 | VM 당 1~2GB 잡아야 | 해당 없음(돈) |
| 비용 | 0 | 0 | 0 (EC2 면 인스턴스 값) | $0.10/h + EC2 |
| 노드 장애 연습 | `docker stop` 흉내 | 같음 | **진짜로 끌 수 있다** | 노드 그룹 축소 |
| 맥 밖 접근 | 없음 | 없음 | VM IP / EC2 퍼블릭 IP | 있음 |
| 쓰임 | 연습·개발 기본 | k3s 로컬 맞춤 | **데모 후보 1순위** | 팀에 경험자 있을 때 |

**결론**: 연습은 kind(드릴), k3s 는 multipass 로 한 번 손으로 + 깨뜨리기 하나, k3d 는 15분 맛보기, EKS 는 읽기만. 1일차에 "로컬 kind/k3d → 데모 EC2 k3s, 둘 다 Terraform + Argo CD" 를 기본안으로 내고, 팀 상황 보고 바꾼다.

---

## 핵심 결정 3개 (+대안)

1. **k3s 연습을 multipass VM 2대로**. 대안: k3d 만 / `poc/07` 을 AWS 에 apply. 이유: "토큰으로 join" "server 를 꺼도 파드는 산다" 는 VM 이어야 보인다. AWS 는 승인·비용·당일 destroy 가 붙고 지금 익힐 건 명령 자체라 로컬 VM 이 맞다.
2. **드릴은 kind + kindnet(Cilium 없이)**. 대안: `poc/04` 설정(Cilium + taint). 이유: 드릴 목적은 "빨리, 매번 같게". Cilium 은 3~5분과 메모리를 더 쓰고 주제에 따라 안 쓸 수도 있다. 필요하면 `poc/04/scripts/rebuild-cluster.sh` 가 이미 있다.
3. **EKS 는 만들지 않는다**. 대안: 10/29 에 eksctl 로 한 번. 이유: 생성·삭제 30분 + 비용 + 프로젝트 금지 규칙. 1일차에 필요한 건 "왜 EKS 가 아니라 k3s 인가(또는 반대)" 를 말하는 것이고 그건 읽어서 된다.

## 셀프 연습 1개

k3s server 에서 `sudo k3s kubectl -n kube-system get pods` 에 보이는 `svclb-traefik-*` 파드가 무엇인지 알아내고, kind 에서는 왜 LoadBalancer Service 가 `<pending>` 으로 남는지 두 줄로 적는다. (힌트: k3s 의 ServiceLB(klipper-lb)는 노드 포트를 hostPort 로 여는 DaemonSet 이다. 【사실: https://docs.k3s.io/networking/networking-services#service-load-balancer 】)

## 검증 명령과 기대 출력

```bash
# kind (드릴 뒤)
kubectl --context kind-prep get nodes            # prep-control-plane, prep-worker, prep-worker2 모두 Ready
docker ps --format '{{.Names}}' | grep prep      # 컨테이너 3개

# k3d
kubectl --context k3d-prep-k3d -n kube-system get pods   # coredns, local-path-provisioner, metrics-server (traefik 은 껐음)

# k3s multipass
KUBECONFIG=~/.kube/k3s-multipass.yaml kubectl get nodes -L pool
#   k3s-server   Ready   control-plane,master   pool=system
#   k3s-agent    Ready   <none>                 pool=exec
```
