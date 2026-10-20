# 노드 풀 하나 = 시작 템플릿(Launch Template) 1개 + Auto Scaling Group(ASG) 1개.
#
# 왜 aws_instance 가 아니라 ASG 인가
#   스팟은 AWS 가 2분 경고 후 회수해 간다. aws_instance 로 만들면 회수된 자리가 그냥 빈다.
#   ASG 는 "항상 desired 대 유지"가 일이라, 회수되면 새 스팟을 다시 받아 오고
#   새 노드는 user_data 로 k3s agent 를 깔고 클러스터에 스스로 다시 붙는다.

locals {
  is_spot = var.capacity_type == "spot"
  tags = {
    Project      = var.project
    Pool         = var.name
    CapacityType = var.capacity_type
  }
}

resource "aws_launch_template" "this" {
  name_prefix   = "${var.project}-${var.name}-"
  image_id      = var.ami_id
  instance_type = var.instance_types[0]
  user_data     = base64encode(var.user_data)

  iam_instance_profile {
    name = var.instance_profile_name
  }

  vpc_security_group_ids = var.security_group_ids

  # IMDSv2 강제. hop limit 2 = 파드(컨테이너 안)에서도 메타데이터에 닿을 수 있게.
  # aws-node-termination-handler 가 스팟 회수 경고를 메타데이터에서 읽는다.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  credit_specification {
    cpu_credits = var.cpu_credits
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = var.root_volume_gb
      volume_type           = "gp3"
      delete_on_termination = true # 노드가 죽으면 디스크도 같이 지운다 (남으면 돈 나감)
      encrypted             = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.tags, { Name = "${var.project}-${var.name}" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = local.tags
  }

  # 스팟 요청에도 태그 (비용 추적용)
  dynamic "tag_specifications" {
    for_each = local.is_spot ? [1] : []
    content {
      resource_type = "spot-instances-request"
      tags          = local.tags
    }
  }

  tags = local.tags
}

resource "aws_autoscaling_group" "this" {
  name                = "${var.project}-${var.name}"
  vpc_zone_identifier = var.subnet_ids
  min_size            = 0
  max_size            = var.max
  desired_capacity    = var.desired

  # 새 노드가 k3s 에 붙기까지 기다리지 않는다 (ASG 는 k3s 를 모름). Ready 판단은 kubectl 로.
  wait_for_capacity_timeout = "0"

  # 스팟이든 온디맨드든 같은 문법(mixed instances)으로 쓴다. 비율만 다르다.
  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = local.is_spot ? 0 : 100
      # 가격과 "회수될 가능성"을 같이 보고 고르는 AWS 권장 전략
      spot_allocation_strategy = "price-capacity-optimized"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.this.id
        version            = "$Latest"
      }

      dynamic "override" {
        for_each = var.instance_types
        content {
          instance_type = override.value
        }
      }
    }
  }

  # 스팟 회수 "경고"가 오기 전에 "회수 위험이 높아졌다" 신호가 오면 미리 교체 노드를 띄운다
  capacity_rebalance = local.is_spot

  dynamic "tag" {
    for_each = merge(local.tags, { Name = "${var.project}-${var.name}" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# 안전망: 지정 시각에 0대로. (시스템 노드는 ASG 가 아니라서 이걸로 못 끈다 → 런북의 destroy 가 본체)
resource "aws_autoscaling_schedule" "scale_down" {
  count                  = var.scale_down_recurrence == "" ? 0 : 1
  scheduled_action_name  = "${var.project}-${var.name}-nightly-zero"
  autoscaling_group_name = aws_autoscaling_group.this.name
  recurrence             = var.scale_down_recurrence
  time_zone              = "Asia/Seoul"
  min_size               = 0
  max_size               = var.max
  desired_capacity       = 0
}
