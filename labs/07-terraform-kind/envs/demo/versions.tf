terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  # backend 블록이 없으면 state 는 이 폴더의 terraform.tfstate (local state).
  # 팀이 같이 쓰는 원격 state + lock 은 10/12~13 에서 다룬다.

  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.11.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3"
    }
  }
}

# helm 이 붙을 클러스터 = cluster 모듈의 output. 클러스터가 아직 없으면 apply 중에 값이 채워진다
provider "helm" {
  kubernetes = {
    host                   = module.cluster.endpoint
    client_certificate     = module.cluster.client_certificate
    client_key             = module.cluster.client_key
    cluster_ca_certificate = module.cluster.cluster_ca_certificate
  }
}
