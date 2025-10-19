# ====================================
# Staging Environment
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
}

# ====================================
# Provider Configuration
# ====================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "staging"
      Project     = var.project_name
      ManagedBy   = "Terraform"
      CostCenter  = "engineering"
    }
  }
}

# ====================================
# Local Variables
# ====================================

locals {
  environment  = "staging"
  project_name = var.project_name
  region       = var.aws_region

  # ステージング環境固有の設定
  log_retention_days         = 14
  ecs_instance_type          = "t3.medium"
  app_desired_count          = 2
  enable_deletion_protection = false
  enable_mfa                 = true

  common_tags = {
    Environment = local.environment
    Project     = local.project_name
    ManagedBy   = "Terraform"
    CostCenter  = "engineering"
  }
}

# ====================================
# App Infrastructure Module
# ====================================

module "app_infrastructure" {
  source = "../../"

  # 基本設定
  project_name = local.project_name
  environment  = local.environment
  region       = local.region

  # ネットワーク設定
  vpc_cidr = "10.1.0.0/16"
  availability_zones = [
    "ap-northeast-1a",
    "ap-northeast-1c",
    "ap-northeast-1d"
  ]

  # ECS設定
  ecs_instance_type = local.ecs_instance_type

  # アプリケーション設定
  app_name          = "nextjs-app"
  app_port          = 3000
  app_cpu           = 512
  app_memory        = 1024
  app_desired_count = local.app_desired_count
  app_health_path   = "/api/health"

  # ログ設定
  log_retention_days = local.log_retention_days

  # セキュリティ設定
  enable_deletion_protection = local.enable_deletion_protection
  enable_mfa                 = local.enable_mfa
  certificate_arn            = var.certificate_arn

  # 監視設定
  alert_email   = var.alert_email
  enable_xray   = true
  enable_canary = false

  # Cognito設定
  enable_cognito = true
  cognito_callback_urls = [
    "https://staging.${local.project_name}.example.com/auth/callback"
  ]
  cognito_logout_urls = [
    "https://staging.${local.project_name}.example.com"
  ]

  # タグ
  common_tags = local.common_tags
}
