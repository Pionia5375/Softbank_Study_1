# ---- cluster 모듈 output 에서 받는 값 ----
variable "cluster_name" {
  description = "kind load 할 대상 클러스터 이름"
  type        = string
}

variable "cluster_endpoint" {
  description = "클러스터가 새로 만들어지면 바뀌는 값. 이미지를 다시 넣어야 하는지 판단하는 데 쓴다"
  type        = string
}

variable "host_port" {
  description = "출력용 (hello_url)"
  type        = number
}

# ---- Traefik ----
variable "traefik_values_file" {
  description = "Lab 02 traefik-values.yaml 경로 (NodePort 30080, 기본 IngressClass)"
  type        = string
}

variable "traefik_chart_version" {
  description = "null = 최신. 첫 apply 후 helm list -A 로 버전을 보고 고정하면 재현성이 올라간다"
  type        = string
  default     = null
}

# ---- metrics-server ----
variable "metrics_server_chart_version" {
  type    = string
  default = null
}

# ---- hello (Lab 04 차트) ----
variable "hello_image" {
  description = "맥 Docker 에 있는 이미지. kind 노드는 맥 이미지를 못 봐서 kind load 로 넣어 준다"
  type        = string
  default     = "lab01-hello:multi"
}

variable "hello_chart_path" {
  type = string
}

variable "hello_values_files" {
  description = "순서대로 겹쳐 쓴다 (helm -f a -f b 와 같음)"
  type        = list(string)
  default     = []
}

variable "hello_replicas" {
  description = "values 파일보다 우선한다 (helm --set 과 같음)"
  type        = number
  default     = 1
}
