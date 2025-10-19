# エンタープライズセットアップガイド

このドキュメントでは、会社の本番環境で使用するためのエンタープライズレベルのセットアップ手順を説明します。

## 📋 目次

1. [前提条件](#前提条件)
2. [アーキテクチャ概要](#アーキテクチャ概要)
3. [初回セットアップ](#初回セットアップ)
4. [環境構築](#環境構築)
5. [セキュリティ設定](#セキュリティ設定)
6. [監視とアラート](#監視とアラート)
7. [コスト管理](#コスト管理)
8. [運用ガイドライン](#運用ガイドライン)

## 前提条件

### 必要な権限

- AWS アカウント管理者権限
- GitHub リポジトリの管理者権限
- 以下のAWSサービスへのアクセス権限:
  - IAM (OIDC Provider、Role作成)
  - S3 (Terraformステート用バケット)
  - DynamoDB (Terraformロック用テーブル)
  - KMS (暗号化キー管理)

### 必要なツール

```bash
# Terraform
terraform --version  # >= 1.6

# AWS CLI
aws --version  # >= 2.0

# ecspresso
ecspresso version  # >= 2.6

# Docker
docker --version  # >= 24.0

# Node.js
node --version  # >= 20
```

## アーキテクチャ概要

### 環境分離戦略

プロジェクトは以下の3つの環境に分離されています:

1. **Development (dev)**: 開発者の日常的な開発・テスト用
2. **Staging (staging)**: リリース前の統合テスト・QA用
3. **Production (prod)**: 本番環境

各環境は以下で完全に分離されています:
- 独立したAWSアカウント (推奨) または VPC
- 独立したTerraformステートファイル
- 環境別のCI/CDパイプライン

### ディレクトリ構造

```
infrastructure/terraform/
├── modules/              # 再利用可能なTerraformモジュール
│   ├── vpc/             # VPC、サブネット、NAT Gateway
│   ├── ecs/             # ECSクラスター、タスク定義
│   ├── alb/             # Application Load Balancer
│   ├── cloudfront/      # CloudFront CDN
│   ├── waf/             # Web Application Firewall
│   ├── s3/              # S3静的アセット
│   ├── monitoring/      # CloudWatch監視、アラート
│   ├── secrets/         # Secrets Manager
│   └── cost-management/ # AWS Budgets、コスト監視
├── env/                 # 環境別設定
│   ├── dev/            # 開発環境
│   ├── staging/        # ステージング環境
│   └── prod/           # 本番環境
├── main.tf             # メイン設定
├── locals.tf           # 環境別変数マップ
├── variables.tf        # 変数定義
└── outputs.tf          # 出力定義
```

## 初回セットアップ

### 1. Terraformバックエンドの構築

各環境ごとにS3バケットとDynamoDBテーブルを作成します:

```bash
# 開発環境
./scripts/setup-backend.sh dev <AWS_ACCOUNT_ID>

# ステージング環境
./scripts/setup-backend.sh staging <AWS_ACCOUNT_ID>

# 本番環境
./scripts/setup-backend.sh prod <AWS_ACCOUNT_ID>
```

このスクリプトは以下を作成します:
- S3バケット (Terraformステート保存用)
- DynamoDBテーブル (ステートロック用)
- KMSキー (ステート暗号化用)

### 2. GitHub Actions OIDC設定

キーレス認証のためにGitHub ActionsとAWSの信頼関係を構築します:

#### IAM OIDC Providerの作成

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

#### IAM Roleの作成

```bash
# IAM Role信頼ポリシー
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:<GITHUB_ORG>/<GITHUB_REPO>:*"
        }
      }
    }
  ]
}
EOF

# Roleの作成
aws iam create-role \
  --role-name github-actions-oidc-role-dev \
  --assume-role-policy-document file://trust-policy.json

# ポリシーのアタッチ
aws iam attach-role-policy \
  --role-name github-actions-oidc-role-dev \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

#### GitHub Secretsの設定

各環境ごとにSecretsを設定:

```
AWS_ROLE_ARN_DEV: arn:aws:iam::<ACCOUNT_ID>:role/github-actions-oidc-role-dev
AWS_ROLE_ARN_STAGING: arn:aws:iam::<ACCOUNT_ID>:role/github-actions-oidc-role-staging
AWS_ROLE_ARN_PROD: arn:aws:iam::<ACCOUNT_ID>:role/github-actions-oidc-role-prod
```

## 環境構築

### 開発環境のデプロイ

```bash
cd infrastructure/terraform/environments/dev

# Terraformの初期化
terraform init -backend-config=backend.hcl

# プラン確認
terraform plan

# 適用
terraform apply

# 出力確認
terraform output
```

### ステージング/本番環境のデプロイ

```bash
cd infrastructure/terraform/environments/staging  # または prod

# 必要な変数を設定
export TF_VAR_certificate_arn="arn:aws:acm:..."
export TF_VAR_alert_email="ops@example.com"

# Terraformの初期化と適用
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

## セキュリティ設定

### 1. AWS Secrets Managerの設定

機密情報は必ずSecrets Managerで管理します:

```bash
# データベース認証情報の設定
aws secretsmanager put-secret-value \
  --secret-id nextjs-ecs-prod-db-credentials \
  --secret-string '{
    "username": "admin",
    "password": "<STRONG_PASSWORD>",
    "host": "db.example.com",
    "port": 5432,
    "database": "appdb"
  }'

# API Keysの設定
aws secretsmanager put-secret-value \
  --secret-id nextjs-ecs-prod-api-keys \
  --secret-string '{
    "stripe_api_key": "sk_live_...",
    "sendgrid_api_key": "SG..."
  }'

# アプリケーション環境変数
aws secretsmanager put-secret-value \
  --secret-id nextjs-ecs-prod-app-env \
  --secret-string '{
    "NODE_ENV": "production",
    "API_URL": "https://api.example.com"
  }'
```

### 2. HTTPS証明書の設定

**本番環境ではHTTPSが必須です:**

```bash
# ACM証明書のリクエスト
aws acm request-certificate \
  --domain-name example.com \
  --subject-alternative-names "*.example.com" \
  --validation-method DNS \
  --region ap-northeast-1

# 証明書ARNを環境変数に設定
export TF_VAR_certificate_arn="arn:aws:acm:ap-northeast-1:..."
```

### 3. WAFルールの最適化

本番環境では以下のWAFルールが自動的に有効化されます:
- AWS Managed Rules - Core Rule Set
- AWS Managed Rules - Known Bad Inputs
- Rate Limiting (2000 req/5分)

カスタムルールの追加:

```hcl
# infrastructure/terraform/modules/waf/main.tf
resource "aws_wafv2_web_acl_association" "custom_rule" {
  # カスタムIPブロックリストなど
}
```

### 4. IAMロールの最小権限原則

各コンポーネントには最小限の権限のみを付与:

- **ECS Task Execution Role**: ECRからのイメージプル、CloudWatch Logsへの書き込み
- **ECS Task Role**: アプリケーションが必要とするAWSサービスへのアクセス
- **ECS Instance Role**: ECSエージェントの動作、SSM Session Manager

## 監視とアラート

### CloudWatchアラーム

自動的に設定されるアラーム:

#### ECS Service
- CPU使用率が80%超 (本番) / 90%超 (開発)
- メモリ使用率が80%超 (本番) / 90%超 (開発)
- Running Task数が期待値を下回る

#### ALB
- Unhealthy Target検出
- 5xxエラー発生 (10件/5分超)
- レスポンスタイム1秒超 (本番)

### CloudWatch Dashboard

各環境ごとに自動生成されるダッシュボード:
- ECS CPU/Memory使用率
- ECS Task数 (Running/Desired)
- ALB レスポンスタイム/リクエスト数
- ALB HTTPステータスコード分布
- ALB Target Health

アクセス方法:
```bash
# ダッシュボードURL取得
cd infrastructure/terraform/environments/prod
terraform output dashboard_url
```

### ログ監視

CloudWatch Logs Insightsで事前定義されたクエリ:

1. **エラーログ検索**
```sql
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 100
```

2. **スローリクエスト検索**
```sql
fields @timestamp, @message
| filter @message like /duration/
| parse @message /duration: (?<duration>\d+)/
| filter duration > 1000
| sort duration desc
| limit 100
```

## コスト管理

### AWS Budgetsの設定

環境ごとに月次予算を自動設定:

- **開発環境**: $300/月
- **ステージング**: $500/月
- **本番環境**: $2000/月

アラート閾値:
- 80%到達時: メール通知
- 100%到達時: 緊急メール通知
- 90%予測時: 予測通知

### コスト異常検知

AWS Cost Anomaly Detectionが有効化されており、通常のパターンから逸脱したコスト増加を自動検出します。

### コスト最適化のベストプラクティス

1. **不要なリソースの削除**
   ```bash
   # 開発環境を夜間/週末に停止
   aws ecs update-service \
     --cluster nextjs-ecs-cluster-dev \
     --service nextjs-app-service \
     --desired-count 0
   ```

2. **Auto Scalingの活用**
   - 本番環境では自動スケーリングが有効
   - CPU/メモリ使用率に基づいて自動調整

3. **CloudFrontキャッシュの最適化**
   - 静的アセットのキャッシュTTLを適切に設定
   - Origin通信量を削減

4. **VPC Endpointsの活用**
   - NAT Gateway通信量を削減
   - ECR、S3、CloudWatch Logsへのプライベート接続

## 運用ガイドライン

### デプロイフロー

#### 開発環境
```bash
# 自動デプロイ (mainブランチマージ時)
git checkout main
git pull origin main
# GitHub Actionsが自動的に dev 環境にデプロイ
```

#### ステージング環境
```bash
# タグベースデプロイ
git tag -a v1.0.0-staging -m "Release v1.0.0 to staging"
git push origin v1.0.0-staging
# GitHub Actionsが自動的に staging 環境にデプロイ
```

#### 本番環境
```bash
# 承認フロー付きデプロイ
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
# GitHub Actionsで承認待ち → 承認後にデプロイ
```

### ロールバック手順

```bash
# 前のバージョンにロールバック
cd infrastructure/ecspresso
ecspresso rollback --config config.yaml --rollback-events 1

# または特定のイメージタグにロールバック
ecspresso deploy --config config.yaml \
  --tasks-override '[{"image":"<ECR_URL>:v1.0.0"}]'
```

### トラブルシューティング

#### サービスが起動しない

```bash
# ログ確認
aws logs tail /ecs/nextjs-ecs/nextjs-app --follow

# タスク状態確認
aws ecs describe-tasks \
  --cluster nextjs-ecs-cluster-prod \
  --tasks $(aws ecs list-tasks \
    --cluster nextjs-ecs-cluster-prod \
    --service-name nextjs-app-service \
    --query 'taskArns[0]' --output text)
```

#### パフォーマンス問題

```bash
# CloudWatch Container Insightsで確認
# CPU/Memory使用率、ネットワークメトリクスを分析

# X-Rayトレースで遅いAPIを特定 (本番環境で有効)
```

### 定期メンテナンス

#### 月次タスク
- [ ] コストレポートの確認
- [ ] セキュリティアラートの確認
- [ ] 未使用リソースのクリーンアップ
- [ ] ECRイメージのクリーンアップ (Lifecycle Policyで自動)

#### 四半期タスク
- [ ] AMIの更新 (ECS-optimized AMI)
- [ ] Terraformバージョンアップ
- [ ] 依存パッケージのアップデート

## 参考資料

### 社内ドキュメント
- [セキュリティポリシー](./SECURITY_POLICY.md)
- [インシデント対応手順](./INCIDENT_RESPONSE.md)
- [災害復旧計画](./DISASTER_RECOVERY.md)

### 外部リンク
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
