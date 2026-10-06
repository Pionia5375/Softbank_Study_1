# dev: 가볍게. 워커 1대(tier=app), hello 1개, 맥 8088
cluster_name   = "tf-dev"
host_port      = 8088
hello_replicas = 1

workers = [
  { labels = { tier = "app" } },
]
