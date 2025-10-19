# ====================================
# SSM Parameter Store Module
# ====================================

# ====================================
# KMS Key for Parameter Store Encryption
# ====================================

resource "aws_kms_key" "ssm" {
  description             = "KMS key for SSM Parameter Store encryption"
  deletion_window_in_days = var.environment == "prod" ? 30 : 7
  enable_key_rotation     = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-ssm-kms"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "ssm" {
  name          = "alias/${var.project_name}-${var.environment}-ssm"
  target_key_id = aws_kms_key.ssm.key_id
}

# ====================================
# Application Configuration Parameters
# ====================================

resource "aws_ssm_parameter" "app_env" {
  name        = "/${var.project_name}/${var.environment}/app/env"
  description = "Application environment"
  type        = "String"
  value       = var.environment
  tier        = "Standard"

  tags = {
    Name        = "${var.project_name}-${var.environment}-app-env"
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "app_log_level" {
  name        = "/${var.project_name}/${var.environment}/app/log_level"
  description = "Application log level"
  type        = "String"
  value       = var.log_level
  tier        = "Standard"

  tags = {
    Name        = "${var.project_name}-${var.environment}-app-log-level"
    Environment = var.environment
  }
}

# ====================================
# Cognito Configuration Parameters
# ====================================

resource "aws_ssm_parameter" "cognito_user_pool_id" {
  count = var.cognito_user_pool_id != "" ? 1 : 0

  name        = "/${var.project_name}/${var.environment}/cognito/user_pool_id"
  description = "Cognito User Pool ID"
  type        = "String"
  value       = var.cognito_user_pool_id
  tier        = "Standard"

  tags = {
    Name        = "${var.project_name}-${var.environment}-cognito-user-pool-id"
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "cognito_client_id" {
  count = var.cognito_client_id != "" ? 1 : 0

  name        = "/${var.project_name}/${var.environment}/cognito/client_id"
  description = "Cognito App Client ID"
  type        = "String"
  value       = var.cognito_client_id
  tier        = "Standard"

  tags = {
    Name        = "${var.project_name}-${var.environment}-cognito-client-id"
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "cognito_client_secret" {
  count = var.cognito_client_secret != "" ? 1 : 0

  name        = "/${var.project_name}/${var.environment}/cognito/client_secret"
  description = "Cognito App Client Secret"
  type        = "SecureString"
  value       = var.cognito_client_secret
  key_id      = aws_kms_key.ssm.key_id
  tier        = "Standard"

  tags = {
    Name        = "${var.project_name}-${var.environment}-cognito-client-secret"
    Environment = var.environment
  }
}

# ====================================
# Database Configuration Parameters
# ====================================

resource "aws_ssm_parameter" "db_host" {
  count = var.db_host != "" ? 1 : 0

  name        = "/${var.project_name}/${var.environment}/database/host"
  description = "Database host"
  type        = "String"
  value       = var.db_host
  tier        = "Standard"

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-host"
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "db_port" {
  count = var.db_port != "" ? 1 : 0

  name        = "/${var.project_name}/${var.environment}/database/port"
  description = "Database port"
  type        = "String"
  value       = var.db_port
  tier        = "Standard"

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-port"
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "db_name" {
  count = var.db_name != "" ? 1 : 0

  name        = "/${var.project_name}/${var.environment}/database/name"
  description = "Database name"
  type        = "String"
  value       = var.db_name
  tier        = "Standard"

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-name"
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "db_username" {
  count = var.db_username != "" ? 1 : 0

  name        = "/${var.project_name}/${var.environment}/database/username"
  description = "Database username"
  type        = "SecureString"
  value       = var.db_username
  key_id      = aws_kms_key.ssm.key_id
  tier        = "Standard"

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-username"
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "db_password" {
  count = var.db_password != "" ? 1 : 0

  name        = "/${var.project_name}/${var.environment}/database/password"
  description = "Database password"
  type        = "SecureString"
  value       = var.db_password
  key_id      = aws_kms_key.ssm.key_id
  tier        = "Standard"

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-password"
    Environment = var.environment
  }

  lifecycle {
    ignore_changes = [value]
  }
}

# ====================================
# API Configuration Parameters
# ====================================

resource "aws_ssm_parameter" "api_key" {
  count = var.api_key != "" ? 1 : 0

  name        = "/${var.project_name}/${var.environment}/api/key"
  description = "API key for external services"
  type        = "SecureString"
  value       = var.api_key
  key_id      = aws_kms_key.ssm.key_id
  tier        = "Standard"

  tags = {
    Name        = "${var.project_name}-${var.environment}-api-key"
    Environment = var.environment
  }

  lifecycle {
    ignore_changes = [value]
  }
}

# ====================================
# IAM Policy for ECS Task to Read Parameters
# ====================================

data "aws_iam_policy_document" "ssm_read" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = [
      "arn:aws:ssm:${var.region}:${var.aws_account_id}:parameter/${var.project_name}/${var.environment}/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt"
    ]
    resources = [
      aws_kms_key.ssm.arn
    ]
  }
}

resource "aws_iam_policy" "ssm_read" {
  name        = "${var.project_name}-${var.environment}-ssm-read"
  description = "Allow ECS tasks to read SSM parameters"
  policy      = data.aws_iam_policy_document.ssm_read.json

  tags = {
    Name        = "${var.project_name}-${var.environment}-ssm-read"
    Environment = var.environment
  }
}
