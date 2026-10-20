# 네트워크: VPC 1개 + 퍼블릭 서브넷 2개(가용 영역 2곳) + 인터넷 게이트웨이.
#
# NAT 게이트웨이를 안 쓰는 이유: 시간당 요금이 이 실습 EC2 전부를 합친 것보다 비싸다.
# 대신 노드에 퍼블릭 IP 를 주고, 들어오는 문은 보안 그룹으로 닫는다 (security.tf).
# 서브넷을 2개 AZ 로 나눈 이유: 스팟 재고는 AZ 마다 달라서, 한 AZ 에 없으면 다른 AZ 에서 받는다.

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.project}-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.project}-igw" }
}

resource "aws_subnet" "public" {
  count                   = length(local.azs)
  vpc_id                  = aws_vpc.this.id
  availability_zone       = local.azs[count.index]
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 1) # 10.70.1.0/24, 10.70.2.0/24
  map_public_ip_on_launch = true

  tags = { Name = "${var.project}-public-${local.azs[count.index]}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = { Name = "${var.project}-public" }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
