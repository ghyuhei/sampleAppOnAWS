# デプロイメントガイド

## 環境別デプロイ手順

### 開発環境 (dev)

#### 自動デプロイ
`main`ブランチへのマージで自動的にデプロイされます。

```bash
git checkout -b feature/new-feature
# 開発作業
git commit -m "feat: add new feature"
git push origin feature/new-feature

# Pull Request作成 → レビュー → マージ
# GitHub Actionsが自動的にdev環境へデプロイ
```

#### 手動デプロイ
```bash
cd infrastructure/terraform/environments/dev

# インフラ変更
terraform plan
terraform apply

# アプリケーション デプロイ
cd ../../ecspresso
ecspresso deploy --config config.yaml
```

### ステージング環境 (staging)

#### タグベースデプロイ
```bash
# リリースタグの作成
git tag -a v1.0.0-staging -m "Release v1.0.0 to staging"
git push origin v1.0.0-staging

# GitHub Actionsが自動的にstagingにデプロイ
```

#### 手動デプロイ
```bash
cd infrastructure/terraform/environments/staging

# 環境変数設定
export TF_VAR_certificate_arn="arn:aws:acm:..."
export TF_VAR_alert_email="staging-alerts@example.com"

# インフラデプロイ
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

### 本番環境 (prod)

#### 承認フロー付きデプロイ
```bash
# 1. リリースタグの作成
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# 2. GitHub Actionsワークフローが起動
# 3. Production環境の承認待ち
# 4. 承認後、自動デプロイ
```

#### 緊急デプロイ (手動)
```bash
cd infrastructure/terraform/environments/prod

# 環境変数設定 (必須)
export TF_VAR_certificate_arn="arn:aws:acm:..."
export TF_VAR_alert_email="prod-alerts@example.com"

# インフラデプロイ
terraform init -backend-config=backend.hcl
terraform plan
terraform apply

# アプリケーションデプロイ
cd ../../ecspresso
export IMAGE_TAG=v1.0.0
ecspresso deploy --config config.yaml
```

## CI/CDパイプライン

### GitHub Actions ワークフロー

#### Pull Request時
```yaml
jobs:
  - lint-and-test      # コード品質チェック
  - terraform-plan     # インフラ変更プレビュー
  - build-image        # Dockerイメージビルド (キャッシュのみ)
```

#### mainブランチマージ時
```yaml
jobs:
  - build-and-push     # ECRにイメージプッシュ
  - upload-assets      # S3に静的アセット配置
  - deploy-dev         # dev環境へ自動デプロイ
  - invalidate-cache   # CloudFrontキャッシュクリア
```

#### タグプッシュ時 (staging)
```yaml
jobs:
  - build-and-push     # ECRにイメージプッシュ
  - deploy-staging     # staging環境へデプロイ
```

#### タグプッシュ時 (prod)
```yaml
jobs:
  - build-and-push     # ECRにイメージプッシュ
  - deploy-prod        # 承認後にprod環境へデプロイ
    environment: production  # 手動承認が必要
```

## ロールバック手順

### 方法1: ecspressoによるロールバック
```bash
cd infrastructure/ecspresso

# 前回のデプロイにロールバック
ecspresso rollback --config config.yaml --rollback-events 1

# 2つ前のデプロイにロールバック
ecspresso rollback --config config.yaml --rollback-events 2
```

### 方法2: 特定バージョンへのロールバック
```bash
# 特定のイメージタグを指定してデプロイ
export IMAGE_TAG=v1.0.0
ecspresso deploy --config config.yaml
```

### 方法3: GitHubタグからロールバック
```bash
# 前のバージョンのタグを再プッシュ
git tag -a v1.0.0-rollback -m "Rollback to v1.0.0"
git push origin v1.0.0-rollback
```

## デプロイ前チェックリスト

### 開発環境
- [ ] コードレビュー完了
- [ ] ユニットテスト通過
- [ ] Lint/型チェック通過

### ステージング環境
- [ ] 開発環境で動作確認済み
- [ ] 統合テスト完了
- [ ] パフォーマンステスト完了
- [ ] セキュリティスキャン完了

### 本番環境
- [ ] ステージング環境で十分にテスト済み
- [ ] リリースノート作成
- [ ] データベースマイグレーション確認
- [ ] ロールバック手順確認
- [ ] 関係者への通知完了
- [ ] メンテナンス時間の調整 (必要に応じて)
- [ ] 監視体制の確認

## トラブルシューティング

### デプロイが失敗する

#### 症状: Terraform apply失敗
```bash
# エラーログ確認
terraform plan -detailed-exitcode

