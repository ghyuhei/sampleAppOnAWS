# Development Environment

このディレクトリには開発環境の Terraform 設定が含まれています。

## 使用方法

### 初回セットアップ

```bash
cd infrastructure/terraform/environments/dev

# 初期化
terraform init

# プランの確認
terraform plan

# デプロイ
terraform apply
```

### S3 バックエンドを使用する場合

```bash
# 1. バックエンドのセットアップ
cd ../../../scripts
./setup-backend.sh dev YOUR_AWS_ACCOUNT_ID

# 2. backend.tf のコメントを解除

# 3. バックエンド設定で初期化
cd ../infrastructure/terraform/environments/dev
terraform init -backend-config=../../env/dev/backend.hcl
```

## 環境固有の設定

開発環境では以下の設定が適用されます：

- **ログ保持期間**: 7日
- **ECS インスタンスタイプ**: t3.medium
- **アプリケーション desired count**: 1
- **削除保護**: 無効
- **MFA**: 無効
- **コストセンター**: engineering

## 環境変数のカスタマイズ

`variables.tf` の値を上書きする場合：

### 方法1: terraform.tfvars ファイル（推奨）

```hcl
# terraform.tfvars (git ignore済み)
project_name = "my-project"
alert_email  = "dev-team@example.com"
```

### 方法2: コマンドラインで指定

```bash
terraform apply -var="alert_email=dev@example.com"
```

### 方法3: 環境変数

```bash
export TF_VAR_alert_email="dev@example.com"
terraform apply
```

## 出力値の確認

```bash
# すべての出力値を表示
terraform output

# 特定の出力値を表示
terraform output alb_dns_name
terraform output cognito_user_pool_id
```

## クリーンアップ

```bash
# リソースの削除
terraform destroy

# 確認なしで削除（注意）
terraform destroy -auto-approve
```

## トラブルシューティング

### State のロックエラー

```bash
# ロックを強制解除（注意して使用）
terraform force-unlock LOCK_ID
```

### 初期化のやり直し

```bash
# .terraform ディレクトリを削除して再初期化
rm -rf .terraform .terraform.lock.hcl
terraform init
```

## 関連ドキュメント

- [../../README.md](../../README.md) - ルートモジュールのドキュメント
- [../../../../docs/PRODUCTION_READY.md](../../../../docs/PRODUCTION_READY.md) - プロダクション運用ガイド
- [../../../../docs/TERRAFORM_TEST_REPORT.md](../../../../docs/TERRAFORM_TEST_REPORT.md) - テストレポート
