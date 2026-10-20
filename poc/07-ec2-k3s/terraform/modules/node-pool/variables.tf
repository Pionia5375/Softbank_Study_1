variable "name" {
  description = "풀 이름. 태그 Pool 값과 노드 라벨 pool 값으로도 쓰인다 (exec / build)"
  type        = string
}

variable "project" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "instance_types" {
  description = "후보 인스턴스 타입들. 스팟은 여러 개를 줘야 한 타입이 모자랄 때 다른 타입으로 받는다"
  type        = list(string)
}

variable "capacity_type" {
  description = "spot 또는 on-demand"
  type        = string

  validation {
    condition     = contains(["spot", "on-demand"], var.capacity_type)
    error_message = "capacity_type 은 spot 또는 on-demand 만 된다."
  }
}

variable "desired" {
  description = "평소 노드 수"
  type        = number
}

variable "max" {
  description = "최대 노드 수 (스팟 회수 직후 교체 노드가 잠깐 겹칠 수 있어 desired 보다 1 크게)"
  type        = number
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "instance_profile_name" {
  type = string
}

variable "user_data" {
  description = "부팅 때 실행할 스크립트 (k3s agent 설치). 평문으로 받아서 여기서 base64 로 바꾼다"
  type        = string
}

variable "root_volume_gb" {
  type    = number
  default = 20
}

variable "cpu_credits" {
  description = "t 계열 CPU 크레딧. standard = 다 쓰면 느려짐(추가 요금 없음), unlimited = 안 느려지는 대신 초과분 과금"
  type        = string
  default     = "standard"
}

variable "scale_down_recurrence" {
  description = "이 cron 시각(서울 시간)에 풀을 0대로 줄인다. 깜빡하고 안 지웠을 때의 안전망. 빈 문자열이면 안 만든다"
  type        = string
  default     = ""
}
