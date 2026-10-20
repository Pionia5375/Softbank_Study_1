# 노드가 SSM(Session Manager)에 등록되게 하는 역할.
# 이게 있으면 SSH 키·22번 포트 없이 `aws ssm start-session` 으로 셸에 들어가고,
# 6443 포트를 맥으로 터널링해서 kubectl 을 쓴다.

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.project}-node"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "node" {
  name = "${var.project}-node"
  role = aws_iam_role.node.name
}
