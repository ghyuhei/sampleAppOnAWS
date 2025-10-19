# Production Environment

このディレクトリには本番環境の Terraform 設定が含まれています。

⚠️ **本番環境です。操作には十分注意してください。**

## 使用方法

### 初回セットアップ

```bash
cd infrastructure/terraform/environments/prod

# 必須: S3 バックエンドの設定
# 1. バックエンド用のS3バケットとDynamoDBテーブルを作成
cd ../../../scripts
./setup-backend.sh prod YOUR_AWS_ACCOUNT_ID

# 2. backend.hcl ファイルを確認・編集
# env/prod/backend.hcl

# 3. terraform.tfvars を作成（必須変数を設定）
cd ../infrastructure/terraform/environments/prod
cat > terraform.tfvars <<EOF
alert_email     = "prod-alerts@example.com"
certificate_arn = "arn:aws:acm:ap-northeast-1:ACCOUNT_ID:certificate/CERT_ID"
EOF

# 4. 初期化（S3バックエンド使用）
terraform init -backend-config=../../env/prod/backend.hcl

# 5. プランの確認
terraform plan

# 6. デプロイ（承認が必要）
terraform apply
```

### 必須変数

本番環境では以下の変数が**必須**です：

- `alert_email`: アラート通知先メールアドレス（有効なメールアドレス形式）
- `certificate_arn`: ACM証明書ARN（HTTPS用）

## 環境固有の設定

本番環境では以下の設定が適用されます：

- **VPC CIDR**: 10.2.0.0/16
- **ログ保持期間**: 30日
- **ECS インスタンスタイプ**: t3.large
- **アプリケーション CPU/Memory**: 1024/2048
- **アプリケーション desired count**: 3（高可用性）
- **削除保護**: **有効**
- **MFA**: **必須**
- **ECR イメージタグ**: IMMUTABLE（本番環境では不変）
- **CloudFront**: PriceClass_All（全リージョン）
- **Canary監視**: 有効
- **コストセンター**: production

## 運用上の注意事項

### デプロイ前の確認事項

1. **terraform plan を必ず実行**
   ```bash
   terraform plan -out=tfplan
   # プランの内容を十分に確認
   terraform apply tfplan
   ```

2. **変更の影響範囲を確認**
   - ダウンタイムが発生する可能性のある変更
   - データ削除につながる変更
   - セキュリティに影響する変更

3. **ロールバック計画の準備**
   - 以前の状態に戻す手順を確認
   - terraform state のバックアップを確認

### 削除保護

本番環境では削除保護が有効になっています。リソースを削除する場合：

```bash
# 削除保護を一時的に無効化（main.tf を編集）
# enable_deletion_protection = false

terraform apply

# その後、削除を実行
terraform destroy
```

### State 管理

本番環境のstateは**必ずS3バックエンド**を使用してください。

```bash
# State の確認
terraform state list

# State のバックアップ
aws s3 cp s3://YOUR_BUCKET/prod/terraform.tfstate ./backup-$(date +%Y%m%d-%H%M%S).tfstate
```

## 環境変数のカスタマイズ

### terraform.tfvars（推奨）

```hcl
# terraform.tfvars (gitignore済み)
project_name    = "my-project"
alert_email     = "prod-alerts@example.com"
certificate_arn = "arn:aws:acm:ap-northeast-1:123456789012:certificate/xxx"
```

### 環境変数

```bash
export TF_VAR_alert_email="prod-alerts@example.com"
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

## モニタリング

デプロイ後は以下を確認してください：

1. **CloudWatch ダッシュボード**
   - コンソール: CloudWatch > Dashboards > nextjs-ecs-prod

2. **アラーム状態**
   ```bash
   aws cloudwatch describe-alarms --state-value ALARM
   ```

3. **ECS サービスの状態**
   ```bash
   aws ecs describe-services --cluster nextjs-ecs-prod --services nextjs-app
   ```

4. **ALB ヘルスチェック**
   ```bash
   aws elbv2 describe-target-health --target-group-arn $(terraform output -raw target_group_arn)
   ```

## 緊急時の対応

### サービスの即時停止

```bash
# ECS サービスのタスク数を0に
aws ecs update-service --cluster nextjs-ecs-prod --service nextjs-app --desired-count 0
```

### ロールバック

```bash
# 以前のStateから復元
terraform state pull > current.tfstate  # バックアップ
# 以前のcommitにチェックアウトして
terraform apply
```

### ALB のトラフィック遮断

```bash
# セキュリティグループのインバウンドルールを一時削除
# ※ Terraformで管理されているため、直接AWSコンソールで操作は避ける
```

## トラブルシューティング

### State のロックエラー

```bash
# ロックIDを確認
terraform force-unlock LOCK_ID

# DynamoDBで確認
aws dynamodb get-item --table-name terraform-state-lock \
  --key '{"LockID":{"S":"your-bucket/prod/terraform.tfstate"}}'
```

### 証明書の検証エラー

```bash
# ACM証明書の状態を確認
aws acm describe-certificate --certificate-arn $(terraform output -raw certificate_arn)
```

### ECS タスクの起動エラー

```bash
# ECS タスクのログを確認
aws logs tail /ecs/nextjs-ecs-prod/nextjs-app --follow
```

## セキュリティ

### シークレット管理

本番環境のシークレットはすべて AWS Systems Manager Parameter Store で管理されています：

```bash
# シークレットの確認
aws ssm get-parameter --name /nextjs-ecs/prod/cognito/client_secret --with-decryption
```

### IAM ロールの確認

```bash
# ECS タスクロールの確認
aws iam get-role --role-name nextjs-ecs-prod-task-role
```

## 関連ドキュメント

- [../../README.md](../../README.md) - ルートモジュールのドキュメント
- [../../../../docs/PRODUCTION_READY.md](../../../../docs/PRODUCTION_READY.md) - プロダクション運用ガイド
- [../../../../docs/TERRAFORM_TEST_REPORT.md](../../../../docs/TERRAFORM_TEST_REPORT.md) - テストレポート

## 変更履歴

本番環境への変更は必ず記録してください：

```bash
# Git commit メッセージに詳細を記載
git commit -m "prod: Update ECS task count from 2 to 3

- Reason: Increased traffic
- Tested in: staging
- Rollback plan: Revert this commit and apply"
```
