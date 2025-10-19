# Next.js ECS Infrastructure

このディレクトリには、Next.jsアプリケーションをAWS ECS上で実行するためのTerraformインフラストラクチャコードが含まれています。

## 📁 ディレクトリ構造

```
infrastructure/terraform/
├── environments/          # 環境別設定
│   ├── dev/              # 開発環境
│   ├── staging/          # ステージング環境
│   └── prod/             # 本番環境
├── modules/              # 再利用可能なモジュール
│   ├── vpc/             # VPCとネットワーキング
│   ├── ecs/             # ECSクラスター
│   ├── alb/             # Application Load Balancer
│   ├── cognito/         # ユーザー認証
│   ├── ssm/             # Parameter Store (シークレット管理)
│   ├── cloudfront/      # CDN
│   ├── s3/              # 静的アセット
│   └── waf/             # Web Application Firewall
├── main.tf              # ルートモジュール
├── variables.tf         # 変数定義
├── outputs.tf           # 出力値
├── versions.tf          # プロバイダーバージョン
└── backend.tf           # バックエンド設定
```

## 🏗️ アーキテクチャ

このインフラストラクチャは以下のAWSサービスを使用します:

- **VPC**: マルチAZ構成のプライベートネットワーク
- **ECS Fargate/EC2**: コンテナオーケストレーション
- **Application Load Balancer**: トラフィック分散
- **CloudFront + S3**: 静的アセット配信
- **Cognito**: ユーザー認証・認可
- **WAF**: セキュリティ保護
- **CloudWatch**: ログ・メトリクス監視
- **SSM Parameter Store**: シークレット管理
- **ECR**: Dockerイメージレジストリ

## 🚀 クイックスタート

### 前提条件

- Terraform >= 1.10
- AWS CLI設定済み
- 適切なAWS権限

### 1. 開発環境のデプロイ

```bash
cd environments/dev
terraform init
terraform plan
terraform apply
```

### 2. ステージング環境のデプロイ

```bash
cd environments/staging

# terraform.tfvars を作成
cat > terraform.tfvars <<EOF
alert_email = "staging-alerts@example.com"
certificate_arn = "arn:aws:acm:ap-northeast-1:ACCOUNT_ID:certificate/CERT_ID"
EOF

terraform init
terraform plan
terraform apply
```

### 3. 本番環境のデプロイ

```bash
cd environments/prod

# terraform.tfvars を作成 (必須)
cat > terraform.tfvars <<EOF
alert_email = "prod-alerts@example.com"
certificate_arn = "arn:aws:acm:ap-northeast-1:ACCOUNT_ID:certificate/CERT_ID"
EOF

terraform init
terraform plan
terraform apply
```

## 🔧 環境別設定

### 開発環境 (dev)

- **用途**: ローカル開発・テスト
- **リソース**: 最小構成
- **ログ保持**: 7日
- **MFA**: 無効
- **削除保護**: 無効
- **コスト**: 最小

### ステージング環境 (staging)

- **用途**: 本番前の検証
- **リソース**: 中規模構成
- **ログ保持**: 14日
- **MFA**: 有効
- **削除保護**: 無効
- **コスト**: 中程度

### 本番環境 (prod)

- **用途**: 本番サービス
- **リソース**: 高可用性構成
- **ログ保持**: 30日
- **MFA**: 必須
- **削除保護**: 有効
- **コスト**: 高

## 📝 主要な変数

### 必須変数

| 変数名 | 説明 | dev | staging | prod |
|--------|------|-----|---------|------|
| `alert_email` | アラート通知先 | オプション | 推奨 | **必須** |
| `certificate_arn` | ACM証明書ARN | オプション | 推奨 | **必須** |

### 主要な設定変数

| 変数名 | デフォルト | 説明 |
|--------|-----------|------|
| `project_name` | `nextjs-ecs` | プロジェクト名 |
| `region` | `ap-northeast-1` | AWSリージョン |
| `vpc_cidr` | 環境依存 | VPC CIDR |
| `app_cpu` | `512` | アプリケーションCPU |
| `app_memory` | `1024` | アプリケーションメモリ(MB) |
| `app_desired_count` | 環境依存 | タスク数 |
| `enable_cognito` | `true` | Cognito有効化 |
| `enable_mfa` | 環境依存 | MFA有効化 |

詳細は各環境の`variables.tf`を参照してください。

## 🔐 セキュリティ

### 認証・認可

- **Cognito User Pool**: ユーザー認証
- **MFA**: 本番環境で必須
- **IAM Roles**: 最小権限の原則

