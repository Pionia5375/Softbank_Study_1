# 이 값들이 platform 모듈(그리고 envs/* 의 helm provider)의 입력이 된다 = 모듈 output → input

output "name" {
  value = kind_cluster.this.name
}

output "endpoint" {
  description = "API 서버 주소. https://127.0.0.1:<랜덤 포트>. 클러스터를 새로 만들면 바뀐다"
  value       = kind_cluster.this.endpoint
}

output "host_port" {
  value = var.host_port
}

output "kubeconfig_path" {
  description = "kind provider 가 떨군 kubeconfig 파일 경로 (terraform 실행 폴더/<name>-config)"
  value       = kind_cluster.this.kubeconfig_path
}

output "kubeconfig" {
  value     = kind_cluster.this.kubeconfig
  sensitive = true # 화면에 안 찍힌다. state 파일에는 평문으로 남는다
}

output "client_certificate" {
  value     = kind_cluster.this.client_certificate
  sensitive = true
}

output "client_key" {
  value     = kind_cluster.this.client_key
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = kind_cluster.this.cluster_ca_certificate
  sensitive = true
}
