terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  required_providers {
    kind = {
      source = "tehcyx/kind"
      # 0.x 는 마이너 버전에서도 바뀔 수 있어서 패치만 허용 (0.11.x)
      version = "~> 0.11.0"
    }
  }
}
