# テストガイド

## 概要

本プロジェクトは包括的なテスト戦略を採用しています:

1. **ユニットテスト**: Vitest
2. **E2Eテスト**: Playwright
3. **負荷テスト**: k6

## テストピラミッド

```
       /\
      /  \    E2E Tests (Playwright)
     /____\
    /      \  Integration Tests
   /________\
  /          \ Unit Tests (Vitest)
 /____________\
```

## ユニットテスト (Vitest)

### Frontend

```bash
cd apps/frontend

# テスト実行
npm test

# カバレッジ付き
npm run test:ci

# Watch モード
npm test -- --watch
```

### Backend

```bash
cd apps/backend

# テスト実行
npm test

# カバレッジ付き
npm run test:ci

# Watch モード
npm test -- --watch
```

### テスト作成例

```typescript
// apps/frontend/src/__tests__/components/Button.test.tsx
import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import { Button } from '@/components/Button'

describe('Button', () => {
  it('should render with text', () => {
    render(<Button>Click me</Button>)
    expect(screen.getByText('Click me')).toBeInTheDocument()
  })
})
```

```typescript
// apps/backend/src/__tests__/routes/health.test.ts
import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { build } from '../app'

describe('Health API', () => {
  let app

  beforeAll(async () => {
    app = await build()
  })

  afterAll(async () => {
    await app.close()
  })

  it('should return 200', async () => {
    const response = await app.inject({
      method: 'GET',
      url: '/health',
    })
    expect(response.statusCode).toBe(200)
  })
})
```

## E2Eテスト (Playwright)

### セットアップ

```bash
cd apps/frontend
npm ci
npx playwright install
```

### テスト実行

```bash
# すべてのブラウザでテスト
npm run test:e2e

# UI モード
npm run test:e2e:ui

# 特定のブラウザのみ
npx playwright test --project=chromium

# デバッグモード
npx playwright test --debug
```

### テスト作成例

```typescript
// apps/frontend/src/__tests__/e2e/login.spec.ts
import { test, expect } from '@playwright/test'

test.describe('Login Flow', () => {
  test('should login successfully', async ({ page }) => {
    await page.goto('/login')
    await page.fill('[name="email"]', 'user@example.com')
    await page.fill('[name="password"]', 'password123')
    await page.click('button[type="submit"]')

    await expect(page).toHaveURL('/dashboard')
    await expect(page.locator('h1')).toContainText('Dashboard')
  })
})
```

### CI/CD統合

E2Eテストは以下の場合に自動実行されます:
- Pull Requestの作成時
- mainブランチへのマージ時

結果はGitHub Actionsのアーティファクトに保存されます。

## 負荷テスト (k6)

### k6のインストール

```bash
# macOS
brew install k6

# Linux
curl -L https://github.com/grafana/k6/releases/download/v0.48.0/k6-v0.48.0-linux-amd64.tar.gz | tar xvz
sudo mv k6-v0.48.0-linux-amd64/k6 /usr/local/bin/

# Windows
choco install k6
```

### テスト実行

```bash
cd tests/load

# ヘルスチェック負荷テスト
npm run test:health

# ストレステスト
npm run test:stress

# スパイクテスト
npm run test:spike

# すべて実行
npm run test:all
```

### 本番環境テスト

```bash
# 環境変数で対象URLを指定
export PROD_URL=https://your-production-url.com
npm run test:health:prod
```

### テストシナリオ

#### 1. ヘルスチェックテスト (`health-check.js`)

**目的**: 基本的な負荷耐性を確認

**負荷パターン**:
- 0→10ユーザー (30秒)
- 10→50ユーザー (1分)
- 50→100ユーザー (30秒)
- 100ユーザー維持 (1分)
- 100→0ユーザー (30秒)

**閾値**:
- P95 < 500ms
- P99 < 1000ms
- エラー率 < 1%

#### 2. ストレステスト (`stress-test.js`)

**目的**: システムの限界を特定

**負荷パターン**:
- 段階的に500ユーザーまで増加
- 各段階で2分間維持

**閾値**:
- P95 < 1000ms
- P99 < 2000ms
- エラー率 < 5%

#### 3. スパイクテスト (`spike-test.js`)

**目的**: 急激な負荷増加への対応確認

**負荷パターン**:
- 10→500ユーザー (10秒で急増)
- 500ユーザー維持 (1分)
- 500→10ユーザー (10秒で急減)

**閾値**:
- P95 < 2000ms
- エラー率 < 10%

### カスタムメトリクス

k6では以下のカスタムメトリクスを収集:

```javascript
import { Rate, Trend, Counter } from 'k6/metrics';

const errorRate = new Rate('errors');
const requestDuration = new Trend('request_duration');
const requestCount = new Counter('requests');
```

### レポート

テスト結果は以下の形式で出力:
- JSON: `test-results/*.json`
- HTML: `test-results/*.html`
- 標準出力: サマリー

## CI/CD統合

### 自動テスト

#### Pull Request時
- ✅ Lint
- ✅ Type Check
- ✅ Unit Tests
- ✅ E2E Tests
- ✅ Build

#### mainブランチマージ時
- ✅ すべてのPRチェック
- ✅ Docker Image Build
- ✅ デプロイ

#### 手動実行
- 📊 Load Tests (GitHub Actions)

### カバレッジレポート

カバレッジは自動的にCodecovにアップロードされます:
- Frontend: `apps/frontend/coverage/`
- Backend: `apps/backend/coverage/`

目標カバレッジ:
- ステートメント: 80%
- ブランチ: 75%
- 関数: 80%
- ライン: 80%

## ベストプラクティス

### ユニットテスト

✅ **DO**
- 1テストケース = 1アサーション (可能な限り)
- テスト名は明確に (should/when/given)
- モックは最小限に
- テストは独立させる

❌ **DON'T**
- 実装の詳細をテストしない
- 複雑なセットアップは避ける
- フレイキーなテストは修正する

### E2Eテスト

✅ **DO**
- ユーザーの視点でテスト
- Page Object Patternを使用
- 明示的な待機を使用
- 重要なフローを優先

❌ **DON'T**
- すべてをE2Eでテストしない
- 暗黙的な待機は避ける
- ハードコードされた待機時間

### 負荷テスト

✅ **DO**
- 本番に近い環境でテスト
- 段階的に負荷を増やす
- 重要なエンドポイントを優先
- 定期的に実行

❌ **DON'T**
- 本番環境で無許可テストしない
- 極端な負荷は計画的に
- 結果を記録しておく

## トラブルシューティング

### Vitestが遅い

```bash
# 並列実行を調整
npm test -- --pool=threads --poolOptions.threads.maxThreads=4

# ファイルを限定
npm test -- path/to/test
```

### Playwrightがタイムアウト

```typescript
// playwright.config.ts
export default defineConfig({
  timeout: 30000, // 30秒に延長
  expect: {
    timeout: 5000
  }
})
```

### k6でメモリ不足

```bash
# VUsを減らす
k6 run --vus 50 --duration 30s script.js

# バッチでリクエストしない
# sleep時間を増やす
```

## 参考リンク

### ツール
- [Vitest](https://vitest.dev/)
- [Playwright](https://playwright.dev/)
- [k6](https://k6.io/docs/)
- [Testing Library](https://testing-library.com/)

### ガイド
- [Testing Best Practices](https://testingjavascript.com/)
- [k6 Best Practices](https://k6.io/docs/testing-guides/running-large-tests/)
- [Playwright Best Practices](https://playwright.dev/docs/best-practices)
