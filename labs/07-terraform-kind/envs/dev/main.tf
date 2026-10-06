locals {
  # path.module = 이 폴더 (envs/dev). 어디서 terraform 을 실행해도 경로가 안 깨진다
  labs_dir = "${path.module}/../../.."
}

module "cluster" {
  source = "../../modules/cluster"

  name       = var.cluster_name
  node_image = var.node_image
  host_port  = var.host_port
  workers    = var.workers
}

module "platform" {
  source = "../../modules/platform"

  # cluster 모듈 output → platform 모듈 input. 이 연결 때문에 Terraform 은 클러스터를 먼저 만든다
  cluster_name     = module.cluster.name
  cluster_endpoint = module.cluster.endpoint
  host_port        = module.cluster.host_port

  traefik_values_file = "${local.labs_dir}/02-k8s-basics/traefik-values.yaml"
  hello_chart_path    = "${local.labs_dir}/04-k8s-rollout-hpa/chart/hello"
  hello_values_files  = ["${local.labs_dir}/04-k8s-rollout-hpa/chart/hello/values-demo.yaml"]
  hello_replicas      = var.hello_replicas
}
