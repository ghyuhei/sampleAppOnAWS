# ====================================
# Development Environment Outputs
# ====================================

output "vpc_id" {
  description = "VPC ID"
  value       = module.app_infrastructure.vpc_id
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.app_infrastructure.alb_dns_name
}

output "alb_url" {
  description = "ALB URL"
  value       = module.app_infrastructure.alb_url
}

output "application_url" {
  description = "Application URL (CloudFront)"
  value       = module.app_infrastructure.application_url
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name"
  value       = module.app_infrastructure.cloudfront_domain_name
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = module.app_infrastructure.ecr_repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.app_infrastructure.ecs_cluster_name
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = module.app_infrastructure.cognito_user_pool_id
}

output "cognito_frontend_client_id" {
  description = "Cognito Frontend Client ID"
  value       = module.app_infrastructure.cognito_frontend_client_id
}

output "ssm_parameter_prefix" {
  description = "SSM Parameter Store prefix"
  value       = module.app_infrastructure.ssm_parameter_prefix
}

output "deployment_commands" {
  description = "Deployment commands"
  value       = module.app_infrastructure.deployment_commands
}
