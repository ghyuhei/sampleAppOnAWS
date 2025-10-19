# ====================================
# Secrets Manager Module Outputs
# ====================================

output "database_credentials_arn" {
  description = "Database credentials secret ARN"
  value       = var.enable_secrets_manager ? aws_secretsmanager_secret.database_credentials[0].arn : null
}

output "api_keys_arn" {
  description = "API keys secret ARN"
  value       = var.enable_secrets_manager ? aws_secretsmanager_secret.api_keys[0].arn : null
}

output "app_env_arn" {
  description = "Application environment variables secret ARN"
  value       = var.enable_secrets_manager ? aws_secretsmanager_secret.app_env[0].arn : null
}

output "kms_key_id" {
  description = "KMS key ID for secrets encryption"
  value       = var.enable_secrets_manager ? aws_kms_key.secrets[0].id : null
}

output "secrets_access_policy_arn" {
  description = "IAM policy ARN for accessing secrets"
  value       = var.enable_secrets_manager ? aws_iam_policy.secrets_access[0].arn : null
}
