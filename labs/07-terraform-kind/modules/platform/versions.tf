terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  required_providers {
    helm = {
      source = "hashicorp/helm"
      # 3.x 부터 set 이 블록 → 리스트, provider 의 kubernetes 가 블록 → 속성(= {...}) 으로 바뀌었다
      version = "~> 3.3"
    }
  }
}
