# 시스템 노드 = k3s server (컨트롤 플레인 + 내장 etcd 대신 SQLite) 1대, 온디맨드.
#
# 스팟을 안 쓰는 이유: 이게 회수되면 클러스터 API 가 통째로 사라진다.
# ASG 를 안 쓰는 이유: 새로 뜬 server 는 빈 클러스터라 자동 교체의 의미가 없다 (데이터가 디스크에 있음).
# HA(server 3대)는 비용 3배라 이번엔 안 한다 → README 결정 1.

resource "aws_instance" "server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.system_instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.nodes.id]
  iam_instance_profile   = aws_iam_instance_profile.node.name
  user_data              = local.server_user_data

  # user_data 를 고치면 인스턴스를 새로 만든다 (부팅 스크립트는 첫 부팅에만 돌기 때문)
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  credit_specification {
    cpu_credits = var.cpu_credits
  }

  root_block_device {
    volume_size           = var.root_volume_gb
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name         = "${var.project}-system"
    Pool         = "system"
    CapacityType = "on-demand"
  }

  # 라우팅이 먼저 있어야 부팅 직후 k3s 설치 스크립트를 내려받을 수 있다
  depends_on = [aws_route_table_association.public]
}
