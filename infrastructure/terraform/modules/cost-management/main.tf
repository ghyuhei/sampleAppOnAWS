# ====================================
# Cost Management Module
# ====================================

# ====================================
# AWS Budgets
# ====================================

resource "aws_budgets_budget" "monthly" {
  count = var.enable_budgets ? 1 : 0

  name              = "${var.project_name}-${var.environment}-monthly-budget"
  budget_type       = "COST"
  limit_amount      = var.monthly_budget_limit
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = formatdate("YYYY-MM-01_00:00", timestamp())

  cost_filter {
    name = "TagKeyValue"
    values = [
      "user:Environment$${var.environment}",
      "user:Project$${var.project_name}"
    ]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_emails
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_emails
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 90
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.budget_alert_emails
  }

  depends_on = [aws_sns_topic.cost_alerts]

  lifecycle {
    ignore_changes = [time_period_start]
  }
}

# ====================================
# SNS Topic for Cost Alerts
# ====================================

resource "aws_sns_topic" "cost_alerts" {
  count = var.enable_budgets ? 1 : 0

  name         = "${var.project_name}-${var.environment}-cost-alerts"
  display_name = "${var.project_name} ${var.environment} Cost Alerts"

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-cost-alerts"
    }
  )
}

resource "aws_sns_topic_subscription" "cost_email" {
  count = var.enable_budgets && length(var.budget_alert_emails) > 0 ? length(var.budget_alert_emails) : 0

  topic_arn = aws_sns_topic.cost_alerts[0].arn
  protocol  = "email"
  endpoint  = var.budget_alert_emails[count.index]
}

# ====================================
# Cost Anomaly Detection
# ====================================

resource "aws_ce_anomaly_monitor" "service" {
  count = var.enable_anomaly_detection ? 1 : 0

  name              = "${var.project_name}-${var.environment}-anomaly-monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-anomaly-monitor"
    }
  )
}

resource "aws_ce_anomaly_subscription" "service" {
  count = var.enable_anomaly_detection && length(var.budget_alert_emails) > 0 ? 1 : 0

  name      = "${var.project_name}-${var.environment}-anomaly-subscription"
  frequency = "DAILY"

  monitor_arn_list = [
    aws_ce_anomaly_monitor.service[0].arn
  ]

  subscriber {
    type    = "EMAIL"
    address = var.budget_alert_emails[0]
  }

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      values        = [tostring(var.anomaly_threshold)]
      match_options = ["GREATER_THAN_OR_EQUAL"]
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-anomaly-subscription"
    }
  )
}

# ====================================
# Cost Allocation Tags
# ====================================

# Tag Policy for Cost Allocation (requires AWS Organizations)
# resource "aws_organizations_policy" "cost_allocation_tags" {
#   count = var.enable_tag_policy ? 1 : 0
#
#   name        = "${var.project_name}-cost-allocation-tags"
#   description = "Required tags for cost allocation"
#   type        = "TAG_POLICY"
#
#   content = jsonencode({
#     tags = {
#       Environment = {
#         tag_key = {
#           @@assign = "Environment"
#         }
#         enforced_for = {
#           @@assign = [
#             "ec2:instance",
#             "rds:db",
#             "s3:bucket",
#             "ecs:cluster",
#             "ecs:service",
#             "ecs:task"
#           ]
#         }
#       }
#       Project = {
#         tag_key = {
#           @@assign = "Project"
#         }
#         enforced_for = {
#           @@assign = [
#             "ec2:instance",
#             "rds:db",
#             "s3:bucket",
#             "ecs:cluster",
#             "ecs:service",
#             "ecs:task"
#           ]
#         }
#       }
#       CostCenter = {
#         tag_key = {
#           @@assign = "CostCenter"
#         }
#         enforced_for = {
#           @@assign = [
#             "ec2:instance",
#             "rds:db",
#             "s3:bucket",
#             "ecs:cluster",
#             "ecs:service",
#             "ecs:task"
#           ]
#         }
#       }
#     }
#   })
# }

# ====================================
# Cost and Usage Report (CUR)
# ====================================

# S3 bucket for Cost and Usage Reports
resource "aws_s3_bucket" "cur" {
  count = var.enable_cur ? 1 : 0

  bucket = "${var.project_name}-${var.environment}-cost-usage-reports"

  tags = merge(
    var.common_tags,
    {
      Name    = "${var.project_name}-${var.environment}-cost-usage-reports"
      Purpose = "cost-reporting"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "cur" {
  count = var.enable_cur ? 1 : 0

  bucket = aws_s3_bucket.cur[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "cur" {
  count = var.enable_cur ? 1 : 0

  bucket = aws_s3_bucket.cur[0].id

  rule {
    id     = "delete-old-reports"
    status = "Enabled"

    expiration {
      days = 90
    }
  }
}

# ====================================
# CloudWatch Cost Metrics
# ====================================

resource "aws_cloudwatch_metric_alarm" "high_cost" {
  count = var.enable_cost_alarms ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-high-daily-cost"
  alarm_description   = "Alert when daily cost exceeds threshold"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = 86400 # 24 hours
  statistic           = "Maximum"
  threshold           = var.daily_cost_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    Currency = "USD"
  }

  alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  tags = merge(
    var.common_tags,
    {
      Name     = "${var.project_name}-${var.environment}-high-daily-cost"
      Severity = "warning"
    }
  )
}
