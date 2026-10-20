output "budget_name" {
  value = aws_budgets_budget.monthly.name
}

output "monthly_limit_usd" {
  value = var.monthly_limit_usd
}
