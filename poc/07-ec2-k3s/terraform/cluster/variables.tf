variable "region" {
  description = "서울. 도쿄(ap-northeast-1)로 바꾸면 가격이 조금 오른다 (README 비용 표 참고)"
  type        = string
  default     = "ap-northeast-2"
}

variable "project" {
  description = "이름 앞머리 + Project 태그 값"
  type        = string
  default     = "poc07"
}

variable "vpc_cidr" {
  type    = string
  default = "10.70.0.0/16"
}

variable "ingress_cidrs" {
  description = "80/443 으로 함수(Traefik)에 들어올 수 있는 주소. 기본은 비워 둠 = 아무도 못 들어옴. 내 IP 는 curl -s https://checkip.amazonaws.com"
  type        = list(string)
  default     = []
}

# ---- k3s ----

variable "k3s_channel" {
  description = "k3s 설치 채널. stable = 그 시점 안정판. 실제 설치된 버전은 kubectl get nodes 로 기록한다"
  type        = string
  default     = "stable"
}

variable "k3s_template_dir" {
  description = "Jeong 이 쓴 k3s 템플릿 폴더. 막히면 ../../solution/k3s 로 바꿔서 정답본으로 띄운다"
  type        = string
  default     = "../../k3s"
}

# ---- 시스템 노드 (k3s server, 온디맨드 1대) ----

variable "system_instance_type" {
  description = "k3s server + Argo CD + Traefik. 2 vCPU / 4 GiB"
  type        = string
  default     = "t3.medium"
}

# ---- 실행 노드 풀 (함수 파드, 스팟) ----

variable "exec_instance_types" {
  description = "스팟 후보. 같은 크기(2 vCPU / 4 GiB)의 다른 타입을 같이 줘야 한 타입 재고가 없을 때 버틴다"
  type        = list(string)
  default     = ["t3.medium", "t3a.medium"]
}

variable "exec_capacity_type" {
  type    = string
  default = "spot"
}

variable "exec_desired" {
  description = "2대 = 스팟 1대가 회수돼도 함수가 나머지 1대에서 계속 돈다. 1대면 교체 노드가 붙을 때까지 끊긴다"
  type        = number
  default     = 2
}

# ---- 빌드 노드 풀 (이미지 빌드 Job) ----

variable "build_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "build_capacity_type" {
  description = "빌드는 중간에 끊기면 처음부터 다시라 기본은 온디맨드. README 결정 2 참고"
  type        = string
  default     = "on-demand"
}

variable "build_desired" {
  description = "빌드 안 할 땐 0 으로 두면 돈이 안 나간다"
  type        = number
  default     = 1
}

# ---- 공통 ----

variable "root_volume_gb" {
  type    = number
  default = 20
}

variable "cpu_credits" {
  type    = string
  default = "standard"
}

variable "nightly_scale_down_cron" {
  description = "실행·빌드 풀을 0대로 줄이는 시각 (cron, 서울 시간). 기본 매일 23:00. 빈 문자열이면 안 만든다"
  type        = string
  default     = "0 23 * * *"
}

variable "enable_fis" {
  description = "스팟 회수 연습용 FIS 실험 템플릿을 만들지. 템플릿 자체는 무료, 실행할 때만 과금"
  type        = bool
  default     = true
}

# ---- (선택) gVisor: 4단계에서 kind 로 못 잰 runc vs gVisor 콜드 스타트를 EC2 에서 ----

variable "enable_gvisor" {
  description = "true 면 실행 풀 노드 첫 부팅 때 gVisor(runsc)를 깔고 k3s containerd 에 등록한다 (README 8.5절)"
  type        = bool
  default     = false
}

variable "gvisor_version" {
  description = "gVisor 릴리스. 4단계 scripts/install-gvisor.sh 와 같은 값으로 맞춘다"
  type        = string
  default     = "20261012.0"
}
