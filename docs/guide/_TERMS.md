# 용어 기준표 (00장 용어집에서 자동 추출, 2차 검수 후 재생성)

## 쿠버네티스 기본
- **컨테이너 (container)**: 프로그램과 그 실행 환경을 한 묶음으로 격리해 돌리는 단위. 이미지(image)는 그 묶음을 담은 파일이고, 레지스트리(registry)는 이미지를 올리고(push) 받는(pull) 저장소다. 6장
- **클러스터 / 노드 (node)**: 노드는 파드가 실제로 도는 서버 한 대, 클러스터는 노드들과 그것을 지휘하는 컨트롤 플레인을 합친 전체. kind 에선 노드 하나가 Docker 컨테이너 하나. 3장
- **파드 (Pod)**: 쿠버네티스가 컨테이너를 띄우는 최소 단위. 같은 노드에서 함께 뜨는 컨테이너 한두 개(예: 함수 + queue-proxy)를 묶는다. 5장
- **API 서버 · etcd · 스케줄러 · 컨트롤러**: 쿠버네티스의 컨트롤 플레인. 모든 요청이 들어오는 문, 상태 저장소, 파드의 자리 고르기, 원하는 상태와 실제를 계속 맞추는 루프. 3장
- **kubelet · containerd**: 노드마다 도는 에이전트(파드를 실제로 띄우고 상태를 보고)와 컨테이너 런타임(컨테이너를 실제로 만들고 돌림). kubelet 의 하트비트가 끊기면 노드 장애가 시작된다. 8장
- **Deployment / ReplicaSet**: 같은 파드를 N 개 유지하며 새 버전으로 굴려 바꾸는 리소스와, 그 아래에서 실제로 N 개를 유지하는 리소스(버전마다 하나). Rollout 은 Deployment 의 자리에 들어가는 대체품. 2장
- **Service / EndpointSlice**: 파드가 바뀌어도 변하지 않는 안정된 주소와, 그 뒤에 지금 붙어 있는 파드 주소 목록. 파드가 NotReady 면 목록에서 빠진다. 8장
- **Job / ConfigMap**: 끝나면 멈추는 일회성 파드를 돌리는 리소스(빌드)와, 설정이나 파일을 담아 파드에 꽂는 리소스(함수 소스). 7장
- **라벨 (label) / annotation**: 리소스에 붙이는 키=값. 라벨은 "어떤 파드" 를 고르는 열쇠(Service, NetworkPolicy, 스케줄링), annotation 은 고르기에 쓰지 않는 메모(min-scale, build-id). 3장
- **kubectl / kubeconfig / 매니페스트**: API 서버에 말하는 명령, 어느 클러스터에 어떤 계정으로 붙을지 적은 파일, 리소스를 적은 YAML. 1장
- **커널 / 시스템 콜 (syscall)**: 운영체제의 핵심(프로세스·메모리·네트워크·파일 관리)과, 프로그램이 그 기능을 부르는 호출. 컨테이너는 호스트 커널을 공유하므로 gVisor 가 시스템 콜을 가로채 격리한다. 6장

