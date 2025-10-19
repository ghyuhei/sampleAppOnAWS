# Changelog

このプロジェクトに対する重要な変更はすべてこのファイルに記録されます。

## [Unreleased]

### Added - プロジェクト公開準備

#### インフラストラクチャ
- ルートレベルの`package.json`を追加（モノレポ管理）
- Terraform backend設定ファイル（`backend.hcl`）を各環境に追加
- `Makefile`を追加してタスクの実行を簡素化

#### デプロイメント
- 統合デプロイスクリプト（`scripts/deploy.sh`）を追加
- GitHub Actions デプロイワークフロー（`.github/workflows/deploy.yml`）を追加
  - 環境別デプロイ（dev/staging/prod）
  - コンポーネント別デプロイ（frontend/backend/all）
  - 手動トリガーサポート

#### 環境設定
- `.env.example`をプロジェクトルートに追加
- `apps/frontend/.env.example`を追加
- `apps/backend/.env.example`を追加

#### Docker最適化
- フロントエンドの`.dockerignore`を改善
- バックエンドの`.dockerignore`を改善

#### ドキュメント
- `docs/QUICK_START.md` - クイックスタートガイド
- `docs/GITHUB_OIDC_SETUP.md` - GitHub Actions OIDC設定ガイド
- `CHANGELOG.md` - このファイル
- `README.md`を更新してMakefileの使用方法を追加

#### その他
- `.gitignore`を拡張（テスト成果物、キャッシュ等）

### Changed

- `README.md`のセットアップ手順を更新
- ディレクトリ構成を明確化

### Improved

- CI/CDパイプラインの整備
- デプロイメントプロセスの自動化
- 開発者エクスペリエンスの向上

## Future Improvements

### 優先度: 高
- [ ] Docker Compose設定の追加（ローカル開発環境）
- [ ] RDSモジュールの追加（データベース対応）
- [ ] ElastiCacheモジュールの追加（Redis対応）

### 優先度: 中
- [ ] カスタムドメイン設定（Route 53 + ACM）
- [ ] Bastion Host設定（セキュアなSSHアクセス）
- [ ] VPNまたはPrivateLinkの設定
- [ ] Blue/Greenデプロイメントの対応

### 優先度: 低
- [ ] マルチリージョン対応
- [ ] ディザスタリカバリ設定
- [ ] Autoscaling設定の最適化
- [ ] コスト最適化レポート

## Notes

このプロジェクトは本番環境での使用を想定して設計されています。
各環境（dev/staging/prod）での設定は、それぞれの要件に応じて調整してください。

## Version History

### v1.0.0 (Initial Release)
- AWS ECS Managed Instanceベースのインフラ
- Next.js + TypeScript フロントエンド
- Fastify + TypeScript バックエンド
- Terraformによるインフラ管理
- GitHub Actions CI/CD
- 包括的なテストスイート（Vitest, Playwright, k6）
