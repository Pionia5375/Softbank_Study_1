# 스팟 회수 연습. AWS Fault Injection Service(FIS) 가 실행 노드 1대에 "2분 뒤 회수" 경고를 진짜로 보낸다.
# 템플릿을 만드는 건 무료, scripts/measure.sh spot 으로 실행할 때만 과금된다.
# 문서: https://docs.aws.amazon.com/fis/latest/userguide/fis-actions-reference.html#send-spot-instance-interruptions

data "aws_iam_policy_document" "fis_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["fis.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "fis" {
  count              = var.enable_fis ? 1 : 0
  name               = "${var.project}-fis"
  assume_role_policy = data.aws_iam_policy_document.fis_assume.json
}

resource "aws_iam_role_policy_attachment" "fis_ec2" {
  count      = var.enable_fis ? 1 : 0
  role       = aws_iam_role.fis[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSFaultInjectionSimulatorEC2Access"
}

resource "aws_fis_experiment_template" "spot_interrupt" {
  count       = var.enable_fis ? 1 : 0
  description = "${var.project}: exec pool spot 1대에 2분 회수 경고"
  role_arn    = aws_iam_role.fis[0].arn

  action {
    name      = "interrupt-one-exec-node"
    action_id = "aws:ec2:send-spot-instance-interruptions"

    parameter {
      key   = "durationBeforeInterruption"
      value = "PT2M"
    }

    target {
      key   = "SpotInstances"
      value = "exec-spot"
    }
  }

  target {
    name           = "exec-spot"
    resource_type  = "aws:ec2:spot-instance"
    selection_mode = "COUNT(1)"

    resource_tag {
      key   = "Pool"
      value = "exec"
    }

    resource_tag {
      key   = "Project"
      value = var.project
    }

    filter {
      path   = "State.Name"
      values = ["running"]
    }
  }

  stop_condition {
    source = "none"
  }

  tags = { Name = "${var.project}-spot-interrupt" }
}
