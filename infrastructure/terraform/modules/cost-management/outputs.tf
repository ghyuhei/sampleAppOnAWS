# ====================================
# Cost Management Module Outputs
# ====================================

output "budget_name" {
  description = "Budget name"
  value       = var.enable_budgets ? aws_budgets_budget.monthly[0].name : null
}

output "anomaly_monitor_arn" {
  description = "Cost anomaly monitor ARN"
  value       = var.enable_anomaly_detection ? aws_ce_anomaly_monitor.service[0].arn : null
}

output "cost_alerts_topic_arn" {
  description = "SNS topic ARN for cost alerts"
  value       = var.enable_budgets ? aws_sns_topic.cost_alerts[0].arn : null
}

output "cur_bucket_name" {
  description = "S3 bucket name for Cost and Usage Reports"
  value       = var.enable_cur ? aws_s3_bucket.cur[0].id : null
}
