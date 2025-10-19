# Production-Ready Infrastructure Guide

本プロジェクトは、プロダクション環境で使用可能な堅牢で安全なインフラストラクチャを提供します。

## 📋 目次

- [実装済み機能](#実装済み機能)
- [セキュリティ](#セキュリティ)
- [認証・認可](#認証認可)
- [監視とアラート](#監視とアラート)
- [スケーリング](#スケーリング)
- [デプロイメント](#デプロイメント)
- [設定管理](#設定管理)
- [バックアップと復旧](#バックアップと復旧)
- [コンプライアンス](#コンプライアンス)

## ✅ 実装済み機能

### インフラストラクチャ

- ✅ **Multi-AZ構成**: 3つのAvailability Zoneにまたがる高可用性
- ✅ **Auto Scaling**: ECS Capacity Providerによる自動スケーリング
- ✅ **Load Balancing**: Application Load Balancerによる負荷分散
- ✅ **CDN**: CloudFrontによるコンテンツ配信
- ✅ **WAF**: Web Application Firewallによる保護
- ✅ **暗号化**: 転送時および保管時のデータ暗号化

### セキュリティ

- ✅ **認証・認可**: AWS Cognito統合
- ✅ **MFA**: 多要素認証サポート
- ✅ **セキュリティグループ**: 最小権限の原則に基づく設定
- ✅ **IAM**: きめ細かなアクセス制御
- ✅ **Secrets Management**: SSM Parameter StoreとKMS暗号化
- ✅ **セキュリティスキャン**: ECRイメージスキャン有効化

### 監視

- ✅ **メトリクス**: CloudWatch Container Insights
- ✅ **ログ**: 集約されたアプリケーションログ
- ✅ **アラート**: SNSによる通知
- ✅ **ダッシュボード**: カスタムCloudWatchダッシュボード
- ✅ **トレーシング**: AWS X-Ray統合（オプション）
- ✅ **合成モニタリング**: CloudWatch Synthetics Canary（オプション）

### 運用

- ✅ **Infrastructure as Code**: Terraformで完全管理
- ✅ **デプロイ自動化**: ecspressoによるECSデプロイ
- ✅ **バージョン管理**: ECRライフサイクルポリシー
- ✅ **ロールバック**: Blue/Greenデプロイメント対応

## 🔐 セキュリティ

### AWS Cognito認証

#### ユーザープール設定

- **パスワードポリシー**:
  - 最小12文字
  - 大文字、小文字、数字、記号を含む
  - 一時パスワードの有効期限: 7日

- **MFA（多要素認証）**:
  - 本番環境: 必須
  - 開発環境: オプション
  - TOTP（Time-based One-Time Password）サポート

- **高度なセキュリティ**:
  - 本番環境: ENFORCED（強制）
  - 開発環境: AUDIT（監査モード）
  - アダプティブ認証による不正アクセス検知

#### ユーザーグループ（RBAC）

```hcl
- admin: 管理者グループ（優先度: 1）
- user: 標準ユーザーグループ（優先度: 10）
```

#### 認証フロー

1. **フロントエンド認証**:
   - OAuth 2.0 / OpenID Connect
   - Authorization Code FlowとImplicit Flow対応
   - PKCEサポート

2. **バックエンドAPI認証**:
   - Client CredentialsとClient Secret
   - Machine-to-Machine認証

### セキュリティグループ

#### ALBセキュリティグループ
```
Inbound:
  - HTTP (80): 0.0.0.0/0
  - HTTPS (443): 0.0.0.0/0

Outbound:
  - All traffic to ECS instances
```

#### ECSインスタンスセキュリティグループ
```
Inbound:
  - Dynamic ports (32768-65535): From ALB

Outbound:
  - HTTPS (443): AWS Services
  - HTTP (80): Package updates
  - DNS (53): Name resolution
  - NTP (123): Time synchronization
```

### データ暗号化

- **転送時**: TLS 1.3（ELBSecurityPolicy-TLS13-1-2-2021-06）
- **保管時**:
  - S3: AES-256
  - EBS: AES-256
  - ECR: AES-256
  - SSM Parameter Store: KMS
  - CloudWatch Logs: KMS（オプション）

## 🔑 認証・認可

### Cognitoの使用方法

#### 1. 初期設定

Terraformでインフラをデプロイ後、Cognitoの設定値を確認:

```bash
cd infrastructure/terraform
terraform output cognito_user_pool_id
terraform output cognito_frontend_client_id
terraform output cognito_user_pool_domain
```

#### 2. フロントエンドでの実装

```typescript
// Next.js アプリケーション例
import { Amplify } from 'aws-amplify';

Amplify.configure({
  Auth: {
    region: 'ap-northeast-1',
    userPoolId: process.env.NEXT_PUBLIC_COGNITO_USER_POOL_ID,
    userPoolWebClientId: process.env.NEXT_PUBLIC_COGNITO_CLIENT_ID,
    oauth: {
      domain: process.env.NEXT_PUBLIC_COGNITO_DOMAIN,
      scope: ['email', 'openid', 'profile'],
      redirectSignIn: 'http://localhost:3000/auth/callback',
      redirectSignOut: 'http://localhost:3000',
      responseType: 'code',
    }
  }
});
```

#### 3. バックエンドでのトークン検証

```typescript
import { CognitoJwtVerifier } from 'aws-jwt-verify';

const verifier = CognitoJwtVerifier.create({
  userPoolId: process.env.COGNITO_USER_POOL_ID!,
  tokenUse: 'access',
  clientId: process.env.COGNITO_CLIENT_ID!,
});

// ミドルウェアでトークン検証
async function verifyToken(token: string) {
  try {
    const payload = await verifier.verify(token);
    return payload;
  } catch (error) {
    throw new Error('Token verification failed');
  }
}
```

#### 4. ユーザー管理

```bash
# 管理者ユーザーの作成
aws cognito-idp admin-create-user \
  --user-pool-id <USER_POOL_ID> \
  --username admin@example.com \
  --user-attributes Name=email,Value=admin@example.com Name=email_verified,Value=true

# ユーザーをグループに追加
aws cognito-idp admin-add-user-to-group \
  --user-pool-id <USER_POOL_ID> \
  --username admin@example.com \
  --group-name admin
```

## 📊 監視とアラート

### CloudWatchアラーム

#### ECSサービス

| アラーム | 条件 | 閾値（本番） | 閾値（開発） | 重要度 |
|---------|------|------------|-------------|--------|
| CPU使用率高 | 平均 > 閾値（5分間x2回） | 80% | 90% | Warning |
| メモリ使用率高 | 平均 > 閾値（5分間x2回） | 80% | 90% | Warning |
| タスク数低 | 平均 < 閾値（1分間x2回） | 2 | 1 | Critical |

#### ALB

| アラーム | 条件 | 閾値（本番） | 閾値（開発） | 重要度 |
|---------|------|------------|-------------|--------|
| 異常ターゲット | 平均 > 0（1分間x2回） | 0 | 0 | Critical |
| 5xxエラー | 合計 > 閾値（5分間x2回） | 10 | 50 | High |
| レスポンスタイム | 平均 > 閾値（5分間x2回） | 1.0s | 2.0s | Warning |

#### RDS（オプション）

| アラーム | 条件 | 閾値（本番） | 閾値（開発） | 重要度 |
|---------|------|------------|-------------|--------|
| CPU使用率高 | 平均 > 閾値（5分間x2回） | 80% | 90% | Warning |
| ストレージ残量低 | 平均 < 閾値（5分間x1回） | 10GB | 10GB | Critical |
| 接続数高 | 平均 > 閾値（5分間x2回） | 80 | 50 | Warning |

### アラート通知設定

```bash
# SNSトピックにメールアドレスを追加
aws sns subscribe \
  --topic-arn arn:aws:sns:ap-northeast-1:ACCOUNT_ID:PROJECT-ENV-alerts \
  --protocol email \
  --notification-endpoint ops-team@example.com
```

### CloudWatch Dashboards

デフォルトで以下のダッシュボードが作成されます：

- **ECSメトリクス**: CPU、メモリ、タスク数
- **ALBメトリクス**: リクエスト数、レスポンスタイム、HTTPステータスコード
- **ターゲットヘルス**: 正常/異常なターゲット数

アクセス:
```
https://console.aws.amazon.com/cloudwatch/home?region=ap-northeast-1#dashboards:name=PROJECT-ENV
```

### ログクエリ

#### エラーログの検索

```
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 100
```

#### 遅いリクエストの検索

```
fields @timestamp, @message
| filter @message like /duration/
| parse @message /duration: (?<duration>\d+)/
| filter duration > 1000
| sort duration desc
| limit 100
```

## ⚡ スケーリング

### ECS Auto Scaling

#### Capacity Provider設定

```hcl
managed_scaling {
  maximum_scaling_step_size = 10000
  minimum_scaling_step_size = 1
  status                    = "ENABLED"
  target_capacity           = 100
  instance_warmup_period    = 300
}
```

#### Auto Scaling Group

```hcl
desired_capacity = 0  # Capacity Providerが管理
min_size        = 0
max_size        = 10
```

### スケーリング戦略

1. **水平スケーリング**: タスク数を増減
2. **垂直スケーリング**: インスタンスタイプの変更（手動）

### スケーリングイベントの監視

```bash
# ECSサービスイベント
aws ecs describe-services \
  --cluster PROJECT-cluster \
  --services PROJECT-SERVICE \
  --query 'services[0].events[0:10]'

# Auto Scalingアクティビティ
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name PROJECT-ecs-asg \
  --max-records 10
```

## 🚀 デプロイメント

### 初回デプロイ

```bash
# 1. バックエンドの設定
cd infrastructure/terraform
./scripts/setup-backend.sh dev AWS_ACCOUNT_ID

# 2. インフラのデプロイ
terraform init -backend-config=env/dev/backend.hcl
terraform plan
terraform apply

# 3. アプリケーションのデプロイ
cd ../../
./scripts/deploy.sh
```

### 更新デプロイ

```bash
# アプリケーションの更新
./scripts/deploy.sh

# インフラの更新
cd infrastructure/terraform
terraform plan
terraform apply
```

### ロールバック

```bash
# 前のバージョンにロールバック
cd infrastructure/terraform
terraform output ecr_repository_url

# 前のイメージタグを確認
aws ecr describe-images \
  --repository-name PROJECT-APP \
  --query 'imageDetails[*].[imageTags[0],imagePushedAt]' \
  --output table

# タスク定義を前のバージョンに戻す
cd ecspresso
ecspresso rollback --config config.yaml --count 1
```

## ⚙️ 設定管理

### SSM Parameter Store

すべての機密情報とアプリケーション設定はSSM Parameter Storeで管理されます。

#### パラメータ構造

```
/PROJECT/ENV/
  ├── app/
  │   ├── env
  │   └── log_level
  ├── cognito/
  │   ├── user_pool_id
  │   ├── client_id
  │   └── client_secret (SecureString)
  └── database/
      ├── host
      ├── port
      ├── name
      ├── username (SecureString)
      └── password (SecureString)
```

#### パラメータの取得

```bash
# 単一パラメータ
aws ssm get-parameter \
  --name /PROJECT/ENV/app/log_level \
  --query 'Parameter.Value' \
  --output text

# パス配下のすべてのパラメータ
aws ssm get-parameters-by-path \
  --path /PROJECT/ENV/ \
  --recursive \
  --with-decryption
```

#### アプリケーションからの利用

```typescript
import { SSMClient, GetParameterCommand } from '@aws-sdk/client-ssm';

const ssmClient = new SSMClient({ region: 'ap-northeast-1' });

async function getParameter(name: string): Promise<string> {
  const command = new GetParameterCommand({
    Name: name,
    WithDecryption: true,
  });

  const response = await ssmClient.send(command);
  return response.Parameter?.Value || '';
}

// 使用例
const dbPassword = await getParameter('/PROJECT/ENV/database/password');
```

#### ECSタスク定義での利用

```json
{
  "secrets": [
    {
      "name": "DB_PASSWORD",
      "valueFrom": "/PROJECT/ENV/database/password"
    },
    {
      "name": "COGNITO_CLIENT_SECRET",
      "valueFrom": "/PROJECT/ENV/cognito/client_secret"
    }
  ]
}
```

### 環境変数の管理

本番環境とステージング環境で異なる設定を使用:

```bash
# locals.tfで環境別に設定
locals {
  environment = "prod"  # or "staging", "dev"

  log_level = local.environment == "prod" ? "warn" : "debug"
  enable_mfa = local.environment == "prod"
  deletion_protection = local.environment == "prod"
}
```

## 💾 バックアップと復旧

### Terraform State

- **S3バケット**: バージョニング有効
- **DynamoDB**: Point-in-Time Recovery有効
- **保持期間**: 90日間

### ECRイメージ

- **タグ付きイメージ**: 最新10個を保持
- **タグなしイメージ**: 1日後に削除

### CloudWatch Logs

- **保持期間**:
  - 本番: 30日
  - 開発: 7日

### リストア手順

#### Terraform State

```bash
# 特定の時点のstateをリストア
aws s3api list-object-versions \
  --bucket terraform-state-BUCKET \
  --prefix PROJECT/ENV/terraform.tfstate

aws s3api get-object \
  --bucket terraform-state-BUCKET \
  --key PROJECT/ENV/terraform.tfstate \
  --version-id VERSION_ID \
  terraform.tfstate
```

#### アプリケーション

```bash
# 前のイメージバージョンを使用
ecspresso deploy \
  --config ecspresso/config.yaml \
  --latest-task-definition \
  --update-service \
  --force-new-deployment
```

## 📜 コンプライアンス

### セキュリティベストプラクティス

- ✅ **最小権限の原則**: IAMロールとポリシー
- ✅ **暗号化**: 転送時と保管時
- ✅ **監査ログ**: CloudTrail（推奨）
- ✅ **パッチ管理**: 自動AMI更新
- ✅ **脆弱性スキャン**: ECRイメージスキャン

### AWSベストプラクティス

- ✅ **Well-Architected Framework**準拠
  - 運用性
  - セキュリティ
  - 信頼性
  - パフォーマンス効率
  - コスト最適化

### 定期的なレビュー

推奨される定期レビュー項目:

- [ ] IAMロールとポリシーの棚卸し（四半期ごと）
- [ ] セキュリティグループルールの確認（四半期ごと）
- [ ] CloudWatchアラームの調整（月次）
- [ ] コスト分析と最適化（月次）
- [ ] ECRイメージの脆弱性レポート確認（週次）

## 🔧 トラブルシューティング

### ECSタスクが起動しない

```bash
# タスクの停止理由を確認
aws ecs describe-tasks \
  --cluster PROJECT-cluster \
  --tasks TASK_ID \
  --query 'tasks[0].stoppedReason'

# コンテナログを確認
aws logs tail /ecs/PROJECT/APP --follow
```

### ALBヘルスチェック失敗

```bash
# ターゲットヘルスを確認
aws elbv2 describe-target-health \
  --target-group-arn TARGET_GROUP_ARN

# ヘルスチェックパスが正しく応答しているか確認
curl -v http://CONTAINER_IP:3000/api/health
```

### Cognito認証エラー

```bash
# ユーザープールクライアント設定を確認
aws cognito-idp describe-user-pool-client \
  --user-pool-id USER_POOL_ID \
  --client-id CLIENT_ID

# ユーザーステータスを確認
aws cognito-idp admin-get-user \
  --user-pool-id USER_POOL_ID \
  --username USERNAME
```

## 📚 参考資料

- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [AWS Cognito Developer Guide](https://docs.aws.amazon.com/cognito/latest/developerguide/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## 🤝 サポート

問題が発生した場合:

1. このドキュメントのトラブルシューティングセクションを確認
2. CloudWatchログとメトリクスを確認
3. チームの技術リードに相談

---

**更新日**: 2025-01-14
**バージョン**: 1.0.0
