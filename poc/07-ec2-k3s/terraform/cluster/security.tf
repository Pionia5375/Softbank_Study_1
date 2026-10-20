# 보안 그룹 1개를 모든 노드가 같이 쓴다.
#   - 노드끼리는 전부 허용 (k3s API 6443, kubelet 10250, flannel VXLAN 8472/udp 등을 하나하나 안 연다)
#   - 바깥 → 노드: 80/443 만, ingress_cidrs 에 적은 주소만. 기본값은 빈 목록 = 닫힘
#   - SSH(22)·k3s API(6443)는 바깥에 안 연다. 접속은 SSM Session Manager 로 (iam.tf, scripts/tunnel.sh)

resource "aws_security_group" "nodes" {
  name        = "${var.project}-nodes"
  description = "k3s nodes"
  vpc_id      = aws_vpc.this.id

  tags = { Name = "${var.project}-nodes" }
}

resource "aws_vpc_security_group_ingress_rule" "self" {
  security_group_id            = aws_security_group.nodes.id
  referenced_security_group_id = aws_security_group.nodes.id
  ip_protocol                  = "-1"
  description                  = "node to node, all"
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  for_each          = toset(var.ingress_cidrs)
  security_group_id = aws_security_group.nodes.id
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  description       = "traefik http"
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  for_each          = toset(var.ingress_cidrs)
  security_group_id = aws_security_group.nodes.id
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "traefik https"
}

# 나가는 건 전부 허용: k3s 설치 스크립트, 컨테이너 이미지, GitHub(Argo CD), SSM 엔드포인트
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.nodes.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