# ステート確認
terraform state list
terraform state show <resource>

# ステート修復 (慎重に)
terraform import <resource> <id>
```

#### 症状: ecspresso deployタイムアウト
```bash
# サービス状態確認
ecspresso status --config config.yaml

# タスク詳細確認
aws ecs describe-tasks \
  --cluster <cluster-name> \
  --tasks <task-arn>

# タスクログ確認
aws logs tail /ecs/<project>/<app> --follow
```

### サービスが起動しない

#### ヘルスチェック失敗
```bash
# ターゲットヘルス確認
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>

# アプリケーションログ確認
aws logs tail /ecs/<project>/<app> --follow

# コンテナ内でヘルスチェックパスを確認
curl http://localhost:3000/api/health
```

#### リソース不足
```bash
# ECS Capacityの確認
aws ecs describe-capacity-providers \
  --cluster <cluster-name>

# Auto Scalingグループ確認
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names <asg-name>
```

### パフォーマンス問題

#### CPU/Memory使用率が高い
```bash
# CloudWatch Insightsで確認
# CPU使用率の推移
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ClusterName,Value=<cluster> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# スケーリング
aws ecs update-service \
  --cluster <cluster-name> \
  --service <service-name> \
  --desired-count 5
```

#### レスポンスタイムが遅い
```bash
# X-Rayトレース確認 (本番環境)
aws xray get-trace-summaries \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s)

# ALBメトリクス確認
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=<alb-arn-suffix> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum
```

## メンテナンスモード

### ALBでメンテナンスページ表示

```bash
# 1. メンテナンスページをS3にアップロード
aws s3 cp maintenance.html s3://your-bucket/maintenance.html

# 2. ALBリスナールールを一時的に変更
aws elbv2 modify-rule \
  --rule-arn <rule-arn> \
  --actions Type=fixed-response,FixedResponseConfig={StatusCode=503,ContentType=text/html,MessageBody="$(cat maintenance.html)"}

# 3. メンテナンス完了後、ルールを元に戻す
aws elbv2 modify-rule \
  --rule-arn <rule-arn> \
  --actions Type=forward,TargetGroupArn=<target-group-arn>
```

## モニタリング

### デプロイ後の確認項目

#### 即座に確認 (0-5分)
- [ ] ECS Taskが正常起動
- [ ] ヘルスチェック通過
- [ ] CloudWatchアラームが発火していない

#### 短期確認 (5-30分)
- [ ] エラーログが増加していない
- [ ] レスポンスタイムが正常範囲内
- [ ] CPU/Memory使用率が正常範囲内

#### 中期確認 (30分-24時間)
- [ ] ユーザーからの問題報告なし
- [ ] ビジネスメトリクスが正常
- [ ] コスト異常なし

### 便利なコマンド

```bash
# リアルタイムログ監視
aws logs tail /ecs/<project>/<app> --follow --format short

# 最近のエラーログのみ表示
aws logs filter-log-events \
  --log-group-name /ecs/<project>/<app> \
  --filter-pattern "ERROR" \
  --start-time $(date -u -d '1 hour ago' +%s)000

# ECSサービス詳細
aws ecs describe-services \
  --cluster <cluster-name> \
  --services <service-name> \
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount,Events:events[:5]}'
```

## 参考資料

- [エンタープライズセットアップガイド](./ENTERPRISE_SETUP.md)
- [セキュリティポリシー](./SECURITY_POLICY.md)
- [インシデント対応手順](./INCIDENT_RESPONSE.md)
