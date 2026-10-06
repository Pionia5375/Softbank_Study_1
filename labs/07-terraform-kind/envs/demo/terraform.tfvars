# demo: 발표용 모양. 워커 2대(app / batch+taint), hello 3개, 맥 8089 (dev 8088 과 안 부딪히게)
cluster_name   = "tf-demo"
host_port      = 8089
hello_replicas = 3

workers = [
  { labels = { tier = "app" } },
  {
    labels = { tier = "batch" }
    # batch 노드: 이 taint 를 견디는(toleration) Pod 만 올라간다. 지금 차트들은 없어서 전부 app 노드로 간다
    taints = [{ key = "dedicated", value = "batch", effect = "NoSchedule" }]
  },
]
