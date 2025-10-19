# ECS Managed Instance with TypeScript Monorepo on AWS

AWS ECS Managed Instance上で動作するTypeScriptモノレポアプリケーションのエンタープライズ対応デプロイ環境です。

## ✨ 特徴

### 本番対応
- **マルチ環境管理**: dev/staging/prod 環境の完全分離
- **ステート管理**: S3バックエンド + DynamoDB ロック
- **セキュリティ**: Secrets Manager, KMS暗号化, GuardDuty
- **監視**: CloudWatch Alarms, Dashboard, X-Ray
- **コスト管理**: AWS Budgets, Cost Anomaly Detection
- **包括的テスト**: Vitest, Playwright, k6

### 技術スタック
- **Infrastructure**: Terraform (モジュール化)
- **Deployment**: ecspresso + GitHub Actions
- **Compute**: ECS Managed Instance (EC2)
- **Frontend**: Next.js 14 (App Router)
- **Backend**: TypeScript + Fastify
- **CDN**: CloudFront + WAF
- **CI/CD**: GitHub Actions with OIDC

## 🚀 クイックスタート

### Makefileを使用する場合（推奨）

```bash
# 1. 依存関係のインストール
make install

# 2. セットアップ（初回のみ）
make setup ENV=dev ACCOUNT_ID=<YOUR_AWS_ACCOUNT_ID>

# 3. インフラのデプロイ
make apply ENV=dev

# 4. アプリケーションのデプロイ
make deploy ENV=dev COMPONENT=all
```

### 手動でセットアップする場合

```bash
# 1. バックエンドのセットアップ
./scripts/setup-backend.sh dev <AWS_ACCOUNT_ID>

# 2. 開発環境のデプロイ
cd infrastructure/terraform/environments/dev
terraform init -backend-config=backend.hcl
terraform apply

# 3. アプリケーションのデプロイ
./scripts/deploy.sh dev all
```

詳細は以下のドキュメントを参照してください:
- **[クイックスタートガイド](docs/QUICK_START.md)**: 最速でセットアップする方法
- **[エンタープライズセットアップ](docs/ENTERPRISE_SETUP.md)**: 本番環境構築ガイド
- **[GitHub OIDC セットアップ](docs/GITHUB_OIDC_SETUP.md)**: CI/CD用の認証設定

## 🏗️ アーキテクチャ

詳細は [docs/architecture.md](docs/architecture.md) を参照してください。

## 📁 ディレクトリ構成

```
.
├── apps/
│   ├── frontend/              # Next.js (Vitest, Playwright)
│   └── backend/               # TypeScript API (Vitest)
├── tests/
│   └── load/                  # k6 Load Tests
├── infrastructure/
│   ├── terraform/
│   │   ├── environments/      # 環境別設定 (dev/staging/prod)
│   │   └── modules/          # 再利用可能モジュール
│   └── ecspresso/            # ECSデプロイ設定
├── scripts/
│   ├── setup-backend.sh      # Terraform Backend セットアップ
│   └── deploy.sh             # アプリケーションデプロイ
├── docs/                      # ドキュメント
├── .github/
│   └── workflows/            # GitHub Actions CI/CD
├── Makefile                   # タスクランナー
└── package.json              # モノレポ設定
```

## 📚 ドキュメント

### セットアップ
- **[クイックスタートガイド](docs/QUICK_START.md)**: 最速でセットアップする方法
- **[GitHub OIDC セットアップ](docs/GITHUB_OIDC_SETUP.md)**: CI/CD用の認証設定
- **[エンタープライズセットアップ](docs/ENTERPRISE_SETUP.md)**: 本番環境構築ガイド

### 運用
- **[デプロイメントガイド](docs/DEPLOYMENT_GUIDE.md)**: デプロイ手順
- **[テストガイド](docs/TESTING_GUIDE.md)**: テスト戦略と実行方法

### アーキテクチャ・セキュリティ
- **[アーキテクチャ](docs/architecture.md)**: システム構成の詳細
- **[セキュリティポリシー](docs/SECURITY_POLICY.md)**: セキュリティ要件

## 💰 コスト見積もり (東京リージョン)

| 環境 | 構成 | 月額 |
|------|------|------|
| Development | t3.small x1, シングルAZ | ~$50 |
| Staging | t3.medium x2, マルチAZ | ~$150 |
| Production | t3.large x3, マルチAZ, 完全冗長 | ~$300 |

## 🔐 セキュリティ

- **ネットワーク**: プライベートサブネット、VPC Endpoints、WAF
- **データ**: KMS暗号化 (S3, ECR, EBS, Secrets)
- **アクセス**: GitHub Actions OIDC、IAM最小権限
- **監視**: GuardDuty、CloudTrail、VPC Flow Logs

セキュリティ問題の報告: security@example.com

## 📊 監視

- CloudWatch Alarms (CPU/Memory/Health/Errors)
- CloudWatch Dashboard (リアルタイムメトリクス)
- AWS Budgets (コスト監視)
- Cost Anomaly Detection
- GuardDuty (脅威検出)

## 🧪 テスト

### Makefileを使用する場合（推奨）

```bash
make test              # すべてのテストを実行
make test-frontend     # フロントエンドのみ
make test-backend      # バックエンドのみ
make test-e2e          # E2Eテスト
make test-load         # 負荷テスト
```

### 手動で実行する場合

```bash
# ユニットテスト (Vitest)
cd apps/frontend && npm test      # カバレッジ80%目標
cd apps/backend && npm test

# E2Eテスト (Playwright)
cd apps/frontend && npm run test:e2e   # Chrome, Firefox, Safari

# 負荷テスト (k6)
cd tests/load
npm run test:health    # ヘルスチェック (10→100 users)
npm run test:stress    # ストレス (500 users)
npm run test:spike     # スパイク (急激に500 users)
```

詳細は [docs/TESTING_GUIDE.md](docs/TESTING_GUIDE.md) を参照してください。

## 🛠️ 運用

### デプロイフロー
- **dev**: mainブランチマージで自動
- **staging**: タグプッシュで自動
- **prod**: タグプッシュ + 手動承認

### ロールバック
```bash
cd infrastructure/ecspresso
ecspresso rollback --config config.yaml
```

詳細は [docs/DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md) を参照してください。

## 📝 ライセンス

MIT

## 📞 サポート

- 技術的な質問: GitHub Issues
- セキュリティ問題: security@example.com
- その他: platform-team@example.com
