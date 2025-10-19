output "user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.id
}

output "user_pool_arn" {
  description = "ARN of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.arn
}

output "user_pool_endpoint" {
  description = "Endpoint of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.endpoint
}

output "user_pool_domain" {
  description = "Domain of the Cognito User Pool"
  value       = aws_cognito_user_pool_domain.main.domain
}

output "frontend_client_id" {
  description = "ID of the frontend user pool client"
  value       = aws_cognito_user_pool_client.frontend.id
}

output "backend_client_id" {
  description = "ID of the backend user pool client"
  value       = aws_cognito_user_pool_client.backend.id
}

output "backend_client_secret" {
  description = "Secret of the backend user pool client"
  value       = aws_cognito_user_pool_client.backend.client_secret
  sensitive   = true
}

output "identity_pool_id" {
  description = "ID of the Cognito Identity Pool"
  value       = aws_cognito_identity_pool.main.id
}

output "authenticated_role_arn" {
  description = "ARN of the authenticated IAM role"
  value       = aws_iam_role.authenticated.arn
}

output "admin_group_name" {
  description = "Name of the admin user group"
  value       = aws_cognito_user_group.admin.name
}

output "user_group_name" {
  description = "Name of the standard user group"
  value       = aws_cognito_user_group.user.name
}
