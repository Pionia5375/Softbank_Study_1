output "region" {
  value = var.region
}

output "server_instance_id" {
  description = "scripts/*.sh 가 SSM 접속 대상으로 쓴다"
  value       = aws_instance.server.id
}

output "server_private_ip" {
  value = aws_instance.server.private_ip
}

output "server_public_ip" {
  value = aws_instance.server.public_ip
}

output "exec_asg_name" {
  value = module.exec_pool.asg_name
}

output "build_asg_name" {
  value = module.build_pool.asg_name
}

output "fis_template_id" {
  value = var.enable_fis ? aws_fis_experiment_template.spot_interrupt[0].id : ""
}

output "ami_name" {
  description = "어떤 우분투 이미지로 떴는지 기록용"
  value       = data.aws_ami.ubuntu.name
}
