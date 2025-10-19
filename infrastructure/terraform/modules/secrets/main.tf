# ====================================
# AWS Secrets Manager Module
# ====================================
# アプリケーションの機密情報を安全に管理

# ====================================
# Secrets Manager Secrets
# ====================================

# データベース認証情報
resource "aws_secretsmanager_secret" "database_credentials" {
  count = var.enable_secrets_manager ? 1 : 0

  name_prefix             = "${var.project_name}-${var.environment}-db-credentials-"
  description             = "Database credentials for ${var.environment} environment"
  recovery_window_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-db-credentials"
      SecretType  = "database"
      Environment = var.environment
    }
  )
}

# API Keys
resource "aws_secretsmanager_secret" "api_keys" {
  count = var.enable_secrets_manager ? 1 : 0

  name_prefix             = "${var.project_name}-${var.environment}-api-keys-"
  description             = "External API keys for ${var.environment} environment"
  recovery_window_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-api-keys"
      SecretType  = "api-keys"
      Environment = var.environment
    }
  )
}

# アプリケーション環境変数
resource "aws_secretsmanager_secret" "app_env" {
  count = var.enable_secrets_manager ? 1 : 0

  name_prefix             = "${var.project_name}-${var.environment}-app-env-"
  description             = "Application environment variables for ${var.environment} environment"
  recovery_window_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-app-env"
      SecretType  = "environment"
      Environment = var.environment
    }
  )
}

# ====================================
# Secret Rotation (Optional)
# ====================================

# Lambda関数でシークレットローテーションを実装する場合
# resource "aws_secretsmanager_secret_rotation" "database_credentials" {
#   count = var.enable_secret_rotation && var.enable_secrets_manager ? 1 : 0
#
#   secret_id           = aws_secretsmanager_secret.database_credentials[0].id
#   rotation_lambda_arn = var.rotation_lambda_arn
#
#   rotation_rules {
#     automatically_after_days = var.rotation_days
#   }
# }

# ====================================
# KMS Key for Secrets Encryption
# ====================================

resource "aws_kms_key" "secrets" {
  count = var.enable_secrets_manager ? 1 : 0

  description             = "KMS key for Secrets Manager encryption (${var.environment})"
  deletion_window_in_days = var.environment == "prod" ? 30 : 7
  enable_key_rotation     = true

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-secrets-kms"
      Purpose     = "secrets-encryption"
      Environment = var.environment
    }
  )
}

resource "aws_kms_alias" "secrets" {
  count = var.enable_secrets_manager ? 1 : 0

  name          = "alias/${var.project_name}-${var.environment}-secrets"
  target_key_id = aws_kms_key.secrets[0].key_id
}

# ====================================
# IAM Policy for ECS Task to Access Secrets
# ====================================

data "aws_iam_policy_document" "secrets_access" {
  count = var.enable_secrets_manager ? 1 : 0

  statement {
    sid    = "GetSecretValue"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]

    resources = [
      aws_secretsmanager_secret.database_credentials[0].arn,
      aws_secretsmanager_secret.api_keys[0].arn,
      aws_secretsmanager_secret.app_env[0].arn
    ]
  }

  statement {
    sid    = "DecryptSecrets"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey"
    ]

    resources = [
      aws_kms_key.secrets[0].arn
    ]
  }
}

resource "aws_iam_policy" "secrets_access" {
  count = var.enable_secrets_manager ? 1 : 0

  name_prefix = "${var.project_name}-${var.environment}-secrets-access-"
  description = "Policy to allow ECS tasks to access secrets"
  policy      = data.aws_iam_policy_document.secrets_access[0].json

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-secrets-access-policy"
      Environment = var.environment
    }
  )
}

# ====================================
# CloudWatch Alarms for Secret Access
# ====================================

resource "aws_cloudwatch_log_metric_filter" "unauthorized_secret_access" {
  count = var.enable_secrets_manager && var.enable_monitoring ? 1 : 0

  name           = "${var.project_name}-${var.environment}-unauthorized-secret-access"
  log_group_name = "/aws/secretsmanager/${var.project_name}"
  pattern        = "[...] AccessDenied"

  metric_transformation {
    name      = "UnauthorizedSecretAccess"
    namespace = "${var.project_name}/${var.environment}/Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "unauthorized_secret_access" {
  count = var.enable_secrets_manager && var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-unauthorized-secret-access"
  alarm_description   = "Alert on unauthorized secret access attempts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnauthorizedSecretAccess"
  namespace           = "${var.project_name}/${var.environment}/Security"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  alarm_actions = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  tags = merge(
    var.common_tags,
    {
      Name        = "${var.project_name}-${var.environment}-unauthorized-secret-access-alarm"
      Environment = var.environment
      Severity    = "high"
    }
  )
}
