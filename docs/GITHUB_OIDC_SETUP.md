# GitHub Actions OIDC セットアップガイド

このガイドでは、GitHub ActionsからAWSリソースに安全にアクセスするためのOIDC（OpenID Connect）認証の設定方法を説明します。

## なぜOIDCを使うのか

従来のアクセスキー方式と比較したOIDCのメリット:

- **セキュリティ向上**: 長期的なクレデンシャルをGitHubに保存する必要がない
- **自動ローテーション**: トークンは短期間で自動的に失効する
- **細かい権限制御**: リポジトリやブランチ単位で権限を制御できる
- **監査の容易さ**: CloudTrailで誰が何をしたか追跡しやすい

## 前提条件

- AWSアカウントの管理者権限
- GitHubリポジトリへの管理者アクセス
- AWS CLIがインストールされていること

## ステップ1: AWS IAM Identity Provider の作成

### 1.1 AWS Management Consoleから作成

1. AWS Management Consoleにログイン
2. IAM → Identity providers → Add provider
3. 以下の情報を入力:

```
Provider type: OpenID Connect
Provider URL: https://token.actions.githubusercontent.com
Audience: sts.amazonaws.com
```

4. "Get thumbprint" をクリック
5. "Add provider" をクリック

### 1.2 AWS CLIから作成

```bash
aws iam create-open-id-connect-provider \
  --url "https://token.actions.githubusercontent.com" \
  --client-id-list "sts.amazonaws.com" \
  --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1"
```

## ステップ2: IAM ロールの作成

### 2.1 信頼ポリシーの作成

`github-actions-trust-policy.json` ファイルを作成:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_AWS_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_ORG/YOUR_REPO_NAME:*"
        }
      }
    }
  ]
}
```

**重要**: 以下を実際の値に置き換えてください:
- `YOUR_AWS_ACCOUNT_ID`: あなたのAWSアカウントID
- `YOUR_GITHUB_ORG`: あなたのGitHub組織名またはユーザー名
- `YOUR_REPO_NAME`: リポジトリ名

### 2.2 より厳格な信頼ポリシー（推奨）

特定のブランチのみを許可する場合:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_AWS_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_ORG/YOUR_REPO_NAME:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

### 2.3 IAM ロールの作成

```bash
# ロールを作成
aws iam create-role \
  --role-name GitHubActionsRole \
  --assume-role-policy-document file://github-actions-trust-policy.json

# ARNを確認
aws iam get-role --role-name GitHubActionsRole --query 'Role.Arn' --output text
```

出力例:
```
arn:aws:iam::123456789012:role/GitHubActionsRole
```

## ステップ3: IAM ポリシーの作成とアタッチ

### 3.1 必要な権限の洗い出し

このプロジェクトで必要な権限:
- ECRへのプッシュ
- ECSサービスのデプロイ
- S3への静的ファイルアップロード
- CloudFrontのキャッシュ無効化
- Terraformの実行

### 3.2 ポリシードキュメントの作成

`github-actions-policy.json` ファイルを作成:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRPermissions",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ECSPermissions",
      "Effect": "Allow",
      "Action": [
        "ecs:UpdateService",
        "ecs:DescribeServices",
        "ecs:DescribeTasks",
        "ecs:DescribeTaskDefinition",
        "ecs:RegisterTaskDefinition",
        "ecs:DeregisterTaskDefinition",
        "ecs:ListTasks"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAMPassRole",
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": [
        "arn:aws:iam::*:role/ecsTaskExecutionRole",
        "arn:aws:iam::*:role/ecsTaskRole"
      ]
    },
    {
      "Sid": "S3Permissions",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::your-static-assets-bucket/*",
        "arn:aws:s3:::your-static-assets-bucket"
      ]
    },
    {
      "Sid": "CloudFrontPermissions",
      "Effect": "Allow",
      "Action": [
        "cloudfront:CreateInvalidation",
        "cloudfront:GetInvalidation"
      ],
      "Resource": "*"
    },
    {
      "Sid": "TerraformStatePermissions",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::your-terraform-state-bucket/*",
        "arn:aws:s3:::your-terraform-state-bucket"
      ]
    },
    {
      "Sid": "DynamoDBLockPermissions",
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/your-terraform-lock-table"
    }
  ]
}
```

**重要**: バケット名やテーブル名を実際の値に置き換えてください。

