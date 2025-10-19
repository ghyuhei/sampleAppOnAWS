# ====================================
# Root Module Variables
# ====================================
#
# このファイルはルートモジュールの変数定義です
# 各環境ディレクトリ (environments/dev, staging, prod) から
# これらの変数に値を渡します

# ====================================
# 基本設定
# ====================================

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "nextjs-ecs"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

# ====================================
# Network Configuration
# ====================================

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
}

# ====================================
# ECS Configuration
# ====================================

variable "ecs_instance_type" {
  description = "EC2 instance type for ECS"
  type        = string
  default     = "t3.medium"
}

variable "ecs_min_capacity" {
  description = "Minimum number of ECS instances"
  type        = number
  default     = 0
}

variable "ecs_max_capacity" {
  description = "Maximum number of ECS instances"
  type        = number
  default     = 10
}

variable "ecs_desired_capacity" {
  description = "Desired number of ECS instances"
  type        = number
  default     = 2
}

# ====================================
# Application Configuration
# ====================================

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "nextjs-app"
}

variable "app_port" {
  description = "Application port"
  type        = number
  default     = 3000
}

variable "app_cpu" {
  description = "CPU units for application (1024 = 1 vCPU)"
  type        = number
  default     = 512
}

variable "app_memory" {
  description = "Memory for application in MB"
  type        = number
  default     = 1024
}

variable "app_desired_count" {
  description = "Desired number of application tasks"
  type        = number
  default     = 2
}

variable "app_health_path" {
  description = "Health check path"
  type        = string
  default     = "/api/health"
}

# ====================================
# Auto Scaling Configuration
# ====================================

variable "enable_auto_scaling" {
  description = "Enable auto scaling for ECS service"
  type        = bool
  default     = true
}

variable "cpu_target_value" {
  description = "Target CPU utilization percentage"
  type        = number
  default     = 70
}

variable "memory_target_value" {
  description = "Target memory utilization percentage"
  type        = number
  default     = 80
}

variable "scale_in_cooldown" {
  description = "Cooldown period in seconds for scale in"
  type        = number
  default     = 300
}

variable "scale_out_cooldown" {
  description = "Cooldown period in seconds for scale out"
  type        = number
  default     = 60
}

# ====================================
# CloudWatch Configuration
# ====================================

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days"
  type        = number
  default     = 7
}

# ====================================
# ALB Configuration
# ====================================

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
  default     = null
}

variable "alb_deregistration_delay" {
  description = "ALB target group deregistration delay in seconds"
  type        = number
  default     = 30
}

variable "alb_health_check_interval" {
  description = "ALB health check interval in seconds"
  type        = number
  default     = 30
}

variable "alb_health_check_timeout" {
  description = "ALB health check timeout in seconds"
  type        = number
  default     = 5
}

variable "alb_healthy_threshold" {
  description = "ALB healthy threshold count"
  type        = number
  default     = 2
}

variable "alb_unhealthy_threshold" {
  description = "ALB unhealthy threshold count"
  type        = number
  default     = 3
}

variable "alb_stickiness_enabled" {
  description = "Enable ALB session stickiness"
  type        = bool
  default     = true
}

variable "alb_stickiness_cookie_duration" {
  description = "ALB session stickiness cookie duration in seconds"
  type        = number
  default     = 86400
}

variable "alb_idle_timeout" {
  description = "ALB idle timeout in seconds"
  type        = number
  default     = 60
}

variable "alb_access_logs_enabled" {
  description = "Enable ALB access logs"
  type        = bool
  default     = false
}

# ====================================
# ECR Configuration
# ====================================

variable "ecr_image_tag_mutability" {
  description = "ECR image tag mutability (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.ecr_image_tag_mutability)
    error_message = "ECR image tag mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "ecr_scan_on_push" {
  description = "Enable ECR image scanning on push"
  type        = bool
  default     = true
}

variable "ecr_lifecycle_tagged_images" {
  description = "Number of tagged images to keep in ECR"
  type        = number
  default     = 10
}

variable "ecr_lifecycle_untagged_days" {
  description = "Days to keep untagged images in ECR"
  type        = number
  default     = 1
}

