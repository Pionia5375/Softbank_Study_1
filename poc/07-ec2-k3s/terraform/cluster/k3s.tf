# k3s 에 넘길 값과 user_data 조립.
#
# 역할 분담
#   Claude(이 파일): 토큰 만들기, 서버 주소 넘기기, 템플릿 파일을 읽어 user_data 로 조립
#   Jeong(k3s/ 폴더): 무엇을 설치하고 노드에 어떤 라벨·taint 를 붙일지 (템플릿 3개)
#
# templatefile(경로, 값들) = 파일을 읽어서 ${이름} 자리에 값을 끼워 넣은 문자열을 돌려준다.

# 노드가 클러스터에 붙을 때 쓰는 공유 비밀번호. state 파일에 평문으로 남는다 → state 는 커밋 금지(.gitignore)
resource "random_password" "k3s_token" {
  length  = 48
  special = false
}

# 우분투 24.04 공식 이미지 중 최신. Canonical 의 AWS 계정 번호가 owner
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  tpl = var.k3s_template_dir

  server_config = templatefile("${path.module}/${local.tpl}/server-config.yaml.tftpl", {
    token = random_password.k3s_token.result
  })

  server_user_data = templatefile("${path.module}/${local.tpl}/install.sh.tftpl", {
    role        = "server"
    k3s_channel = var.k3s_channel
    config      = local.server_config
  })

  agent_user_data = {
    for pool, capacity_type in {
      exec  = var.exec_capacity_type
      build = var.build_capacity_type
    } :
    pool => join("", [
      templatefile("${path.module}/${local.tpl}/install.sh.tftpl", {
        role        = "agent"
        k3s_channel = var.k3s_channel
        config = templatefile("${path.module}/${local.tpl}/agent-config.yaml.tftpl", {
          token         = random_password.k3s_token.result
          server_url    = "https://${aws_instance.server.private_ip}:6443"
          pool          = pool
          capacity_type = capacity_type
        })
      }),
      # (선택) 실행 풀에만 gVisor 설치를 뒤에 붙인다. Claude 작성 파일이라 k3s_template_dir 과 상관없이 이 폴더에 있다
      var.enable_gvisor && pool == "exec" ? templatefile("${path.module}/gvisor.sh.tftpl", {
        gvisor_version = var.gvisor_version
      }) : "",
    ])
  }
}
