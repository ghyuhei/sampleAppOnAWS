# セキュリティポリシー

## 概要

本ドキュメントは、本プロジェクトにおけるセキュリティポリシーとベストプラクティスを定義します。

## 認証・認可

### AWS IAM

#### 最小権限の原則
- 各サービス/ロールには必要最小限の権限のみを付与
- 定期的な権限レビュー (四半期ごと)

#### Multi-Factor Authentication (MFA)
- AWS ルートアカウントは必ずMFAを有効化
- IAMユーザーは特権操作にMFAを要求

#### アクセスキーの管理
- GitHub ActionsはOIDCを使用 (アクセスキー不使用)
- ローテーションポリシー: 90日ごと

### Secrets Manager

#### 機密情報の管理
以下の情報は必ずSecrets Managerで管理:
- データベース認証情報
- APIキー
- 暗号化キー
- OAuth トークン

#### アクセスログ
- Secrets Manager アクセスは CloudTrail で記録
- 不正アクセス試行は自動アラート

## ネットワークセキュリティ

### VPC設計

```
Public Subnet  (ALB のみ)
    ↓
Private Subnet (ECS Instances)
    ↓
VPC Endpoints (ECR, S3, CloudWatch)
```

#### セキュリティグループルール
- **ALB**: 80/443ポートのみ公開
- **ECS Instances**: ALBからの動的ポートマッピングのみ許可
- **Egress**: VPC Endpoints経由でAWSサービスにアクセス

### WAF (Web Application Firewall)

#### 有効化ルール
- AWS Managed Rules - Core Rule Set
- AWS Managed Rules - Known Bad Inputs
- Rate Limiting: 2000 req/5分 (本番)

#### カスタムルール
- SQLインジェクション対策
- XSS対策
- 地域ベースのブロック (必要に応じて)

## データ保護

### 転送時の暗号化
- CloudFront: TLS 1.2以上のみ許可
- ALB: HTTPS リダイレクト (本番環境)
- VPC Endpoints: プライベート接続

### 保存時の暗号化
- **S3**: AES-256 暗号化
- **ECR**: KMS暗号化
- **EBS**: KMS暗号化
- **Secrets Manager**: KMS暗号化
- **CloudWatch Logs**: KMS暗号化 (オプション)

### バックアップ
- ECS Task Definitionは自動バージョニング
- Terraformステートは S3 バージョニング有効
- データベース: 日次バックアップ (保持期間30日)

## コンテナセキュリティ

### Dockerイメージ

#### ベースイメージ
- 公式イメージのみ使用
- Alpine Linuxを優先 (最小サイズ)

#### イメージスキャン
- ECR Image Scanningを有効化
- プッシュ時に自動スキャン
- 重大な脆弱性が見つかった場合はデプロイブロック

#### マルチステージビルド
```dockerfile
FROM node:22-alpine AS builder
# ビルド

FROM node:22-alpine AS runner
# 非rootユーザーで実行
USER nextjs
```

### 実行時セキュリティ

#### 非rootユーザー
- すべてのコンテナは非rootユーザーで実行
- UID/GID: 1001

#### Read-Only ルートファイルシステム
```json
{
  "readonlyRootFilesystem": true,
  "tmpfs": ["/tmp"]
}
```

#### Drop Capabilities
```json
{
  "linuxParameters": {
    "capabilities": {
      "drop": ["ALL"]
    }
  }
}
```

## ログとモニタリング

### ログ収集

#### CloudWatch Logs
- すべてのコンテナログを収集
- 保持期間:
  - 開発: 7日
  - ステージング: 14日
  - 本番: 30日

#### アクセスログ
- ALB Access Logs: S3に保存
- CloudFront Access Logs: S3に保存
- VPC Flow Logs: CloudWatch Logsに保存

### セキュリティ監視

#### CloudTrail
- すべてのAPI呼び出しを記録
- マルチリージョン有効化
- ログファイル整合性検証を有効化

#### GuardDuty
- 脅威検出を有効化 (ステージング、本番)
- 検出結果を自動アラート

#### Config
- リソース設定の変更を追跡
- コンプライアンスルールの自動評価

### アラート

#### 重要度別アラート
- **Critical**: 即座にオンコール対応
  - ECS Task停止
  - ALB Unhealthy Targets
  - 不正アクセス試行

- **High**: 24時間以内に対応
  - 5xxエラー多発
  - Secrets Manager不正アクセス

- **Warning**: 定期レビュー
  - CPU/Memory高使用率
  - コスト異常

## インシデント対応

### 検知
1. CloudWatch Alarms
2. GuardDuty検出
3. ユーザー報告

### 対応フロー
1. **検知** → アラート受信
2. **分析** → ログ調査、影響範囲特定
3. **封じ込め** → 該当リソースの隔離
4. **根絶** → 脆弱性の修正
5. **復旧** → サービス復旧
6. **事後対応** → ポストモーテム、再発防止

### エスカレーション
```
L1 (オンコール) → L2 (シニアエンジニア) → L3 (アーキテクト/マネージャー)
```

## コンプライアンス

### 定期監査

#### 月次
- IAM権限レビュー
- Secrets Manager使用状況
- コストレビュー

#### 四半期
- セキュリティパッチ適用状況
- 脆弱性スキャン結果レビュー
- アクセスログレビュー

#### 年次
- セキュリティポリシー全体レビュー
- 災害復旧訓練

### チェックリスト

#### 本番デプロイ前
- [ ] ECRイメージスキャン完了 (脆弱性なし)
- [ ] HTTPS証明書設定済み
- [ ] Secrets Manager設定完了
- [ ] WAF有効化
- [ ] CloudWatch Alarms設定完了
- [ ] バックアップ設定完了
- [ ] アクセスログ有効化

## 脆弱性報告

### 報告先
security@example.com

### 対応SLA
- **Critical**: 24時間以内
- **High**: 3営業日以内
- **Medium**: 1週間以内
- **Low**: 次回リリース時

## 更新履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2025-01-XX | 1.0 | 初版作成 |