# ====================================
# WAF Configuration
# ====================================

variable "waf_rate_limit" {
  description = "WAF rate limit (requests per 5 minutes)"
  type        = number
  default     = 2000
}

variable "waf_enable_logging" {
  description = "Enable WAF logging"
  type        = bool
  default     = false
}

# ====================================
# CloudFront Configuration
# ====================================

variable "cloudfront_enable_waf" {
  description = "Enable WAF for CloudFront"
  type        = bool
  default     = true
}

variable "cloudfront_price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_200"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.cloudfront_price_class)
    error_message = "CloudFront price class must be PriceClass_100, PriceClass_200, or PriceClass_All."
  }
}

variable "cloudfront_enable_access_logs" {
  description = "Enable CloudFront access logs"
  type        = bool
  default     = false
}

variable "cloudfront_min_ttl" {
  description = "CloudFront minimum TTL in seconds"
  type        = number
  default     = 0
}

variable "cloudfront_default_ttl" {
  description = "CloudFront default TTL in seconds"
  type        = number
  default     = 3600
}

variable "cloudfront_max_ttl" {
  description = "CloudFront maximum TTL in seconds"
  type        = number
  default     = 86400
}

# ====================================
# Backup Configuration
# ====================================

variable "enable_backup" {
  description = "Enable automated backups"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "backup_schedule" {
  description = "Backup schedule (cron expression)"
  type        = string
  default     = "cron(0 2 * * ? *)"
}

# ====================================
# Monitoring Configuration
# ====================================

variable "enable_enhanced_monitoring" {
  description = "Enable enhanced monitoring"
  type        = bool
  default     = false
}

variable "enable_xray" {
  description = "Enable AWS X-Ray tracing"
  type        = bool
  default     = false
}

variable "enable_container_insights" {
  description = "Enable ECS Container Insights"
  type        = bool
  default     = true
}

# ====================================
# Cost Allocation
# ====================================

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "engineering"
}

variable "project_code" {
  description = "Project code for billing"
  type        = string
  default     = ""
}

variable "owner" {
  description = "Owner/team responsible for resources"
  type        = string
  default     = "platform-team"
}

# ====================================
# Feature Flags
# ====================================

variable "enable_multi_az" {
  description = "Enable multi-AZ deployment"
  type        = bool
  default     = true
}

variable "enable_nat_gateway_per_az" {
  description = "Create NAT Gateway per AZ (false = single shared NAT Gateway)"
  type        = bool
  default     = false
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = false
}

variable "enable_guardduty" {
  description = "Enable AWS GuardDuty"
  type        = bool
  default     = false
}

variable "enable_config" {
  description = "Enable AWS Config"
  type        = bool
  default     = false
}

variable "enable_secrets_manager" {
  description = "Enable AWS Secrets Manager integration"
  type        = bool
  default     = true
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for critical resources"
  type        = bool
  default     = false
}

# ====================================
# Notification Configuration
# ====================================

variable "alert_email" {
  description = "Email address for alerts"
  type        = string
  default     = ""
}

variable "enable_slack_notifications" {
  description = "Enable Slack notifications"
  type        = bool
  default     = false
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications"
  type        = string
  default     = ""
  sensitive   = true
}

# ====================================
# Cognito Configuration
# ====================================

variable "enable_cognito" {
  description = "Enable Cognito authentication"
  type        = bool
  default     = true
}

variable "cognito_callback_urls" {
  description = "Cognito callback URLs"
  type        = list(string)
  default     = ["http://localhost:3000/auth/callback"]
}

variable "cognito_logout_urls" {
  description = "Cognito logout URLs"
  type        = list(string)
  default     = ["http://localhost:3000"]
}

variable "enable_mfa" {
  description = "Enable MFA for Cognito"
  type        = bool
  default     = false
}

# ====================================
# Monitoring Configuration (Extended)
# ====================================

variable "enable_canary" {
  description = "Enable CloudWatch Synthetics Canary monitoring"
  type        = bool
  default     = false
}

# ====================================
# Common Tags
# ====================================

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
