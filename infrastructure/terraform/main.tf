# ====================================
# Root Module - App Infrastructure
# ====================================
#
# このモジュールは各環境から呼び出されます
# - environments/dev/
# - environments/staging/
# - environments/prod/

# ====================================
# VPC Module
# ====================================

module "vpc" {
  source = "./modules/vpc"

  project_name       = var.project_name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  region             = var.region
}

# ====================================
# ECS Cluster Module
# ====================================

module "ecs" {
  source = "./modules/ecs"

  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  ecs_instance_type = var.ecs_instance_type
}

# ====================================
# ALB Module
# ====================================

module "alb" {
  source = "./modules/alb"

  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  certificate_arn   = var.certificate_arn
}

# ====================================
# ECR Repository
# ====================================

resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-${var.app_name}"
  image_tag_mutability = var.ecr_image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.ecr_scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "${var.project_name}-${var.app_name}"
    Application = var.app_name
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.ecr_lifecycle_tagged_images} tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "latest"]
          countType     = "imageCountMoreThan"
          countNumber   = var.ecr_lifecycle_tagged_images
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images after ${var.ecr_lifecycle_untagged_days} day(s)"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.ecr_lifecycle_untagged_days
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ====================================
# CloudWatch Logs
# ====================================

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}/${var.app_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-${var.app_name}-logs"
    Application = var.app_name
  }
}

# ====================================
# ECS Task Definition and Service
# ====================================
# Task Definition と Service は ecspresso で管理します
# ecspresso/ ディレクトリを参照してください

# ====================================
# ALB Target Group
# ====================================

resource "aws_lb_target_group" "app" {
  name                 = "${var.project_name}-${var.app_name}-tg"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = module.vpc.vpc_id
  target_type          = "instance"
  deregistration_delay = var.alb_deregistration_delay

  health_check {
    enabled             = true
    path                = var.app_health_path
    healthy_threshold   = var.alb_healthy_threshold
    unhealthy_threshold = var.alb_unhealthy_threshold
    timeout             = var.alb_health_check_timeout
    interval            = var.alb_health_check_interval
    matcher             = "200"
    protocol            = "HTTP"
  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = var.alb_stickiness_cookie_duration
    enabled         = var.alb_stickiness_enabled
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-${var.app_name}-tg"
    Application = var.app_name
  }
}

# ====================================
# ALB Listener Rule
# ====================================

resource "aws_lb_listener_rule" "app" {
  listener_arn = module.alb.http_listener_arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.app_name}-rule"
    Application = var.app_name
  }
}

# ====================================
# Security Group Rule
# ====================================

resource "aws_security_group_rule" "alb_to_ecs" {
  type                     = "ingress"
  from_port                = 32768
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = module.ecs.ecs_instance_security_group_id
  source_security_group_id = module.alb.alb_security_group_id
  description              = "Allow dynamic port mapping from ALB"
}

# ====================================
# Random Password for CloudFront Custom Header
# ====================================

resource "random_password" "cloudfront_header" {
  length  = 32
  special = true
}

# ====================================
# WAF Module
# ====================================

module "waf" {
  source = "./modules/waf"

  project_name = var.project_name
  rate_limit   = var.waf_rate_limit
}

# ====================================
# S3 Module (Static Assets)
# ====================================

module "s3" {
  source = "./modules/s3"

  project_name = var.project_name
  # CloudFront ARN is set via separate resource after CloudFront creation
}

# ====================================
# CloudFront Module
# ====================================

module "cloudfront" {
  source = "./modules/cloudfront"

  project_name                = var.project_name
  alb_domain_name             = module.alb.alb_dns_name
  s3_bucket_domain_name       = module.s3.bucket_regional_domain_name
  s3_origin_access_control_id = module.s3.origin_access_control_id
  waf_web_acl_arn             = var.cloudfront_enable_waf ? module.waf.web_acl_arn : ""
  custom_header_value         = random_password.cloudfront_header.result
  price_class                 = var.cloudfront_price_class
}

# ====================================
# S3 Bucket Policy (after CloudFront creation)
# ====================================

resource "aws_s3_bucket_policy" "static_assets_cloudfront" {
  bucket = module.s3.bucket_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${module.s3.bucket_arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = module.cloudfront.distribution_arn
          }
        }
      }
    ]
  })

  depends_on = [module.cloudfront, module.s3]
}

# ====================================
# Cognito Module
# ====================================

module "cognito" {
  count  = var.enable_cognito ? 1 : 0
  source = "./modules/cognito"

  project_name           = var.project_name
  environment            = var.environment
  callback_urls          = var.cognito_callback_urls
  logout_urls            = var.cognito_logout_urls
  enable_mfa             = var.enable_mfa
  deletion_protection    = var.enable_deletion_protection
  advanced_security_mode = var.environment == "prod" ? "ENFORCED" : "AUDIT"
  log_retention_days     = var.log_retention_days
}

# ====================================
# SSM Parameter Store Module
# ====================================

module "ssm" {
  source = "./modules/ssm"

  project_name   = var.project_name
  environment    = var.environment
  region         = var.region
  aws_account_id = data.aws_caller_identity.current.account_id
  log_level      = var.environment == "prod" ? "warn" : "debug"

  # Cognito configuration
  cognito_user_pool_id  = var.enable_cognito ? module.cognito[0].user_pool_id : ""
  cognito_client_id     = var.enable_cognito ? module.cognito[0].backend_client_id : ""
  cognito_client_secret = var.enable_cognito ? module.cognito[0].backend_client_secret : ""
}

# ====================================
# Data Sources
# ====================================

data "aws_caller_identity" "current" {}

# ====================================
# Attach SSM Policy to ECS Task Role
# ====================================

resource "aws_iam_role_policy_attachment" "ecs_task_ssm" {
  role       = module.ecs.ecs_task_role_name
  policy_arn = module.ssm.ssm_read_policy_arn
}

