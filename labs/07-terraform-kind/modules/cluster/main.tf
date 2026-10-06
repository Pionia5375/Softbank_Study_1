# kind 클러스터 1개 = Docker 컨테이너 (1 + 워커 수) 개.
# 주의: 이 provider 는 "수정" 을 못 한다. 아래 값을 하나라도 바꾸면 클러스터를 지우고 새로 만든다 (plan 에 -/+ 로 보인다).
resource "kind_cluster" "this" {
  name       = var.name
  node_image = var.node_image
  # true = 노드가 Ready 될 때까지 apply 가 기다린다. 다음 단계(helm)가 바로 붙을 수 있게
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      # Lab 02 kind-config.yaml 과 같은 역할: 맥 host_port → 노드 node_port
      extra_port_mappings {
        container_port = var.node_port
        host_port      = var.host_port
        protocol       = "TCP"
      }
    }

    # workers 목록 길이만큼 node 블록을 찍어 낸다
    dynamic "node" {
      for_each = var.workers
      content {
        role   = "worker"
        labels = node.value.labels

        # kind 설정 파일에는 taint 칸이 없다. 노드가 클러스터에 붙을 때(kubeadm join) 설정을 덧대서 넣는다
        kubeadm_config_patches = length(node.value.taints) == 0 ? [] : [
          yamlencode({
            kind = "JoinConfiguration"
            nodeRegistration = {
              taints = node.value.taints
            }
          })
        ]
      }
    }
  }
}
