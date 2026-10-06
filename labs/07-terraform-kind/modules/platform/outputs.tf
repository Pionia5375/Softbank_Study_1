output "hello_url" {
  value = "http://localhost:${var.host_port}/hello"
}

output "releases" {
  description = "설치된 차트 버전 (버전 고정할 때 참고)"
  value = {
    traefik        = helm_release.traefik.metadata.version
    metrics_server = helm_release.metrics_server.metadata.version
    hello          = helm_release.hello.metadata.version
  }
}
