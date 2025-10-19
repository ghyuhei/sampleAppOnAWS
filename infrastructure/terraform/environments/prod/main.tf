# ====================================
# Production Environment Configuration
# ====================================

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.16"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # バックエンド設定は backend.tf で定義
}

# ====================================
# Provider Configuration
# ====================================

provider "aws" {
  region = local.region

  default_tags {
    tags = local.common_tags
  }
}

provider "random" {}

# ====================================
# Local Variables
# ====================================

locals {
  # 基本設定
  region       = "ap-northeast-1"
  project_name = "nextjs-ecs"
  environment  = "prod"

  # ====================================
  # Network Configuration
  # ====================================

  vpc_cidr = "10.2.0.0/16" # 本番環境用CIDR
  availability_zones = [
    "ap-northeast-1a",
    "ap-northeast-1c",
    "ap-northeast-1d"
  ]

  # ====================================
  # ECS Configuration
  # ====================================

  ecs_instance_type = "t3.large" # 本番環境では大きめのインスタンス

  # ====================================
  # Application Configuration
  # ====================================

  app_name          = "nextjs-app"
  app_port          = 3000
  app_cpu           = 1024 # 本番環境では多めに
  app_memory        = 2048 # 本番環境では多めに
  app_desired_count = 3    # 本番環境では冗長性を確保
  app_health_path   = "/api/health"

  # ====================================
  # CloudWatch Configuration
  # ====================================

  log_retention_days = 30 # 本番環境では長めに保持

  # ====================================
  # ALB Configuration
  # ====================================

  alb_deregistration_delay       = 30
  alb_health_check_interval      = 30
  alb_health_check_timeout       = 5
  alb_healthy_threshold          = 2
  alb_unhealthy_threshold        = 3
  alb_stickiness_enabled         = true
  alb_stickiness_cookie_duration = 86400

  # ====================================
  # ECR Configuration
  # ====================================

  ecr_image_tag_mutability    = "IMMUTABLE" # 本番環境では不変
  ecr_scan_on_push            = true
  ecr_lifecycle_tagged_images = 30 # 本番環境では多めに保持
  ecr_lifecycle_untagged_days = 1

  # ====================================
  # WAF Configuration
  # ====================================

  waf_rate_limit = 2000 # リクエスト数/5分

  # ====================================
  # CloudFront Configuration
  # ====================================

  cloudfront_enable_waf  = true
  cloudfront_price_class = "PriceClass_All" # 本番環境では全リージョン

  # ====================================
  # Cognito Configuration
  # ====================================

  enable_cognito = true
  cognito_callback_urls = [
    "https://${local.project_name}.example.com/auth/callback"
  ]
  cognito_logout_urls = [
    "https://${local.project_name}.example.com"
  ]

  # ====================================
  # Monitoring Configuration
  # ====================================

  enable_xray   = true
  enable_canary = true # 本番環境では有効化

  # ====================================
  # Tags
  # ====================================

  common_tags = {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "Terraform"
    Team        = "Platform"
    CostCenter  = "production"
  }
}

# ====================================
# Root Module
# ====================================

module "app_infrastructure" {
  source = "../../"

  # 基本設定
  project_name = local.project_name
  environment  = local.environment
  region       = local.region

  # Network
  vpc_cidr           = local.vpc_cidr
  availability_zones = local.availability_zones

  # ECS
  ecs_instance_type = local.ecs_instance_type

  # Application
  app_name          = local.app_name
  app_port          = local.app_port
  app_cpu           = local.app_cpu
  app_memory        = local.app_memory
  app_desired_count = local.app_desired_count
  app_health_path   = local.app_health_path

  # CloudWatch
  log_retention_days = local.log_retention_days

  # ALB
  certificate_arn                = var.certificate_arn # 本番環境では必須
  alb_deregistration_delay       = local.alb_deregistration_delay
  alb_health_check_interval      = local.alb_health_check_interval
  alb_health_check_timeout       = local.alb_health_check_timeout
  alb_healthy_threshold          = local.alb_healthy_threshold
  alb_unhealthy_threshold        = local.alb_unhealthy_threshold
  alb_stickiness_enabled         = local.alb_stickiness_enabled
  alb_stickiness_cookie_duration = local.alb_stickiness_cookie_duration

  # ECR
  ecr_image_tag_mutability    = local.ecr_image_tag_mutability
  ecr_scan_on_push            = local.ecr_scan_on_push
  ecr_lifecycle_tagged_images = local.ecr_lifecycle_tagged_images
  ecr_lifecycle_untagged_days = local.ecr_lifecycle_untagged_days

  # WAF
  waf_rate_limit = local.waf_rate_limit

  # CloudFront
  cloudfront_enable_waf  = local.cloudfront_enable_waf
  cloudfront_price_class = local.cloudfront_price_class

  # Cognito
  enable_cognito        = local.enable_cognito
  enable_mfa            = true # 本番環境ではMFA必須
  cognito_callback_urls = local.cognito_callback_urls
  cognito_logout_urls   = local.cognito_logout_urls

  # Monitoring
  alert_email   = var.alert_email # 本番環境では必須
  enable_xray   = local.enable_xray
  enable_canary = local.enable_canary

  # Security
  enable_deletion_protection = true # 本番環境では削除保護を有効化

  # Tags
  tags = local.common_tags
}
