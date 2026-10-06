# 클러스터 위에 올리는 것들: Traefik → metrics-server → (이미지 넣기) → hello
# helm provider 설정은 이 모듈이 아니라 envs/* 쪽에 있다. 모듈 안에 provider 를 두면 destroy 순서가 꼬이기 쉽다.

resource "helm_release" "traefik" {
  name             = "traefik"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  version          = var.traefik_chart_version
  namespace        = "traefik"
  create_namespace = true

  # Lab 02 의 values 파일을 그대로 읽는다 (helm install -f traefik-values.yaml 과 같음)
  values = [file(var.traefik_values_file)]
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.metrics_server_chart_version
  namespace  = "kube-system"

  # kind kubelet 인증서는 자체 서명이라 검증을 끈다 (로컬 실습 전용). Lab 04 의 --set 'args={...}' 와 같은 뜻
  values = [yamlencode({ args = ["--kubelet-insecure-tls"] })]
}

# kind provider 에는 "이미지 넣기" 리소스가 없다. 그래서 CLI 를 대신 불러 준다.
# provisioner 는 Terraform 이 결과를 추적 못 하는 최후 수단이다: 노드 안 이미지를 지워도 state 는 모른다.
resource "terraform_data" "load_hello_image" {
  # 이 값이 바뀔 때만 다시 실행된다. 클러스터를 새로 만들면 endpoint 가 바뀌어서 다시 넣는다
  triggers_replace = [var.cluster_name, var.cluster_endpoint, var.hello_image]

  provisioner "local-exec" {
    command = "kind load docker-image ${var.hello_image} --name ${var.cluster_name}"
  }
}

resource "helm_release" "hello" {
  name      = "hello"
  chart     = var.hello_chart_path # 로컬 폴더 경로면 repository 없이 바로 읽는다
  namespace = "default"

  values = [for f in var.hello_values_files : file(f)]

  # helm provider 3.x 문법: set = [ {name, value}, ... ] 리스트
  set = [
    { name = "replicaCount", value = tostring(var.hello_replicas) },
  ]

  # TODO(human): wait 를 true 로 둘지 false 로 둘지.
  #   추천 기본값 true: Pod 가 Ready 될 때까지 apply 가 안 끝난다 → apply 끝 = curl 되는 상태, 측정 숫자가 정직해진다.
  #   false 로 하면 apply 는 빨라지지만 drill.sh 의 "첫 200 까지" 시간이 그만큼 늘어난다. 둘 다 재 보고 하나 고르기.
  wait    = true
  timeout = 300 # 초. Spring 기동 + 이미지 3개 Ready 여유

  # 이미지가 노드에 있어야 Pod 가 뜨고, Traefik(IngressClass)이 있어야 Ingress 가 붙는다
  depends_on = [terraform_data.load_hello_image, helm_release.traefik]
}
