# 예산 알람. cluster 보다 "먼저" apply 하고, 매일 destroy 대상에서는 뺀다.
# 주의: Budgets 는 실시간이 아니다. 비용 데이터가 하루 몇 번만 갱신되므로
# 당일 사고를 막는 건 이 알람이 아니라 런북 마지막의 destroy + check-leftovers.sh 다.
resource "aws_budgets_budget" "monthly" {
  name         = var.budget_name
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # 실제 쓴 돈이 50% 를 넘으면
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  # 실제 쓴 돈이 80% 를 넘으면
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  # 이 속도면 월말에 100% 를 넘을 것 같으면 (예측)
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}
