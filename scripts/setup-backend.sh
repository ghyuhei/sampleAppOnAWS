#!/bin/bash
# ====================================
# Terraform Backend Setup Script
# ====================================
# S3バケットとDynamoDBテーブルを作成してTerraformバックエンドをセットアップします
#
# 使用方法:
#   ./scripts/setup-backend.sh <environment> <aws-account-id>
#
# 例:
#   ./scripts/setup-backend.sh dev 123456789012
#   ./scripts/setup-backend.sh staging 123456789012
#   ./scripts/setup-backend.sh prod 123456789012

set -euo pipefail

# ====================================
# 変数設定
# ====================================

ENVIRONMENT=${1:-dev}
AWS_ACCOUNT_ID=${2:-}
REGION="ap-northeast-1"
BUCKET_NAME="your-company-terraform-state-${ENVIRONMENT}"
DYNAMODB_TABLE="terraform-state-lock-${ENVIRONMENT}"
KMS_ALIAS="alias/terraform-state-${ENVIRONMENT}"

# ====================================
# 引数チェック
# ====================================

if [ -z "$AWS_ACCOUNT_ID" ]; then
  echo "Error: AWS Account ID is required"
  echo "Usage: $0 <environment> <aws-account-id>"
  echo "Example: $0 dev 123456789012"
  exit 1
fi

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  echo "Error: Environment must be one of: dev, staging, prod"
  exit 1
fi

echo "================================================"
echo "Terraform Backend Setup"
echo "================================================"
echo "Environment:     ${ENVIRONMENT}"
echo "AWS Account ID:  ${AWS_ACCOUNT_ID}"
echo "Region:          ${REGION}"
echo "S3 Bucket:       ${BUCKET_NAME}"
echo "DynamoDB Table:  ${DYNAMODB_TABLE}"
echo "KMS Alias:       ${KMS_ALIAS}"
echo "================================================"
echo ""
read -p "Continue? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
  echo "Aborted."
  exit 0
fi

# ====================================
# KMS Key作成
# ====================================

echo ""
echo "Creating KMS Key..."
KMS_KEY_ID=$(aws kms create-key \
  --region "${REGION}" \
  --description "KMS key for Terraform state encryption (${ENVIRONMENT})" \
  --tags "TagKey=Name,TagValue=terraform-state-${ENVIRONMENT}" \
         "TagKey=Environment,TagValue=${ENVIRONMENT}" \
         "TagKey=Purpose,TagValue=terraform-backend" \
  --query 'KeyMetadata.KeyId' \
  --output text)

echo "KMS Key ID: ${KMS_KEY_ID}"

# KMSエイリアス作成
aws kms create-alias \
  --region "${REGION}" \
  --alias-name "${KMS_ALIAS}" \
  --target-key-id "${KMS_KEY_ID}"

# キーローテーション有効化
aws kms enable-key-rotation \
  --region "${REGION}" \
  --key-id "${KMS_KEY_ID}"

echo "✓ KMS Key created and rotation enabled"

# ====================================
# S3 Bucket作成
# ====================================

echo ""
echo "Creating S3 Bucket..."

# バケット作成
aws s3api create-bucket \
  --bucket "${BUCKET_NAME}" \
  --region "${REGION}" \
  --create-bucket-configuration LocationConstraint="${REGION}"

# バージョニング有効化
aws s3api put-bucket-versioning \
  --bucket "${BUCKET_NAME}" \
  --versioning-configuration Status=Enabled

# 暗号化有効化
aws s3api put-bucket-encryption \
  --bucket "${BUCKET_NAME}" \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "aws:kms",
          "KMSMasterKeyID": "'"${KMS_KEY_ID}"'"
        },
        "BucketKeyEnabled": true
      }
    ]
  }'

# パブリックアクセスブロック
aws s3api put-public-access-block \
  --bucket "${BUCKET_NAME}" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# ライフサイクルポリシー（古いバージョンの削除）
aws s3api put-bucket-lifecycle-configuration \
  --bucket "${BUCKET_NAME}" \
  --lifecycle-configuration '{
    "Rules": [
      {
        "Id": "DeleteOldVersions",
        "Status": "Enabled",
        "NoncurrentVersionExpiration": {
          "NoncurrentDays": 90
        }
      }
    ]
  }'

# タグ設定
aws s3api put-bucket-tagging \
  --bucket "${BUCKET_NAME}" \
  --tagging 'TagSet=[
    {Key=Name,Value='"${BUCKET_NAME}"'},
    {Key=Environment,Value='"${ENVIRONMENT}"'},
    {Key=Purpose,Value=terraform-backend},
    {Key=ManagedBy,Value=script}
  ]'

echo "✓ S3 Bucket created and configured"

# ====================================
# DynamoDB Table作成
# ====================================

echo ""
echo "Creating DynamoDB Table..."

aws dynamodb create-table \
  --region "${REGION}" \
  --table-name "${DYNAMODB_TABLE}" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --sse-specification Enabled=true \
  --tags Key=Name,Value="${DYNAMODB_TABLE}" \
         Key=Environment,Value="${ENVIRONMENT}" \
         Key=Purpose,Value=terraform-backend \
         Key=ManagedBy,Value=script

# Point-in-Time Recovery有効化
aws dynamodb update-continuous-backups \
  --region "${REGION}" \
  --table-name "${DYNAMODB_TABLE}" \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true

echo "✓ DynamoDB Table created with Point-in-Time Recovery enabled"

# ====================================
# バックエンド設定ファイル更新
# ====================================

echo ""
echo "Updating backend configuration file..."

BACKEND_CONFIG_FILE="infrastructure/terraform/environments/${ENVIRONMENT}/backend.hcl"
cat > "${BACKEND_CONFIG_FILE}" <<EOF
bucket         = "${BUCKET_NAME}"
key            = "ecs-app/${ENVIRONMENT}/terraform.tfstate"
region         = "${REGION}"
dynamodb_table = "${DYNAMODB_TABLE}"
encrypt        = true
kms_key_id     = "arn:aws:kms:${REGION}:${AWS_ACCOUNT_ID}:key/${KMS_KEY_ID}"
EOF

echo "✓ Backend configuration file updated: ${BACKEND_CONFIG_FILE}"

# ====================================
# 完了
# ====================================

echo ""
echo "================================================"
echo "✓ Terraform Backend Setup Complete!"
echo "================================================"
echo ""
echo "Next steps:"
echo "1. Review the generated backend configuration file:"
echo "   infrastructure/terraform/environments/${ENVIRONMENT}/backend.hcl"
echo "2. Initialize Terraform with backend:"
echo "   cd infrastructure/terraform/environments/${ENVIRONMENT}"
echo "   terraform init -backend-config=backend.hcl"
echo ""
echo "3. If migrating existing state:"
echo "   terraform init -backend-config=backend.hcl -migrate-state"
echo ""
echo "Resources created:"
echo "  - KMS Key: ${KMS_KEY_ID}"
echo "  - S3 Bucket: ${BUCKET_NAME}"
echo "  - DynamoDB Table: ${DYNAMODB_TABLE}"
echo "================================================"
