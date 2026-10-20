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

# (선택) enable_gvisor = true 일 때 실행 노드 user_data = exec + gvisor.sh.tftpl
output "exec_gvisor" {
  value = join("", [local.agent["exec"], templatefile("${path.module}/../../terraform/cluster/gvisor.sh.tftpl", { gvisor_version = "20261012.0" })])
}

output "build" {
  value = local.agent["build"]
}
