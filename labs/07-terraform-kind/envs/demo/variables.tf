# 값은 terraform.tfvars 에서 채운다. dev 와 demo 는 이 파일까지 똑같고 tfvars 만 다르다

variable "cluster_name" {
  type = string
}

variable "host_port" {
  type = number
}

variable "workers" {
  type = list(object({
    labels = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
}

variable "hello_replicas" {
  type = number
}

variable "node_image" {
  type     = string
  default  = "kindest/node:v1.37.0"
  nullable = true
}
