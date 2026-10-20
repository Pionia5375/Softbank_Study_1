terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.region

  # 이 provider 로 만드는 모든 리소스에 붙는 태그. check-leftovers.sh 가 Project 태그로 남은 걸 찾는다
  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
      Owner     = "jeong"
    }
  }
}