### シークレット管理

- **SSM Parameter Store**: アプリケーション設定
- **KMS暗号化**: 保存時暗号化
- **動的参照**: ECSタスクからの安全なアクセス

### ネットワークセキュリティ

- **WAF**: SQLインジェクション、XSS保護
- **Security Groups**: 最小限のアクセス許可
- **Private Subnets**: アプリケーション層の隔離

## 📊 モニタリング

### CloudWatch

- **ログ**: ECSタスク、ALB、CloudFront
- **メトリクス**: CPU、メモリ、リクエスト数
- **アラーム**: 異常検知と通知

### X-Ray

- **分散トレーシング**: リクエストフロー可視化
- **パフォーマンス分析**: ボトルネック検出

### Canary監視 (prod)

- **合成監視**: 定期的なエンドポイントチェック
- **可用性確認**: ユーザー体験のシミュレーション

## 🗄️ バックエンド設定

### ローカルバックエンド (デフォルト)

開発・テスト用。stateファイルはローカルに保存されます。

### S3バックエンド (推奨: staging/prod)

1. バックエンド用のS3バケットとDynamoDBテーブルを作成:

```bash
cd ../../scripts
./setup-backend.sh prod YOUR_AWS_ACCOUNT_ID
```

2. `backend.tf`のコメントを解除

3. `backend.hcl`を作成:

```hcl
bucket         = "your-terraform-state-bucket"
key            = "prod/terraform.tfstate"
region         = "ap-northeast-1"
encrypt        = true
dynamodb_table = "terraform-state-lock"
```

4. 初期化:

```bash
terraform init -backend-config=backend.hcl
```

## 🔄 デプロイフロー

### 通常のデプロイ

```bash
# 1. 変更を確認
terraform plan

# 2. 変更を適用
terraform apply

# 3. 出力を確認
terraform output
```

### 安全なデプロイ (本番環境)

```bash
# 1. プランを保存
terraform plan -out=tfplan

# 2. プランを確認 (複数人でレビュー推奨)
terraform show tfplan

# 3. 承認後に適用
terraform apply tfplan

# 4. 動作確認
# - ALBヘルスチェック
# - CloudWatchメトリクス
# - アプリケーション動作
```

## 📤 出力値

デプロイ後、以下の情報が出力されます:

```bash
terraform output
```

### 主要な出力

- `alb_dns_name`: ALBのDNS名
- `cloudfront_domain_name`: CloudFrontのドメイン名
- `application_url`: アプリケーションURL
- `ecr_repository_url`: ECRリポジトリURL
- `cognito_user_pool_id`: Cognito User Pool ID
- `cognito_frontend_client_id`: フロントエンド用クライアントID

## 🛠️ トラブルシューティング

### Terraform初期化エラー

```bash
# .terraformディレクトリを削除して再初期化
rm -rf .terraform .terraform.lock.hcl
terraform init
```

### State ロックエラー

```bash
# ロックを強制解除 (注意: 他の操作が実行中でないことを確認)
terraform force-unlock LOCK_ID
```

### バリデーションエラー

```bash
# 設定の検証
terraform validate

# フォーマット
terraform fmt -recursive
```

## 🧹 クリーンアップ

### 開発環境の削除

```bash
cd environments/dev
terraform destroy
```

### 本番環境の削除

⚠️ **注意**: 本番環境では削除保護が有効です。

```bash
# 1. main.tfで削除保護を無効化
# enable_deletion_protection = false

# 2. 変更を適用
terraform apply

# 3. リソースを削除
terraform destroy
```

## 📚 関連ドキュメント

- [AWS Terraform Provider ベストプラクティス](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/)
- [Google Cloud Terraform ベストプラクティス](https://cloud.google.com/docs/terraform/best-practices)
- [Terraform Registry - AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## 🆘 サポート

### 環境別README

- [dev/README.md](environments/dev/README.md)
- [staging/README.md](environments/staging/README.md)
- [prod/README.md](environments/prod/README.md)

### プロダクション運用ガイド

- [docs/PRODUCTION_READY.md](../../docs/PRODUCTION_READY.md)
- [docs/TERRAFORM_TEST_REPORT.md](../../docs/TERRAFORM_TEST_REPORT.md)

## 📄 ライセンス

プロジェクトのライセンスに従います。

---

**最終更新**: 2025-10-15
**Terraform バージョン**: >= 1.10
**AWS Provider バージョン**: ~> 6.16