## GitOps 와 배포
- **GitOps**: 클러스터의 원하는 상태를 Git 에 두고, 클러스터 안의 에이전트가 Git 을 읽어 맞추는 방식. 사람은 클러스터 대신 Git 을 고친다. 1장
- **Argo CD**: GitOps 에이전트. Git 을 폴링해 렌더하고, 클러스터와 비교해 apply 한다. 이 PoC 는 Helm 차트 10.10.5(v3.5.5). 1장
- **Application**: Argo CD 의 기본 단위. "이 레포의 이 폴더를 이 클러스터의 이 namespace 에" 라는 한 장짜리 약속. 최종 클러스터에 10개. 1장
- **App of Apps**: Application 들을 담은 폴더를 가리키는 Application(root). 폴더에 YAML 을 더하고 push 하면 새 Application 이 생긴다. 1장
- **ApplicationSet**: 생성기(generator)로 Application 을 찍어 내는 틀. 03 은 Git files generator 로 tenants/*.yaml 하나마다 Application 하나. 3장
- **AppProject**: Application 묶음의 울타리. 갈 수 있는 namespace, 만들 수 없는 리소스 종류를 정한다. 테넌트 project 는 자기 ns 만, Quota·NetworkPolicy·RBAC 금지. 3장
- **Sync 상태 (Synced / OutOfSync)**: Git 과 클러스터가 같은가. 비교를 못 하면 Unknown. Health 와 따로 본다. 1장
- **Health 상태 (Healthy / Progressing / Degraded)**: 리소스가 잘 도는가. Healthy·Progressing·Degraded 외에 Suspended(일시 중지)·Missing(없음)·Unknown 이 있다. 카나리 abort 뒤에는 Synced + Degraded 가 된다. 2장
- **자동 치유 (selfHeal)**: 누가 클러스터를 손으로 바꾸면 Argo CD 가 Git 상태로 되돌리는 옵션. 1장
- **정리 (prune)**: Git 에서 지운 리소스를 클러스터에서도 지우는 옵션. 1장
- **폴링 주기 (timeout.reconciliation)**: Argo CD 가 Git 을 다시 보는 간격. 이 PoC 는 120초 + jitter 60초. 1장
- **Helm**: 템플릿 + values 로 매니페스트를 만드는 패키지 도구. Argo CD 는 helm template 으로만 쓴다. 1장
- **valuesObject**: Application 안에 Helm values 를 직접 적는 필드. bye-fn 이 hello-fn 차트를 메시지만 바꿔 재사용한다. 1장
- **Argo Rollouts**: Deployment 대신 Rollout 리소스로 카나리·블루그린을 하는 컨트롤러. v1.10.1. 2장
- **카나리 (canary)**: 새 버전을 일부에만 먼저 보내 보고 넓히는 배포. podinfo 는 20% → 60% → 100%. 2장
- **setWeight / pause**: Rollout 단계. 트래픽 라우터가 없으면 비율을 파드 수로 흉내 낸다. 2장
- **AnalysisTemplate / AnalysisRun**: "무엇을 재서 어떻게 판정하나" 의 틀과 그 실행. 성공률 0.95 미만이면 Failed. 2장
- **abort**: 분석이 실패하면 카나리를 0 으로 줄이고 stable 로 돌아가는 것. Git 은 그대로라 revert 가 따로 필요하다. 2장
- **fail-closed**: 판단이 불가능하면(질의 오류) 안전한 쪽(멈춤)을 고르는 설계. 2장
- **Prometheus**: 지표를 긁어 모으고(scrape) PromQL 로 묻는 시계열 DB. 10초마다 긁는다. 2장
- **pod-template-hash**: Deployment 가 만든 ReplicaSet 마다 다른 파드 라벨. Rollout 은 같은 역할의 rollouts-pod-template-hash 를 쓴다. 02 는 후자로 카나리 파드만 골라 재고, 06 은 전자를 흩어 놓기 기준(matchLabelKeys)으로 쓴다. 2장

## 테넌트와 네트워크
- **멀티테넌시 (multi-tenancy)**: 한 클러스터를 여러 고객(테넌트)이 서로 모른 채 나눠 쓰는 것. 이 PoC 는 namespace 하나 = 테넌트 하나. 3장
- **namespace**: 이름과 권한을 나누는 칸. 패킷과 CPU 는 나누지 않는다. 그래서 울타리 리소스가 더 필요하다. 3장
- **tenant 차트**: 03 의 Helm 차트. namespace, ResourceQuota, LimitRange, NetworkPolicy, RBAC, AppProject 를 한 번에 만든다. 3장
- **ResourceQuota**: namespace 전체의 CPU·메모리·파드 수 한도. tenant-a 는 파드 10, tenant-b 는 5. 3장
- **LimitRange**: 컨테이너 하나의 기본값과 상한. requests 를 안 적은 파드도 Quota 계산에 들어가게 해 준다. 3장
- **PSA (Pod Security Admission)**: namespace 라벨로 파드 보안 수준(privileged·baseline·restricted)을 강제하는 기본 기능. 테넌트는 baseline 강제 + restricted 경고. 3장
- **RBAC**: Role·ClusterRole(권한 목록)과 RoleBinding·ClusterRoleBinding(누구에게, 어디서). 이 PoC 의 "진짜 벽". 3장
- **ServiceAccount**: 파드나 프로그램이 API 서버에 쓰는 계정. control-plane, ops-agent, deployer. 7장
- **노드 풀 (node pool)**: 같은 역할의 노드 묶음. 라벨 pool=system|build|exec. 3장
- **taint / toleration**: 노드가 "이것을 견디는 파드만 와라" 고 거는 표시와, 파드가 "견딘다" 고 다는 표시. 3장
- **nodeSelector**: 파드가 "이 라벨 노드로만" 가겠다는 조건. toleration 과 짝을 이뤄야 풀에 고정된다. 3장
- **NetworkPolicy**: 파드 사이 연결을 라벨로 허용하는 규칙. 아무것도 없으면 전부 허용, 하나라도 고르면 그 파드는 허용 목록만(들어오는 ingress 와 나가는 egress 방향별로 따로). 4장
- **default-deny**: 모든 파드를 고르고 허용 규칙은 비운 정책. 그 위에 같은 ns · DNS · 플랫폼 ns 허용을 쌓는다. 4장
- **allow-from-namespaces**: tenant-a 에서 knative-serving·kourier-system 출발 연결을 여는 정책. 없으면 "READY 인데 타임아웃". 4장
- **CNI (Container Network Interface)**: 노드에 파드 네트워크를 꽂는 플러그인 표준과 그 구현(kindnet, Cilium, flannel). NetworkPolicy 집행도 CNI 구현의 일이다. kind 기본 kindnet 도 kind v0.24 부터 표준 NetworkPolicy 를 집행한다(kube-network-policies 내장). Cilium 을 고른 이유는 집행 여부가 아니라 Hubble 관측과 L7 정책이다. 4장
- **Cilium**: eBPF 기반 CNI. 정책을 커널에서 집행한다. 1.20.3. 4장
- **eBPF**: 커널 안에서 안전하게 도는 작은 프로그램. Cilium 이 패킷 경로에 붙인다. 4장
- **Hubble**: Cilium 의 흐름 관찰 도구. hubble observe --verdict DROPPED 로 막힌 패킷을 본다. 4장
- **Kourier**: Knative 용 가벼운 인그레스(Envoy). Host 헤더로 함수를 고른다. 4장
- **Host 헤더 라우팅**: 같은 IP·포트로 들어와도 Host 값(hello.tenant-a.faas.local)으로 대상을 고르는 것. 4장
- **NodePort**: 모든 노드의 같은 포트로 Service 를 여는 방식. Kourier 는 31080. 4장
- **extraPortMappings**: kind 노드 컨테이너의 포트를 맥 포트에 묶는 설정. 맥 8081 → 31080. 4장

## 서버리스, 빌드, 런타임
- **FaaS (Function as a Service)**: 코드 조각만 올리면 플랫폼이 빌드·배포·확장·축소를 맡는 서비스 모양. 5장
- **Knative Serving**: 쿠버네티스 위의 서버리스 계층. 요청 수로 파드를 0 까지 줄이고 늘린다. v1.23.0. 5장
- **Knative Service (ksvc)**: 함수 하나. Configuration·Revision·Route 를 만들어 낸다. 5장
- **Revision**: template 이 바뀔 때마다 생기는 바꿀 수 없는 스냅샷. 롤백은 "traffic 을 옛 Revision 으로". 5장
- **traffic**: Revision 별 비율. 기본은 latestRevision: true, percent: 100. 에이전트 rollback 은 특정 Revision 에 고정한다. 5장
- **scale-to-zero**: 요청이 없으면 파드를 0개로. 자원은 아끼고 첫 요청은 느려진다. 5장
- **콜드 스타트 (cold start)**: 파드 0개 상태에서 첫 요청이 파드가 뜰 때까지 기다리는 것. 5장
- **activator**: 파드가 0개일 때 요청을 대신 받아 붙잡고, 파드가 뜨면 넘기는 Knative 부품. 파드가 있어도 여유 용량(target-burst-capacity)이 모자라면 요청 경로에 계속 끼어 있다. 우리 설정(기본값 211)에서는 항상 끼어 있다. 5장
- **autoscaler (KPA)**: 동시 요청 수를 보고 파드 수를 정하는 Knative 부품. PodAutoscaler 리소스를 쓴다. 5장
- **queue-proxy**: 함수 컨테이너 옆에 붙는 사이드카. 동시 요청 수를 재어 autoscaler 가 1초마다 긁어 가는 지표로 내놓고(알리는 게 아니라 긁어 가는 구조), containerConcurrency 를 넘는 요청은 줄 세운다. 5장
- **min-scale / max-scale**: 파드 수 하한·상한 annotation. 컨트롤 플레인은 max 5 만 적고, min 은 에이전트 몫으로 비워 둔다. 5장
- **containerConcurrency**: 파드 하나가 동시에 받는 요청 수 상한. 05 함수는 10. 5장
- **stable window**: autoscaler 가 평균을 내는 시간. 짧으면 빨리 줄어든다. 04 함수는 6초. 5장
- **kaniko**: Docker 데몬 없이 컨테이너 안에서 이미지를 빌드·push 하는 도구. v1.23.2. 프로젝트는 아카이브되어 더 개발되지 않는다(본선이면 BuildKit rootless 같은 대안 검토). 6장
- **digest (sha256)**: 이미지 내용의 해시. 태그와 달리 바뀌지 않는다. 05 는 digest 로 배포해 "무엇이 도는지" 를 고정한다. 6장
- **termination message**: 컨테이너가 끝날 때 /dev/termination-log 에 쓴 글. kaniko 가 digest 를 여기 남긴다. 7장
- **kind-registry**: 맥의 Docker 에서 도는 registry:2. 노드에선 kind-registry:5000(push), kubelet 은 localhost:5001(pull, hosts.toml 로 연결). 6장
- **RuntimeClass**: 파드가 어떤 컨테이너 런타임 핸들러로 돌지 고르는 리소스. gvisor → runsc. 6장
- **gVisor (runsc)**: 사용자 공간 커널로 시스템 콜을 가로채는 샌드박스 런타임. 남의 코드를 돌릴 때 커널 공격면을 줄인다. 6장
- **runc**: 기본 컨테이너 런타임. 호스트 커널을 그대로 쓴다. 6장

## 컨트롤 플레인과 에이전트
- **컨트롤 플레인 (이 PoC 의 뜻)**: 함수 배포 API 를 가진 Spring Boot 서비스. 쿠버네티스 컨트롤 플레인(API 서버·etcd·스케줄러·컨트롤러 매니저가 도는 control-plane 노드)과 다른 말이다. 각 장은 쿠버네티스 쪽을 말할 때 "control-plane 노드" 또는 "쿠버네티스 컨트롤 플레인" 이라고 구분해 쓴다. 7장
- **fabric8**: 자바용 쿠버네티스 클라이언트. Job 생성, watch, server-side apply 를 한다. 7장
- **가상 스레드 (virtual thread)**: JVM 이 가볍게 만드는 스레드. 빌드 대기처럼 오래 막히는 일을 요청 스레드에서 떼어 낸다. 7장
- **202 Accepted + Location**: "받았다, 결과는 저 주소로 물어봐라" 응답. 오래 걸리는 작업의 표준 모양. 7장
- **멱등 (idempotent)**: 같은 요청을 몇 번 보내도 결과가 같은 성질. 같은 코드 = 같은 buildId = 빌드 재사용. 7장
- **server-side apply (SSA)**: "내가 적은 필드는 이 값" 을 API 서버가 필드 주인(field manager)별로 관리하는 apply. 7장
- **field manager**: SSA 에서 필드의 주인 이름. 컨트롤 플레인은 faas-control-plane. 7장
- **ownerReference**: "이 리소스의 주인은 저것" 표시. 주인이 지워지면 쓰레기 수집기가 같이 지운다. 소스 ConfigMap → 빌드 Job. 7장
- **ttlSecondsAfterFinished**: 끝난 Job 을 몇 초 뒤 지울지. 빌드 Job 은 3600. 7장
- **MCP (Model Context Protocol)**: AI 애플리케이션(호스트·클라이언트)이 외부 서버의 도구(tools)·자원(resources)·프롬프트를 표준 방식으로 쓰게 하는 규약. 전송은 stdio 또는 Streamable HTTP. ops_mcp 는 stdio 로 get_metrics·scale·rollback 세 도구를 낸다. 7장
- **가드레일 (guardrail)**: 에이전트가 할 수 있는 일을 좁히는 겹겹의 장치. 범위 고정 · RBAC · 승인 · 한도/dry-run · 감사. 7장
- **사람 승인 (human-in-the-loop)**: 되돌리기 어려운 동작은 사람이 터미널에서 승인해야 실행. 1회용, 900초, 인자에 묶임. 7장
- **감사 로그 (audit log)**: 누가 언제 무엇을 시도했고 결과가 무엇인지 남긴 줄. 거절도 남긴다. 7장
- **TokenRequest**: ServiceAccount 의 짧게 사는 토큰을 발급하는 API. kubectl create token. 7장

## 장애와 클라우드
- **장애 주입 (fault injection)**: 일부러 노드·배포·설정을 망가뜨려 시스템의 반응을 재는 실험. 8장
- **대역 클러스터 (stand-in)**: 06 이 쓰는 kind-chaos. faas 와 노드 역할은 비슷하지만 taint 없음, kindnet. 8장
- **NotReady / Unknown**: 노드 하트비트가 grace period(기본 50초) 넘게 없을 때의 노드 상태(Unknown). kubelet 이 살아 있어도 CNI 가 안 깔려 파드 네트워크가 준비 안 되면(NetworkReady=false) NotReady 가 된다. 8장
- **Lease (kube-node-lease)**: kubelet 이 주기적으로 갱신하는 하트비트 리소스. 8장
- **tolerationSeconds**: NoExecute taint 를 몇 초 견딘 뒤 쫓겨날지. 기본 300, 06 방어는 20. 8장
- **topologySpreadConstraints**: 파드를 노드·존마다 고르게 흩는 규칙. maxSkew, whenUnsatisfiable, nodeTaintsPolicy. 8장
- **PodDisruptionBudget (PDB)**: drain 같은 자발적 중단 때 최소 몇 개는 남겨 두라는 약속. 노드 장애(비자발적)는 막지 못한다. 8장
- **cordon / drain**: 노드에 새 파드를 막기 / 기존 파드를 PDB 를 지키며 내보내기. 스팟 예고 대응의 기본. 8장
- **합성 프로브 (synthetic probe)**: 밖에서 정해진 주기로 함수를 불러 성공·실패를 기록하는 스크립트. 사용자 체감의 대리 지표. 8장
- **런북 (runbook)**: 알림이 울렸을 때 사람이 따라 할 절차. RB-01 ~ RB-04. 8장
- **k3s**: 바이너리 하나로 된 가벼운 쿠버네티스 배포판. 기본 CNI flannel, 기본 인그레스 Traefik, NetworkPolicy 는 내장 컨트롤러(kube-router 기반)가 집행. 9장
- **스팟 인스턴스 (Spot)**: 남는 EC2 를 싸게 쓰되 2분 예고 후 회수될 수 있는 구매 방식. exec 풀에 쓴다. 9장
- **ASG (Auto Scaling Group)**: 같은 Launch Template 으로 EC2 수를 유지하는 묶음. 예약으로 매일 23:00 에 0. 9장
- **NTH (Node Termination Handler)**: 스팟 회수 예고를 받아 노드를 cordon·drain 하는 AWS 도구. 9장
- **FIS (Fault Injection Service)**: AWS 의 장애 주입 서비스. 스팟 중단 예고를 일부러 보낸다. 9장
- **SSM 포트 포워딩**: 인바운드 포트를 열지 않고 AWS Systems Manager 로 6443 에 터널을 뚫는 방법. 9장
- **Terraform**: 인프라를 코드로 선언하고 plan/apply 로 맞추는 도구. 07 의 VPC·EC2·ASG·예산. 9장