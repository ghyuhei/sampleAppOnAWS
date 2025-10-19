output "kms_key_id" {
  description = "KMS key ID for SSM parameter encryption"
  value       = aws_kms_key.ssm.key_id
}

output "kms_key_arn" {
  description = "KMS key ARN for SSM parameter encryption"
  value       = aws_kms_key.ssm.arn
}

output "ssm_read_policy_arn" {
  description = "IAM policy ARN for reading SSM parameters"
  value       = aws_iam_policy.ssm_read.arn
}

output "parameter_prefix" {
  description = "SSM parameter prefix path"
  value       = "/${var.project_name}/${var.environment}"
}
