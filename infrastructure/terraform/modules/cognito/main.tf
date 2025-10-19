# ====================================
# Cognito User Pool
# ====================================

resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-user-pool"

  # パスワードポリシー
  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  # アカウント復旧設定
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # MFA設定
  mfa_configuration = var.enable_mfa ? "OPTIONAL" : "OFF"

  software_token_mfa_configuration {
    enabled = var.enable_mfa
  }

  # ユーザー属性
  schema {
    name                     = "email"
    attribute_data_type      = "String"
    required                 = true
    mutable                  = true
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  schema {
    name                     = "name"
    attribute_data_type      = "String"
    required                 = false
    mutable                  = true
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  # 自動検証
  auto_verified_attributes = ["email"]

  # ユーザー登録設定
  admin_create_user_config {
    allow_admin_create_user_only = var.admin_create_user_only
  }

  # Email設定
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # アカウント削除保護
  deletion_protection = var.deletion_protection ? "ACTIVE" : "INACTIVE"

  # ユーザープール追加設定
  user_pool_add_ons {
    advanced_security_mode = var.advanced_security_mode
  }

  # デバイス記憶設定
  device_configuration {
    challenge_required_on_new_device      = true
    device_only_remembered_on_user_prompt = true
  }

  tags = {
    Name = "${var.project_name}-user-pool"
  }
}

# ====================================
# Cognito User Pool Domain
# ====================================

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.project_name}-${var.environment}"
  user_pool_id = aws_cognito_user_pool.main.id
}

# ====================================
# Cognito User Pool Client (Frontend)
# ====================================

resource "aws_cognito_user_pool_client" "frontend" {
  name         = "${var.project_name}-frontend-client"
  user_pool_id = aws_cognito_user_pool.main.id

  # OAuth設定
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  callback_urls                        = var.callback_urls
  logout_urls                          = var.logout_urls
  supported_identity_providers         = ["COGNITO"]

  # トークン設定
  access_token_validity  = 60 # 60分
  id_token_validity      = 60 # 60分
  refresh_token_validity = 30 # 30日

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  # セキュリティ設定
  prevent_user_existence_errors = "ENABLED"

  # 読み取り・書き込み属性
  read_attributes = [
    "email",
    "email_verified",
    "name",
  ]

  write_attributes = [
    "email",
    "name",
  ]

  # PKCE設定（推奨）
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
  ]
}

# ====================================
# Cognito User Pool Client (Backend API)
# ====================================

resource "aws_cognito_user_pool_client" "backend" {
  name         = "${var.project_name}-backend-client"
  user_pool_id = aws_cognito_user_pool.main.id

  # Machine-to-Machine認証用
  generate_secret = true

  # トークン設定
  access_token_validity  = 60 # 60分
  id_token_validity      = 60 # 60分
  refresh_token_validity = 30 # 30日

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  # セキュリティ設定
  prevent_user_existence_errors = "ENABLED"

  # 認証フロー
  explicit_auth_flows = [
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
  ]
}

# ====================================
# Cognito Identity Pool
# ====================================

resource "aws_cognito_identity_pool" "main" {
  identity_pool_name               = "${var.project_name}-identity-pool"
  allow_unauthenticated_identities = false
  allow_classic_flow               = false

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.frontend.id
    provider_name           = aws_cognito_user_pool.main.endpoint
    server_side_token_check = true
  }

  tags = {
    Name = "${var.project_name}-identity-pool"
  }
}

# ====================================
# IAM Roles for Identity Pool
# ====================================

# 認証済みユーザー用ロール
resource "aws_iam_role" "authenticated" {
  name = "${var.project_name}-cognito-authenticated-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "cognito-identity.amazonaws.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.main.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "authenticated"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-cognito-authenticated-role"
  }
}

# 認証済みユーザー用ポリシー
resource "aws_iam_role_policy" "authenticated" {
  name = "${var.project_name}-cognito-authenticated-policy"
  role = aws_iam_role.authenticated.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "mobileanalytics:PutEvents",
          "cognito-sync:*",
          "cognito-identity:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Identity Poolへのロール紐付け
resource "aws_cognito_identity_pool_roles_attachment" "main" {
  identity_pool_id = aws_cognito_identity_pool.main.id

  roles = {
    authenticated = aws_iam_role.authenticated.arn
  }
}

# ====================================
# Cognito User Pool Groups (RBAC)
# ====================================

resource "aws_cognito_user_group" "admin" {
  name         = "admin"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Administrator group with full access"
  precedence   = 1
}

resource "aws_cognito_user_group" "user" {
  name         = "user"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Standard user group"
  precedence   = 10
}

# ====================================
# CloudWatch Log Group for User Pool
# ====================================

resource "aws_cloudwatch_log_group" "cognito" {
  name              = "/aws/cognito/${var.project_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-cognito-logs"
  }
}
