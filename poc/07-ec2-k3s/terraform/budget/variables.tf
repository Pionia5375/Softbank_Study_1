variable "region" {
  description = "Budgets 는 전역 서비스지만 provider 에 리전이 있어야 한다"
  type        = string
  default     = "ap-northeast-2"
}

variable "budget_name" {
  type    = string
  default = "poc07-monthly"
}

variable "monthly_limit_usd" {
  description = "한 달 상한(USD). 10/27 하루 예상 비용이 약 2달러라 5달러면 사고만 잡는다"
  type        = number
  default     = 5
}

variable "alert_email" {
  description = "알림 받을 메일. tfvars 에만 적고 커밋하지 않는다"
  type        = string
}
