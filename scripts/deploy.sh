#!/bin/bash
set -euo pipefail

# ====================================
# Deployment Script
# ====================================
# アプリケーションをECSにデプロイするスクリプト
#
# 使用方法:
#   ./scripts/deploy.sh <environment> <component>
#
# 例:
#   ./scripts/deploy.sh dev frontend
#   ./scripts/deploy.sh prod backend
#   ./scripts/deploy.sh staging all

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ====================================
# Color Output
# ====================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

function warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

function error() {
  echo -e "${RED}[ERROR]${NC} $1"
  exit 1
}

# ====================================
# Validation
# ====================================
if [ $# -lt 2 ]; then
  error "Usage: $0 <environment> <component>\nEnvironment: dev, staging, prod\nComponent: frontend, backend, all"
fi

ENVIRONMENT=$1
COMPONENT=$2

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  error "Invalid environment: $ENVIRONMENT. Must be one of: dev, staging, prod"
fi

# Validate component
if [[ ! "$COMPONENT" =~ ^(frontend|backend|all)$ ]]; then
  error "Invalid component: $COMPONENT. Must be one of: frontend, backend, all"
fi

info "Deploying ${COMPONENT} to ${ENVIRONMENT} environment..."

# ====================================
# AWS Configuration
# ====================================
AWS_REGION=${AWS_REGION:-ap-northeast-1}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")

if [ -z "$AWS_ACCOUNT_ID" ]; then
  error "Failed to get AWS Account ID. Please configure AWS credentials."
fi

info "AWS Account ID: ${AWS_ACCOUNT_ID}"
info "AWS Region: ${AWS_REGION}"

# ====================================
# Get Terraform Outputs
# ====================================
TERRAFORM_DIR="${PROJECT_ROOT}/infrastructure/terraform/environments/${ENVIRONMENT}"

if [ ! -d "$TERRAFORM_DIR" ]; then
  error "Terraform directory not found: $TERRAFORM_DIR"
fi

cd "$TERRAFORM_DIR"

info "Initializing Terraform..."
terraform init -backend-config=backend.hcl > /dev/null

info "Getting Terraform outputs..."
ECR_FRONTEND_URL=$(terraform output -raw ecr_frontend_url 2>/dev/null || echo "")
ECR_BACKEND_URL=$(terraform output -raw ecr_backend_url 2>/dev/null || echo "")
ECS_CLUSTER=$(terraform output -raw ecs_cluster_name 2>/dev/null || echo "")

# ====================================
# Docker Login
# ====================================
info "Logging in to ECR..."
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# ====================================
# Build and Push Function
# ====================================
function build_and_push() {
  local app_name=$1
  local ecr_url=$2
  local app_dir="${PROJECT_ROOT}/apps/${app_name}"

  if [ -z "$ecr_url" ]; then
    error "ECR URL not found for ${app_name}"
  fi

  info "Building ${app_name}..."

  cd "$app_dir"

  # Build Docker image
  IMAGE_TAG="$(git rev-parse --short HEAD)"
  FULL_IMAGE_TAG="${ecr_url}:${IMAGE_TAG}"
  LATEST_TAG="${ecr_url}:latest"

  docker build -t "$FULL_IMAGE_TAG" -t "$LATEST_TAG" .

  # Push to ECR
  info "Pushing ${app_name} to ECR..."
  docker push "$FULL_IMAGE_TAG"
  docker push "$LATEST_TAG"

  info "${app_name} pushed successfully: ${FULL_IMAGE_TAG}"
}

# ====================================
# Deploy Function
# ====================================
function deploy_service() {
  local service_name=$1

  info "Deploying ${service_name} to ECS..."

  cd "${PROJECT_ROOT}/infrastructure/ecspresso"

  # Deploy with ecspresso
  ecspresso deploy \
    --config config.yaml \
    --cluster "$ECS_CLUSTER" \
    --service "${service_name}" \
    --timeout 10m

  info "${service_name} deployed successfully"

  # Verify deployment
  ecspresso status --config config.yaml --cluster "$ECS_CLUSTER" --service "${service_name}"
}

# ====================================
# Upload Static Assets (Frontend only)
# ====================================
function upload_static_assets() {
  info "Uploading static assets to S3..."

  cd "${PROJECT_ROOT}/apps/frontend"

  # Build Next.js app
  npm run build

  # Get S3 bucket name
  cd "$TERRAFORM_DIR"
  S3_BUCKET=$(terraform output -raw static_assets_bucket_name 2>/dev/null || echo "")
  CLOUDFRONT_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")

  if [ -z "$S3_BUCKET" ]; then
    warn "S3 bucket not found. Skipping static asset upload."
    return
  fi

  # Sync static files
  cd "${PROJECT_ROOT}/apps/frontend"
  aws s3 sync .next/static "s3://${S3_BUCKET}/_next/static" \
    --delete \
    --cache-control "public,max-age=31536000,immutable" \
    --metadata-directive REPLACE

  info "Static assets uploaded successfully"

  # Invalidate CloudFront cache
  if [ -n "$CLOUDFRONT_ID" ]; then
    info "Invalidating CloudFront cache..."
    aws cloudfront create-invalidation \
      --distribution-id "$CLOUDFRONT_ID" \
      --paths "/_next/static/*"
  fi
}

# ====================================
# Main Deployment Logic
# ====================================
case $COMPONENT in
  frontend)
    build_and_push "frontend" "$ECR_FRONTEND_URL"
    upload_static_assets
    deploy_service "nextjs-app"
    ;;
  backend)
    build_and_push "backend" "$ECR_BACKEND_URL"
    deploy_service "backend-api"
    ;;
  all)
    build_and_push "frontend" "$ECR_FRONTEND_URL"
    build_and_push "backend" "$ECR_BACKEND_URL"
    upload_static_assets
    deploy_service "nextjs-app"
    deploy_service "backend-api"
    ;;
esac

# ====================================
# Summary
# ====================================
info "================================"
info "Deployment completed successfully!"
info "Environment: ${ENVIRONMENT}"
info "Component: ${COMPONENT}"
info "================================"
