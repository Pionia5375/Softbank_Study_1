variable "name" {
  description = "kind 클러스터 이름. kubectl context 는 kind-<name> 이 된다"
  type        = string
}

variable "node_image" {
  description = "노드 이미지. null 이면 provider 에 내장된 kind 라이브러리(v0.31) 기본값 kindest/node:v1.35.0 을 쓴다"
  type        = string
  default     = "kindest/node:v1.37.0"
  nullable    = true
}

variable "host_port" {
  description = "맥에서 curl 할 포트. 환경마다 달라야 두 클러스터가 같이 떠도 안 부딪힌다"
  type        = number
  default     = 8088
}

variable "node_port" {
  description = "클러스터 안쪽 포트 (Traefik NodePort). traefik-values.yaml 의 30080 과 맞춘다"
  type        = number
  default     = 30080
}

variable "workers" {
  description = "워커 노드 목록. 노드마다 라벨과 taint 를 준다. 빈 목록이면 control-plane 1대짜리"
  type = list(object({
    labels = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string # NoSchedule / PreferNoSchedule / NoExecute
    })), [])
  }))
  default = [
    { labels = { tier = "app" } },
    {
      labels = { tier = "batch" }
      taints = [{ key = "dedicated", value = "batch", effect = "NoSchedule" }]
    },
  ]
}
