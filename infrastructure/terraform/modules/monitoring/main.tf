# ====================================
# Monitoring and Alerting Module
# ====================================

# ====================================
# SNS Topic for Alerts
# ====================================

resource "aws_sns_topic" "alerts" {
  name              = "${var.project_name}-${var.environment}-alerts"
  display_name      = "${var.project_name} ${var.environment} Alerts"
  kms_master_key_id = aws_kms_key.sns[0].id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-alerts"
    }
  )
}

resource "aws_sns_topic_subscription" "email" {
  count = var.alert_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ====================================
# KMS Key for SNS Encryption
# ====================================

resource "aws_kms_key" "sns" {
  count = 1

  description             = "KMS key for SNS topic encryption"
  deletion_window_in_days = var.environment == "prod" ? 30 : 7
  enable_key_rotation     = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-sns-kms"
    }
  )
}

resource "aws_kms_alias" "sns" {
  count = 1

  name          = "alias/${var.project_name}-${var.environment}-sns"
  target_key_id = aws_kms_key.sns[0].key_id
}

# ====================================
# CloudWatch Alarms - ECS Service
# ====================================

# CPU使用率アラーム
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${var.project_name}-${var.environment}-ecs-cpu-high"
  alarm_description   = "ECS service CPU utilization is high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.environment == "prod" ? 80 : 90
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = merge(
    var.common_tags,
    {
      Name     = "${var.project_name}-${var.environment}-ecs-cpu-high"
      Severity = "warning"
    }
  )
}

# メモリ使用率アラーム
resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name          = "${var.project_name}-${var.environment}-ecs-memory-high"
  alarm_description   = "ECS service memory utilization is high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.environment == "prod" ? 80 : 90
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = merge(
    var.common_tags,
    {
      Name     = "${var.project_name}-${var.environment}-ecs-memory-high"
      Severity = "warning"
    }
  )
}

# Running Task数アラーム
resource "aws_cloudwatch_metric_alarm" "ecs_task_count_low" {
  alarm_name          = "${var.project_name}-${var.environment}-ecs-task-count-low"
  alarm_description   = "ECS service has too few running tasks"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = var.environment == "prod" ? 2 : 1
  treat_missing_data  = "breaching"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = merge(
    var.common_tags,
    {
      Name     = "${var.project_name}-${var.environment}-ecs-task-count-low"
      Severity = "critical"
    }
  )
}

# ====================================
# CloudWatch Alarms - ALB
# ====================================

# ターゲットヘルスチェック失敗アラーム
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-unhealthy-targets"
  alarm_description   = "ALB has unhealthy targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = merge(
    var.common_tags,
    {
      Name     = "${var.project_name}-${var.environment}-alb-unhealthy-targets"
      Severity = "critical"
    }
  )
}

# 5xxエラーアラーム
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-5xx-errors"
  alarm_description   = "ALB is returning 5xx errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.environment == "prod" ? 10 : 50
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = merge(
    var.common_tags,
    {
      Name     = "${var.project_name}-${var.environment}-alb-5xx-errors"
      Severity = "high"
    }
  )
}

# レスポンスタイムアラーム
resource "aws_cloudwatch_metric_alarm" "alb_response_time" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-response-time-high"
  alarm_description   = "ALB response time is high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = var.environment == "prod" ? 1.0 : 2.0
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = merge(
    var.common_tags,
    {
      Name     = "${var.project_name}-${var.environment}-alb-response-time-high"
      Severity = "warning"
    }
  )
}

# ====================================
# CloudWatch Dashboard
# ====================================

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", { stat = "Average", label = "CPU %" }],
            [".", "MemoryUtilization", { stat = "Average", label = "Memory %" }]
          ]
          period = 300
          region = var.region
          title  = "ECS Service - CPU & Memory"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["ECS/ContainerInsights", "RunningTaskCount", { stat = "Average" }],
            [".", "DesiredTaskCount", { stat = "Average" }]
          ]
          period = 60
          region = var.region
          title  = "ECS Service - Task Count"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", { stat = "Average" }],
            [".", "RequestCount", { stat = "Sum", yAxis = "right" }]
          ]
          period = 300
          region = var.region
          title  = "ALB - Response Time & Requests"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", { stat = "Sum", label = "2xx" }],
            [".", "HTTPCode_Target_4XX_Count", { stat = "Sum", label = "4xx" }],
            [".", "HTTPCode_Target_5XX_Count", { stat = "Sum", label = "5xx" }]
          ]
          period = 300
          region = var.region
          title  = "ALB - HTTP Status Codes"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", { stat = "Average" }],
            [".", "UnHealthyHostCount", { stat = "Average" }]
          ]
          period = 60
          region = var.region
          title  = "ALB - Target Health"
        }
      }
    ]
  })
}

# ====================================
# CloudWatch Log Insights Queries
# ====================================

