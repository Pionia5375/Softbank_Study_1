output "cluster_name" {
  value = module.cluster.name
}

output "host_port" {
  value = module.cluster.host_port
}

output "kubectl_context" {
  value = "kind-${module.cluster.name}"
}

output "kubeconfig_path" {
  value = module.cluster.kubeconfig_path
}

output "hello_url" {
  value = module.platform.hello_url
}

output "releases" {
  value = module.platform.releases
}
