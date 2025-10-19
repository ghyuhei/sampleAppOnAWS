# ====================================
# Makefile - ECS Managed App
# ====================================
# プロジェクトのセットアップとデプロイを簡易化するMakefile
#
# 使用例:
#   make setup ENV=dev ACCOUNT_ID=123456789012
#   make deploy ENV=dev COMPONENT=all
#   make test

.PHONY: help setup deploy destroy clean test lint format

# デフォルト設定
ENV ?= dev
COMPONENT ?= all
AWS_REGION ?= ap-northeast-1
TERRAFORM_DIR = infrastructure/terraform/environments/$(ENV)

# カラー出力
GREEN  := \033[0;32m
YELLOW := \033[1;33m
RED    := \033[0;31m
NC     := \033[0m # No Color

##@ General

help: ## このヘルプメッセージを表示
	@echo 'Usage:'
	@echo '  make <target> [ENV=dev|staging|prod] [COMPONENT=frontend|backend|all]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*##"; printf "\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(YELLOW)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Setup

setup: ## インフラをセットアップ (ENV, ACCOUNT_ID必須)
	@echo "$(GREEN)[INFO]$(NC) Setting up $(ENV) environment..."
	@if [ -z "$(ACCOUNT_ID)" ]; then \
		echo "$(RED)[ERROR]$(NC) ACCOUNT_ID is required. Usage: make setup ENV=dev ACCOUNT_ID=123456789012"; \
		exit 1; \
	fi
	@./scripts/setup-backend.sh $(ENV) $(ACCOUNT_ID)
	@echo "$(GREEN)[INFO]$(NC) Initializing Terraform..."
	@cd $(TERRAFORM_DIR) && terraform init -backend-config=backend.hcl
	@echo "$(GREEN)[SUCCESS]$(NC) Setup completed for $(ENV) environment"

init: ## Terraformを初期化
	@echo "$(GREEN)[INFO]$(NC) Initializing Terraform for $(ENV) environment..."
	@cd $(TERRAFORM_DIR) && terraform init -backend-config=backend.hcl

plan: ## Terraformプランを表示
	@echo "$(GREEN)[INFO]$(NC) Planning infrastructure for $(ENV) environment..."
	@cd $(TERRAFORM_DIR) && terraform plan

apply: ## Terraformを適用
	@echo "$(GREEN)[INFO]$(NC) Applying infrastructure for $(ENV) environment..."
	@cd $(TERRAFORM_DIR) && terraform apply
	@echo "$(GREEN)[SUCCESS]$(NC) Infrastructure applied for $(ENV) environment"

destroy: ## インフラを削除 (要確認)
	@echo "$(RED)[WARNING]$(NC) This will destroy all infrastructure in $(ENV) environment!"
	@cd $(TERRAFORM_DIR) && terraform destroy

##@ Development

install: ## 依存関係をインストール
	@echo "$(GREEN)[INFO]$(NC) Installing dependencies..."
	@npm install
	@echo "$(GREEN)[SUCCESS]$(NC) Dependencies installed"

dev-frontend: ## フロントエンドを開発モードで起動
	@echo "$(GREEN)[INFO]$(NC) Starting frontend in development mode..."
	@npm run dev:frontend

dev-backend: ## バックエンドを開発モードで起動
	@echo "$(GREEN)[INFO]$(NC) Starting backend in development mode..."
	@npm run dev:backend

build: ## すべてのアプリケーションをビルド
	@echo "$(GREEN)[INFO]$(NC) Building all applications..."
	@npm run build:all
	@echo "$(GREEN)[SUCCESS]$(NC) Build completed"

build-frontend: ## フロントエンドをビルド
	@echo "$(GREEN)[INFO]$(NC) Building frontend..."
	@npm run build:frontend

build-backend: ## バックエンドをビルド
	@echo "$(GREEN)[INFO]$(NC) Building backend..."
	@npm run build:backend

##@ Testing

test: ## すべてのテストを実行
	@echo "$(GREEN)[INFO]$(NC) Running all tests..."
	@npm run test:all
	@echo "$(GREEN)[SUCCESS]$(NC) All tests passed"

test-frontend: ## フロントエンドのテストを実行
	@echo "$(GREEN)[INFO]$(NC) Running frontend tests..."
	@npm run test:frontend

test-backend: ## バックエンドのテストを実行
	@echo "$(GREEN)[INFO]$(NC) Running backend tests..."
	@npm run test:backend

test-e2e: ## E2Eテストを実行
	@echo "$(GREEN)[INFO]$(NC) Running E2E tests..."
	@npm run test:e2e

test-load: ## 負荷テストを実行
	@echo "$(GREEN)[INFO]$(NC) Running load tests..."
	@npm run test:load

##@ Code Quality

lint: ## Lintを実行
	@echo "$(GREEN)[INFO]$(NC) Running lint..."
	@npm run lint:all

type-check: ## 型チェックを実行
	@echo "$(GREEN)[INFO]$(NC) Running type check..."
	@npm run type-check:all

format: ## コードをフォーマット
	@echo "$(GREEN)[INFO]$(NC) Formatting code..."
	@npx prettier --write "**/*.{ts,tsx,js,jsx,json,md}"
	@echo "$(GREEN)[SUCCESS]$(NC) Code formatted"

##@ Deployment

deploy: ## アプリケーションをデプロイ (ENV, COMPONENT必須)
	@echo "$(GREEN)[INFO]$(NC) Deploying $(COMPONENT) to $(ENV) environment..."
	@./scripts/deploy.sh $(ENV) $(COMPONENT)
	@echo "$(GREEN)[SUCCESS]$(NC) Deployment completed"

docker-build-frontend: ## フロントエンドのDockerイメージをビルド
	@echo "$(GREEN)[INFO]$(NC) Building frontend Docker image..."
	@cd apps/frontend && docker build -t ecs-frontend:latest .

docker-build-backend: ## バックエンドのDockerイメージをビルド
	@echo "$(GREEN)[INFO]$(NC) Building backend Docker image..."
	@cd apps/backend && docker build -t ecs-backend:latest .

docker-build-all: docker-build-frontend docker-build-backend ## すべてのDockerイメージをビルド

##@ Cleanup

clean: ## ビルド成果物を削除
	@echo "$(GREEN)[INFO]$(NC) Cleaning build artifacts..."
	@npm run clean
	@echo "$(GREEN)[SUCCESS]$(NC) Cleanup completed"

clean-tf: ## Terraform一時ファイルを削除
	@echo "$(GREEN)[INFO]$(NC) Cleaning Terraform files..."
	@find infrastructure/terraform -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@find infrastructure/terraform -type f -name "*.tfstate*" -exec rm -f {} + 2>/dev/null || true
	@echo "$(GREEN)[SUCCESS]$(NC) Terraform files cleaned"

##@ Information

outputs: ## Terraform出力を表示
	@echo "$(GREEN)[INFO]$(NC) Showing Terraform outputs for $(ENV) environment..."
	@cd $(TERRAFORM_DIR) && terraform output

status: ## ECSサービスのステータスを表示
	@echo "$(GREEN)[INFO]$(NC) Checking ECS service status..."
	@cd infrastructure/ecspresso && ecspresso status --config config.yaml

logs: ## ECSサービスのログを表示
	@echo "$(GREEN)[INFO]$(NC) Fetching ECS service logs..."
	@aws logs tail /ecs/nextjs-ecs/nextjs-app --follow --region $(AWS_REGION)

##@ CI/CD

ci-test: ## CI環境でテストを実行
	@echo "$(GREEN)[INFO]$(NC) Running CI tests..."
	@npm run test:frontend -- --run
	@npm run test:backend -- --run

ci-build: ## CI環境でビルドを実行
	@echo "$(GREEN)[INFO]$(NC) Running CI build..."
	@npm run build:all

##@ Docker Compose (Local Development)

up: ## Docker Composeで起動
	@echo "$(GREEN)[INFO]$(NC) Starting services with Docker Compose..."
	@docker-compose up -d
	@echo "$(GREEN)[SUCCESS]$(NC) Services started"

down: ## Docker Composeで停止
	@echo "$(GREEN)[INFO]$(NC) Stopping services..."
	@docker-compose down
	@echo "$(GREEN)[SUCCESS]$(NC) Services stopped"

restart: down up ## Docker Composeで再起動