### 3.3 ポリシーの作成とアタッチ

```bash
# ポリシーを作成
aws iam create-policy \
  --policy-name GitHubActionsPolicy \
  --policy-document file://github-actions-policy.json

# ロールにアタッチ
aws iam attach-role-policy \
  --role-name GitHubActionsRole \
  --policy-arn arn:aws:iam::YOUR_AWS_ACCOUNT_ID:policy/GitHubActionsPolicy
```

## ステップ4: GitHub Secretsの設定

### 4.1 GitHub Secretsに追加

1. GitHubリポジトリに移動
2. Settings → Secrets and variables → Actions
3. "New repository secret" をクリック
4. 以下のシークレットを追加:

```
Name: AWS_ROLE_ARN
Value: arn:aws:iam::123456789012:role/GitHubActionsRole
```

### 4.2 その他の必要なSecrets

```bash
# CodecovのToken（オプション）
CODECOV_TOKEN=your-codecov-token

# Slackの通知（オプション）
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

## ステップ5: GitHub Actionsワークフローの設定

ワークフローファイルで以下のように設定します:

```yaml
name: Deploy to ECS

on:
  push:
    branches: [main]

permissions:
  id-token: write  # OIDC トークンの取得に必要
  contents: read   # リポジトリの読み取りに必要

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v5

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v5.1
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ap-northeast-1

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      # 以降のステップでAWS CLIやSDKが使用可能
```

## ステップ6: 動作確認

### 6.1 テストワークフローの実行

1. mainブランチにプッシュしてワークフローをトリガー
2. GitHub Actionsのログを確認

成功した場合のログ例:
```
Assuming role arn:aws:iam::123456789012:role/GitHubActionsRole
Credentials configured successfully
```

### 6.2 CloudTrailでの確認

AWS CloudTrailで以下のイベントを確認:
- `AssumeRoleWithWebIdentity`
- どのGitHubリポジトリ/ブランチからのアクセスか

## トラブルシューティング

### エラー: "Not authorized to perform sts:AssumeRoleWithWebIdentity"

**原因**: 信頼ポリシーの設定が間違っている

**確認ポイント**:
1. OIDCプロバイダーが正しく作成されているか
2. 信頼ポリシーのリポジトリ名が正しいか
3. ブランチ名が正しいか（厳格な設定の場合）

```bash
# ロールの信頼ポリシーを確認
aws iam get-role --role-name GitHubActionsRole
```

### エラー: "Access Denied"

**原因**: IAMポリシーに必要な権限がない

**解決方法**:
1. CloudTrailで拒否されたAPIコールを確認
2. 必要な権限をポリシーに追加
3. ポリシーを更新

```bash
# ポリシーを更新
aws iam create-policy-version \
  --policy-arn arn:aws:iam::YOUR_AWS_ACCOUNT_ID:policy/GitHubActionsPolicy \
  --policy-document file://github-actions-policy.json \
  --set-as-default
```

### 権限の最小化

本番環境では、最小権限の原則に従ってください:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "arn:aws:ecr:ap-northeast-1:123456789012:repository/nextjs-ecs-*"
    }
  ]
}
```

## セキュリティのベストプラクティス

1. **環境別のロールを作成**
   - dev、staging、prodで別々のロールを使用
   - 本番環境は特定のブランチ/タグからのみアクセス可能に

2. **定期的な権限の見直し**
   - CloudTrailログを定期的に確認
   - 使用されていない権限を削除

3. **モニタリングの設定**
   - CloudWatch Alarmsで異常なAPI呼び出しを検知
   - SNSで通知を受け取る

4. **マルチAWS アカウント構成**
   - 環境ごとにAWSアカウントを分離
   - Organizations + SCPで権限を制限

## まとめ

OIDCを使用することで、セキュアかつ管理しやすいCI/CDパイプラインを構築できます。

主な設定内容:
- ✅ AWS IAM Identity Provider の作成
- ✅ 信頼ポリシーとロールの作成
- ✅ 必要最小限の権限ポリシーの作成
- ✅ GitHub Secretsの設定
- ✅ ワークフローの更新

次のステップ:
- [QUICK_START.md](./QUICK_START.md) - アプリケーションのデプロイ
- [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) - 詳細なデプロイガイド
- [SECURITY_POLICY.md](./SECURITY_POLICY.md) - セキュリティポリシー