resource "aws_cloudwatch_query_definition" "error_logs" {
  name = "${var.project_name}-${var.environment}-error-logs"

  log_group_names = [
    var.log_group_name
  ]

  query_string = <<-QUERY
    fields @timestamp, @message
    | filter @message like /ERROR/
    | sort @timestamp desc
    | limit 100
  QUERY
}

resource "aws_cloudwatch_query_definition" "slow_requests" {
  name = "${var.project_name}-${var.environment}-slow-requests"

  log_group_names = [
    var.log_group_name
  ]

  query_string = <<-QUERY
    fields @timestamp, @message
    | filter @message like /duration/
    | parse @message /duration: (?<duration>\d+)/
    | filter duration > 1000
    | sort duration desc
    | limit 100
  QUERY
}

# ====================================
# CloudWatch Alarms - RDS (Optional)
# ====================================

resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  count = var.rds_instance_id != "" ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-rds-cpu-high"
  alarm_description   = "RDS CPU utilization is high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.environment == "prod" ? 80 : 90
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = merge(
    var.common_tags,
    {
      Name     = "${var.project_name}-${var.environment}-rds-cpu-high"
      Severity = "warning"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "rds_storage_low" {
  count = var.rds_instance_id != "" ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-rds-storage-low"
  alarm_description   = "RDS free storage space is low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 10737418240 # 10GB in bytes
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = merge(
    var.common_tags,
    {
      Name     = "${var.project_name}-${var.environment}-rds-storage-low"
      Severity = "critical"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "rds_connection_count_high" {
  count = var.rds_instance_id != "" ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-rds-connection-count-high"
  alarm_description   = "RDS database connection count is high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.environment == "prod" ? 80 : 50
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = var.rds_instance_id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = merge(
    var.common_tags,
    {
      Name     = "${var.project_name}-${var.environment}-rds-connection-count-high"
      Severity = "warning"
    }
  )
}

# ====================================
# CloudWatch Composite Alarms
# ====================================

resource "aws_cloudwatch_composite_alarm" "service_health" {
  alarm_name        = "${var.project_name}-${var.environment}-service-health-critical"
  alarm_description = "Multiple critical metrics are breaching thresholds"
  actions_enabled   = true
  alarm_actions     = [aws_sns_topic.alerts.arn]
  ok_actions        = [aws_sns_topic.alerts.arn]

  alarm_rule = "ALARM(${aws_cloudwatch_metric_alarm.ecs_task_count_low.alarm_name}) OR ALARM(${aws_cloudwatch_metric_alarm.alb_unhealthy_targets.alarm_name})"

  tags = merge(
    var.common_tags,
    {
      Name     = "${var.project_name}-${var.environment}-service-health-critical"
      Severity = "critical"
    }
  )
}

# ====================================
# CloudWatch Synthetics Canary (Optional)
# ====================================

resource "aws_cloudwatch_log_group" "canary" {
  count = var.enable_canary ? 1 : 0

  name              = "/aws/lambda/cwsyn-${var.project_name}-${var.environment}-canary"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-canary-logs"
    }
  )
}

resource "aws_iam_role" "canary" {
  count = var.enable_canary ? 1 : 0

  name = "${var.project_name}-${var.environment}-canary-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-canary-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "canary_basic" {
  count = var.enable_canary ? 1 : 0

  role       = aws_iam_role.canary[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "canary" {
  count = var.enable_canary ? 1 : 0

  name = "${var.project_name}-${var.environment}-canary-policy"
  role = aws_iam_role.canary[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-${var.environment}-canary-results/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "CloudWatchSynthetics"
          }
        }
      }
    ]
  })
}

# ====================================
# X-Ray Tracing
# ====================================

resource "aws_iam_role_policy" "ecs_task_xray" {
  count = var.enable_xray ? 1 : 0

  name = "${var.project_name}-${var.environment}-ecs-task-xray"
  role = var.ecs_task_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets",
          "xray:GetSamplingStatisticSummaries"
        ]
        Resource = "*"
      }
    ]
  })
}

# ====================================
# CloudWatch Log Metric Filters
# ====================================

resource "aws_cloudwatch_log_metric_filter" "error_count" {
  name           = "${var.project_name}-${var.environment}-error-count"
  log_group_name = var.log_group_name
  pattern        = "[time, request_id, level = ERROR*, ...]"

  metric_transformation {
    name      = "ErrorCount"
    namespace = "${var.project_name}/${var.environment}"
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "error_count_high" {
  alarm_name          = "${var.project_name}-${var.environment}-error-count-high"
  alarm_description   = "High number of application errors detected"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ErrorCount"
  namespace           = "${var.project_name}/${var.environment}"
  period              = 300
  statistic           = "Sum"
  threshold           = var.environment == "prod" ? 10 : 50
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = merge(
    var.common_tags,
    {
      Name     = "${var.project_name}-${var.environment}-error-count-high"
      Severity = "high"
    }
  )
}
