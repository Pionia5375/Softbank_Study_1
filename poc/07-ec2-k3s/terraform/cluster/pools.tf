# 워커 노드 풀 2개. 같은 모듈을 값만 바꿔 두 번 쓴다.

module "exec_pool" {
  source = "../modules/node-pool"

  name                  = "exec"
  project               = var.project
  ami_id                = data.aws_ami.ubuntu.id
  instance_types        = var.exec_instance_types
  capacity_type         = var.exec_capacity_type
  desired               = var.exec_desired
  max                   = var.exec_desired + 1
  subnet_ids            = aws_subnet.public[*].id
  security_group_ids    = [aws_security_group.nodes.id]
  instance_profile_name = aws_iam_instance_profile.node.name
  user_data             = local.agent_user_data["exec"]
  root_volume_gb        = var.root_volume_gb
  cpu_credits           = var.cpu_credits
  scale_down_recurrence = var.nightly_scale_down_cron
}

module "build_pool" {
  source = "../modules/node-pool"

  name                  = "build"
  project               = var.project
  ami_id                = data.aws_ami.ubuntu.id
  instance_types        = var.build_instance_types
  capacity_type         = var.build_capacity_type
  desired               = var.build_desired
  max                   = var.build_desired + 1
  subnet_ids            = aws_subnet.public[*].id
  security_group_ids    = [aws_security_group.nodes.id]
  instance_profile_name = aws_iam_instance_profile.node.name
  user_data             = local.agent_user_data["build"]
  root_volume_gb        = var.root_volume_gb
  cpu_credits           = var.cpu_credits
  scale_down_recurrence = var.nightly_scale_down_cron
}
