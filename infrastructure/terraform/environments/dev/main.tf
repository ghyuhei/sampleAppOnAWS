# ====================================
# Development Environment
# ====================================
#
# このファイルは開発環境のルートモジュールです
# 共通のモジュールを呼び出し、環境固有の値を設定します

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
      Environment = "dev"
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
  environment  = "dev"
  project_name = var.project_name
  region       = var.aws_region

  # 開発環境固有の設定
  log_retention_days         = 7
  ecs_instance_type          = "t3.medium"
  app_desired_count          = 1
  enable_deletion_protection = false
  enable_mfa                 = false

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
  source = "../../" # ルートディレクトリのモジュールを参照

  # 基本設定
  project_name = local.project_name
  environment  = local.environment
  region       = local.region

  # ネットワーク設定
  vpc_cidr = "10.0.0.0/16"
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

  # 監視設定
  alert_email   = var.alert_email
  enable_xray   = true
  enable_canary = false

  # Cognito設定
  enable_cognito = true
  cognito_callback_urls = [
    "http://localhost:3000/auth/callback"
  ]
  cognito_logout_urls = [
    "http://localhost:3000"
  ]

  # タグ
  common_tags = local.common_tags
}
