# ====================================
# Network Outputs
# ====================================

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

# ====================================
# ECS Outputs
# ====================================

output "ecs_cluster_id" {
  description = "ECS cluster ID"
  value       = module.ecs.cluster_id
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = module.ecs.cluster_arn
}

output "capacity_provider_name" {
  description = "ECS capacity provider name"
  value       = module.ecs.capacity_provider_name
}

output "task_execution_role_arn" {
  description = "ECS task execution role ARN"
  value       = module.ecs.task_execution_role_arn
}

output "task_role_arn" {
  description = "ECS task role ARN"
  value       = module.ecs.task_role_arn
}

output "ecs_instance_security_group_id" {
  description = "Security group ID for ECS instances"
  value       = module.ecs.ecs_instance_security_group_id
}

# ====================================
# ALB Outputs
# ====================================

output "alb_id" {
  description = "ALB ID"
  value       = module.alb.alb_id
}

output "alb_arn" {
  description = "ALB ARN"
  value       = module.alb.alb_arn
}

output "alb_dns_name" {
  description = "ALB DNS name - Access your application at http://<this-value>"
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "ALB zone ID for Route53 alias records"
  value       = module.alb.alb_zone_id
}

output "alb_security_group_id" {
  description = "Security group ID for ALB"
  value       = module.alb.alb_security_group_id
}

# ====================================
# Application Outputs
# ====================================

output "project_name" {
  description = "Project name"
  value       = var.project_name
}

output "app_name" {
  description = "Application name"
  value       = var.app_name
}

output "app_port" {
  description = "Application port"
  value       = var.app_port
}

output "app_cpu" {
  description = "Application CPU units"
  value       = var.app_cpu
}

output "app_memory" {
  description = "Application memory (MiB)"
  value       = var.app_memory
}

output "app_desired_count" {
  description = "Application desired count"
  value       = var.app_desired_count
}

output "app_health_path" {
  description = "Application health check path"
  value       = var.app_health_path
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "ecr_repository_url" {
  description = "ECR repository URL for application images"
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_arn" {
  description = "ECR repository ARN"
  value       = aws_ecr_repository.app.arn
}

output "target_group_arn" {
  description = "ALB target group ARN"
  value       = aws_lb_target_group.app.arn
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for application logs"
  value       = aws_cloudwatch_log_group.app.name
}

# ====================================
# Deployment Information
# ====================================

output "application_url" {
  description = "Application URL (via CloudFront CDN)"
  value       = "https://${module.cloudfront.domain_name}"
}

output "alb_url" {
  description = "Direct ALB URL (for testing/debugging)"
  value       = "http://${module.alb.alb_dns_name}"
}

output "deployment_commands" {
  description = "Commands to build and deploy the application with ecspresso"
  value = {
    init_service = "./init-service.sh"
    deploy       = "./deploy.sh"
    status       = "cd ecspresso && ecspresso status --config config.yaml"
    logs         = "aws logs tail /ecs/${var.project_name}/${var.app_name} --follow"
  }
}

# ====================================
# CloudFront & CDN Outputs
# ====================================

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.cloudfront.distribution_id
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = module.cloudfront.distribution_arn
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = module.cloudfront.domain_name
}

output "static_assets_bucket_name" {
  description = "S3 bucket name for static assets"
  value       = module.s3.bucket_name
}

output "static_assets_bucket_arn" {
  description = "S3 bucket ARN for static assets"
  value       = module.s3.bucket_arn
}

output "waf_web_acl_id" {
  description = "WAF Web ACL ID"
  value       = module.waf.web_acl_id
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = module.waf.web_acl_arn
}

# ====================================
# Cognito Outputs
# ====================================

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = var.enable_cognito ? module.cognito[0].user_pool_id : null
}

output "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN"
  value       = var.enable_cognito ? module.cognito[0].user_pool_arn : null
}

output "cognito_frontend_client_id" {
  description = "Cognito Frontend Client ID"
  value       = var.enable_cognito ? module.cognito[0].frontend_client_id : null
}

output "cognito_backend_client_id" {
  description = "Cognito Backend Client ID"
  value       = var.enable_cognito ? module.cognito[0].backend_client_id : null
}

output "cognito_user_pool_domain" {
  description = "Cognito User Pool Domain"
  value       = var.enable_cognito ? module.cognito[0].user_pool_domain : null
}

output "cognito_identity_pool_id" {
  description = "Cognito Identity Pool ID"
  value       = var.enable_cognito ? module.cognito[0].identity_pool_id : null
}

# ====================================
# SSM Parameter Store Outputs
# ====================================

output "ssm_parameter_prefix" {
  description = "SSM Parameter Store prefix for application configuration"
  value       = module.ssm.parameter_prefix
}

output "ssm_kms_key_id" {
  description = "KMS Key ID for SSM Parameter Store encryption"
  value       = module.ssm.kms_key_id
}
