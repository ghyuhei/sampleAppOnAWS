# ====================================
# Terraform Backend Configuration - Development
# ====================================
#
# このファイルはTerraformのリモートステート管理を設定します
# S3にステートファイルを保存し、DynamoDBでロックを管理します
#
# 使用方法:
#   terraform init -backend-config=backend.hcl

bucket         = "your-terraform-state-bucket"
key            = "ecs-app/dev/terraform.tfstate"
region         = "ap-northeast-1"
encrypt        = true
dynamodb_table = "your-terraform-lock-table"

# オプション設定
# profile = "default"
# role_arn = "arn:aws:iam::ACCOUNT_ID:role/TerraformRole"
