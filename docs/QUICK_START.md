# クイックスタートガイド

このガイドでは、ECS Managed Appを最速でセットアップ・デプロイする方法を説明します。

## 前提条件

- AWS CLIの設定が完了していること
- Terraformがインストールされていること (v1.10以上)
- Node.jsがインストールされていること (v22以上)
- Dockerがインストールされていること
- gitがインストールされていること
- ecspressoがインストールされていること (v2.6.1以上)

## ステップ1: 環境変数の設定

### 1.1 環境変数ファイルをコピー

```bash
# ルートディレクトリ
cp .env.example .env

# フロントエンド
cp apps/frontend/.env.example apps/frontend/.env.local

# バックエンド
cp apps/backend/.env.example apps/backend/.env.local
```

### 1.2 環境変数を編集

`.env`ファイルを開いて、以下の値を設定します:

```bash
# AWS設定
AWS_ACCOUNT_ID=123456789012  # あなたのAWSアカウントID
AWS_REGION=ap-northeast-1

# プロジェクト設定
PROJECT_NAME=nextjs-ecs
ENVIRONMENT=dev

# アラート
ALERT_EMAIL=your-email@example.com
```

## ステップ2: Terraform Backend のセットアップ

### 2.1 S3バケットとDynamoDBテーブルを作成

```bash
# setup-backend.shスクリプトを使用
./scripts/setup-backend.sh dev <YOUR_AWS_ACCOUNT_ID>
```

このスクリプトは以下を自動的に作成します:
- Terraformステート用のS3バケット
- ステートロック用のDynamoDBテーブル

### 2.2 backend.hcl を編集

各環境の`backend.hcl`を編集します:

```bash
# 開発環境の場合
vi infrastructure/terraform/environments/dev/backend.hcl
```

```hcl
bucket         = "your-terraform-state-bucket"  # 実際のバケット名に変更
key            = "ecs-app/dev/terraform.tfstate"
region         = "ap-northeast-1"
encrypt        = true
dynamodb_table = "your-terraform-lock-table"    # 実際のテーブル名に変更
```

## ステップ3: 依存関係のインストール

```bash
# ルートディレクトリで実行
npm install

# または Makefileを使用
make install
```

## ステップ4: インフラのデプロイ

### 4.1 Makefileを使用する場合（推奨）

```bash
# セットアップ（初回のみ）
make setup ENV=dev ACCOUNT_ID=123456789012

# Terraformプランの確認
make plan ENV=dev

# インフラのデプロイ
make apply ENV=dev
```

### 4.2 手動でTerraformを実行する場合

```bash
# Terraformディレクトリに移動
cd infrastructure/terraform/environments/dev

# 初期化
terraform init -backend-config=backend.hcl

# プランの確認
terraform plan

# 適用
terraform apply
```

## ステップ5: アプリケーションのビルドとデプロイ

### 5.1 Makefileを使用する場合（推奨）

```bash
# すべてのコンポーネントをビルド
make build

# フロントエンドとバックエンドの両方をデプロイ
make deploy ENV=dev COMPONENT=all

# フロントエンドのみをデプロイ
make deploy ENV=dev COMPONENT=frontend

# バックエンドのみをデプロイ
make deploy ENV=dev COMPONENT=backend
```

### 5.2 手動でデプロイする場合

```bash
# デプロイスクリプトを使用
./scripts/deploy.sh dev all
```

## ステップ6: デプロイの確認

### 6.1 Terraform出力の確認

```bash
# Makefileを使用
make outputs ENV=dev

# または手動で
cd infrastructure/terraform/environments/dev
terraform output
```

以下のような出力が表示されます:

```
alb_dns_name = "nextjs-ecs-alb-xxxxxxxxx.ap-northeast-1.elb.amazonaws.com"
cloudfront_domain = "d1234567890abc.cloudfront.net"
ecr_repository_url = "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/nextjs-ecs-frontend"
```

### 6.2 ECSサービスのステータス確認

```bash
# Makefileを使用
make status ENV=dev

# または手動で
cd infrastructure/ecspresso
ecspresso status --config config.yaml
```

### 6.3 アプリケーションへのアクセス

ブラウザで以下のURLにアクセスします:

```
# ALB経由（開発環境）
http://<alb_dns_name>

# CloudFront経由（本番環境推奨）
https://<cloudfront_domain>
```

## ステップ7: ローカル開発環境の起動

### 7.1 フロントエンド

```bash
# Makefileを使用
make dev-frontend

# または直接実行
npm run dev:frontend
```

ブラウザで http://localhost:3000 にアクセス

### 7.2 バックエンド

```bash
# Makefileを使用
make dev-backend

# または直接実行
npm run dev:backend
```

API は http://localhost:3001 で起動します

## よく使うコマンド

### テストの実行

```bash
# すべてのテストを実行
make test

# フロントエンドのテストのみ
make test-frontend

# バックエンドのテストのみ
make test-backend

# E2Eテスト
make test-e2e

# 負荷テスト
make test-load
```

### コード品質チェック

```bash
# Lint
make lint

# 型チェック
make type-check

# フォーマット
make format
```

### ログの確認

```bash
# ECSサービスのログを表示
make logs ENV=dev

# または直接実行
aws logs tail /ecs/nextjs-ecs/nextjs-app --follow --region ap-northeast-1
```

### クリーンアップ

```bash
# ビルド成果物を削除
make clean

# Terraform一時ファイルを削除
make clean-tf
```

## トラブルシューティング

### Terraform backend の初期化エラー

**エラー**: `Error: Backend configuration changed`

**解決方法**:
```bash
cd infrastructure/terraform/environments/dev
terraform init -reconfigure -backend-config=backend.hcl
```

### ECRへのプッシュエラー

**エラー**: `denied: Your authorization token has expired`

**解決方法**:
```bash
# ECRに再ログイン
aws ecr get-login-password --region ap-northeast-1 | \
  docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.ap-northeast-1.amazonaws.com
```

### ECSタスクが起動しない

**確認ポイント**:
1. ECRにイメージがプッシュされているか確認
2. ECSタスク定義のログを確認
3. セキュリティグループの設定を確認

```bash
# ECSタスクのログを確認
aws ecs describe-tasks \
  --cluster nextjs-ecs-cluster \
  --tasks <TASK_ARN> \
  --region ap-northeast-1
```

### Docker Build エラー

**エラー**: `ERROR [internal] load metadata`

**解決方法**:
```bash
# Dockerのキャッシュをクリア
docker system prune -a
```

## 次のステップ

- [デプロイメントガイド](./DEPLOYMENT_GUIDE.md) - 詳細なデプロイ手順
- [テストガイド](./TESTING_GUIDE.md) - テスト戦略と実行方法
- [アーキテクチャドキュメント](./architecture.md) - システム構成の詳細
- [エンタープライズセットアップ](./ENTERPRISE_SETUP.md) - 本番環境構築ガイド

## サポート

問題が発生した場合は、以下を確認してください:

1. GitHub Issues: プロジェクトのissuesページ
2. ドキュメント: [docs/](../docs/) ディレクトリ
3. AWS ドキュメント: [AWS公式ドキュメント](https://docs.aws.amazon.com/)

## まとめ

これで基本的なセットアップとデプロイが完了しました！

クイックコマンドリファレンス:
```bash
# セットアップ
make setup ENV=dev ACCOUNT_ID=123456789012
make apply ENV=dev

# デプロイ
make deploy ENV=dev COMPONENT=all

# 開発
make dev-frontend
make dev-backend

# テスト
make test

# 確認
make outputs ENV=dev
make status ENV=dev
```
