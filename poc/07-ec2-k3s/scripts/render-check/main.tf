# AWS 없이 k3s 템플릿 3개를 채워 보는 검사용 설정. provider 가 없어서 인터넷·AWS 계정 없이 돈다.
# scripts/render-k3s.sh 가 이걸 실행한다. 값은 가짜(토큰·IP)지만 모양은 실제 user_data 와 같다.

variable "dir" {
  type = string
}

locals {
  server = templatefile("${var.dir}/install.sh.tftpl", {
    role        = "server"
    k3s_channel = "stable"
    config      = templatefile("${var.dir}/server-config.yaml.tftpl", { token = "FAKE-TOKEN" })
  })

  agent = {
    for pool, capacity_type in { exec = "spot", build = "on-demand" } :
    pool => templatefile("${var.dir}/install.sh.tftpl", {
      role        = "agent"
      k3s_channel = "stable"
      config = templatefile("${var.dir}/agent-config.yaml.tftpl", {
        token         = "FAKE-TOKEN"
        server_url    = "https://10.70.1.10:6443"
        pool          = pool
        capacity_type = capacity_type
      })
    })
  }
}

output "server" {
  value = local.server
}

output "exec" {
  value = local.agent["exec"]
}

output "build" {
  value = local.agent["build"]
}
