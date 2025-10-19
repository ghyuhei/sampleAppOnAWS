# Staging Environment

このディレクトリにはステージング環境の Terraform 設定が含まれています。

## 使用方法

### 初回セットアップ

```bash
cd infrastructure/terraform/environments/staging

# 1. terraform.tfvars を作成 (推奨変数を設定)
cat > terraform.tfvars <<EOF
alert_email     = "staging-alerts@example.com"
certificate_arn = "arn:aws:acm:ap-northeast-1:ACCOUNT_ID:certificate/CERT_ID"
EOF

# 2. 初期化
terraform init

# 3. プランの確認
terraform plan

# 4. デプロイ
terraform apply
```

### S3 バックエンドを使用する場合

```bash
# 1. バックエンドのセットアップ
cd ../../../scripts
./setup-backend.sh staging YOUR_AWS_ACCOUNT_ID

# 2. backend.tf のコメントを解除

# 3. バックエンド設定で初期化
cd ../infrastructure/terraform/environments/staging
terraform init -backend-config=../../env/staging/backend.hcl
```

## 環境固有の設定

ステージング環境では以下の設定が適用されます：

- **VPC CIDR**: 10.1.0.0/16
- **ログ保持期間**: 14日
- **ECS インスタンスタイプ**: t3.medium
- **アプリケーション CPU/Memory**: 512/1024
- **アプリケーション desired count**: 2
- **削除保護**: 無効 (テスト環境のため)
- **MFA**: 有効
- **コストセンター**: engineering

## 必須変数

ステージング環境では以下の変数の設定を**強く推奨**します：

### terraform.tfvars

```hcl
# アラート通知先 (推奨)
alert_email = "staging-alerts@example.com"

# ACM証明書ARN (HTTPS用、推奨)
certificate_arn = "arn:aws:acm:ap-northeast-1:123456789012:certificate/xxx"
```

## 環境変数のカスタマイズ

### 方法1: terraform.tfvars ファイル（推奨）

```hcl
# terraform.tfvars (git ignore済み)
project_name    = "my-project"
alert_email     = "staging@example.com"
certificate_arn = "arn:aws:acm:..."
```

### 方法2: コマンドラインで指定

```bash
terraform apply \
  -var="alert_email=staging@example.com" \
  -var="certificate_arn=arn:aws:acm:..."
```

### 方法3: 環境変数

```bash
export TF_VAR_alert_email="staging@example.com"
export TF_VAR_certificate_arn="arn:aws:acm:..."
terraform apply
```

## 出力値の確認

```bash
# すべての出力値を表示
terraform output

# 特定の出力値を表示
terraform output alb_dns_name
terraform output cloudfront_domain_name
terraform output cognito_user_pool_id
```

## デプロイ後の確認

### 1. インフラストラクチャの確認

```bash
# ECS サービスの状態
aws ecs describe-services \
  --cluster nextjs-ecs-staging \
  --services nextjs-app

# ALB ターゲットヘルス
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)

# CloudFront ディストリビューション
aws cloudfront get-distribution \
  --id $(terraform output -raw cloudfront_distribution_id)
```

### 2. アプリケーションの動作確認

```bash
# ALB経由でアクセス
curl -I http://$(terraform output -raw alb_dns_name)

# CloudFront経由でアクセス
curl -I https://$(terraform output -raw cloudfront_domain_name)
```

### 3. ログの確認

```bash
# ECS タスクログ
aws logs tail /ecs/nextjs-ecs-staging/nextjs-app --follow

# ALB アクセスログ (有効化している場合)
aws logs tail /aws/elasticloadbalancing/app/nextjs-ecs-staging --follow
```

## モニタリング

### CloudWatch ダッシュボード

```bash
# ブラウザで開く
aws cloudwatch get-dashboard \
  --dashboard-name nextjs-ecs-staging
```

### アラームの確認

```bash
# アラーム状態の確認
aws cloudwatch describe-alarms \
  --alarm-names nextjs-ecs-staging-cpu-high \
                nextjs-ecs-staging-memory-high \
                nextjs-ecs-staging-error-count-high
```

## トラブルシューティング

### ECS タスクが起動しない

```bash
# タスク定義の確認
aws ecs describe-task-definition \
  --task-definition nextjs-app

# タスクイベントの確認
aws ecs describe-services \
  --cluster nextjs-ecs-staging \
  --services nextjs-app \
  --query 'services[0].events[0:5]'
```

### ALB ヘルスチェック失敗

```bash
# ターゲットヘルスの詳細確認
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)

# アプリケーションログを確認
aws logs tail /ecs/nextjs-ecs-staging/nextjs-app --follow
```

### Cognito 認証エラー

```bash
# User Pool 設定の確認
aws cognito-idp describe-user-pool \
  --user-pool-id $(terraform output -raw cognito_user_pool_id)

# App Client 設定の確認
aws cognito-idp describe-user-pool-client \
  --user-pool-id $(terraform output -raw cognito_user_pool_id) \
  --client-id $(terraform output -raw cognito_frontend_client_id)
```

### State のロックエラー

```bash
# ロックIDを確認
terraform force-unlock LOCK_ID

# DynamoDBで確認 (S3バックエンド使用時)
aws dynamodb get-item \
  --table-name terraform-state-lock \
  --key '{"LockID":{"S":"your-bucket/staging/terraform.tfstate"}}'
```

## クリーンアップ

```bash
# リソースの削除
terraform destroy

# 確認なしで削除 (注意)
terraform destroy -auto-approve
```

## セキュリティ

### Cognito

- **MFA**: 有効
- **パスワードポリシー**: 強力なパスワード要求
- **高度なセキュリティ**: AUDIT モード

### ネットワーク

- **VPC**: 独立したネットワーク空間 (10.1.0.0/16)
- **サブネット**: パブリック/プライベート分離
- **Security Groups**: 最小権限

### シークレット管理

ステージング環境のシークレットは AWS Systems Manager Parameter Store で管理:

```bash
# シークレットの確認
aws ssm get-parameter \
  --name /nextjs-ecs/staging/cognito/client_secret \
  --with-decryption
```

## 本番環境への昇格

ステージング環境で十分にテストした後、本番環境にデプロイ:

```bash
# 1. ステージング環境で動作確認
cd infrastructure/terraform/environments/staging
terraform output

# 2. 本番環境の設定を確認
cd ../prod
cat terraform.tfvars

# 3. 本番環境にデプロイ
terraform init
terraform plan
terraform apply
```

## 関連ドキュメント

- [../../README.md](../../README.md) - ルートモジュールのドキュメント
- [../../../../docs/PRODUCTION_READY.md](../../../../docs/PRODUCTION_READY.md) - プロダクション運用ガイド
- [../../../../docs/TERRAFORM_TEST_REPORT.md](../../../../docs/TERRAFORM_TEST_REPORT.md) - テストレポート

## 変更履歴

ステージング環境への変更は記録してください：

```bash
# Git commit メッセージに詳細を記載
git commit -m "staging: Update ECS task count from 1 to 2

- Reason: Load testing
- Tested: Stress test passed
- Rollback plan: Revert this commit"
```
