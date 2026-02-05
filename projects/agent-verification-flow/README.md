# AI駆動検証フロー - 汎用ツールキット

AIエージェント（Cursor, GitHub Copilot, Claude等）との協調で、WebサービスのAPI動作検証を効率的に行うためのツール群。

## 概要

本ツールキットは、AI駆動開発における検証フェーズを自動化・効率化するためのスクリプト群とドキュメントテンプレートを提供します。

### 対象アーキテクチャ

本ツールキットは以下のような一般的なWebサービス構成を想定しています:

| レイヤー | 想定技術 |
|---------|---------|
| **フロントエンド** | SPA（Single Page Application） |
| **バックエンド** | REST API |
| **API仕様** | OpenAPI / Swagger |
| **認証・認可** | JWT（OAuth2/OIDC）、Session + CSRF |
| **IdP** | AWS Cognito, Auth0, Firebase Auth 等 |
| **エラー監視** | Sentry, Datadog, New Relic 等 |

### 特徴

- **認証の自動化**: JWT認証/Session認証をスクリプト化
- **API呼び出しの標準化**: Bearer Token / Session+CSRF の両方式に対応
- **AIエージェントとの親和性**: CLIベースでAIが直接実行可能
- **ドキュメント駆動**: 検証ケース・レポートのテンプレート提供

## クイックスタート

```bash
cd projects/agent-verification-flow

# 1. 設定ファイル作成
cp config.yaml.example config.yaml
# config.yaml を編集（認証情報を入力）

# 2. 認証（JWT取得）
./scripts/cognito_auth.sh

# 3. API呼び出し
./scripts/api_call.sh GET /api/users
```

## ツール一覧

| スクリプト | 用途 | 認証方式 |
|-----------|------|----------|
| `scripts/cognito_auth.sh` | JWT取得（Cognito） | - |
| `scripts/api_call.sh` | API呼び出し | JWT Bearer Token |
| `scripts/session_api.sh` | API呼び出し | Session Cookie + CSRF |

## 認証方式

### JWT認証（`api_call.sh`）

IdP（Cognito, Auth0等）から取得したアクセストークンを使用。モダンなREST API向け。

```bash
./scripts/cognito_auth.sh
./scripts/api_call.sh GET /api/users
```

### Session認証（`session_api.sh`）

ブラウザセッション（Cookie + CSRF Token）を使用。従来型のWeb API向け。

```bash
# .session ファイルを作成（ブラウザのDevToolsから取得）
cat > .session << 'EOF'
BEARER_TOKEN="eyJraWQ..."
COOKIES="_ga=...; session=...; csrfToken=..."
CSRF_TOKEN="abc123..."
EOF

./scripts/session_api.sh GET /api/auth/me
```

## ドキュメント

| ドキュメント | 内容 |
|-------------|------|
| [docs/USAGE.md](docs/USAGE.md) | 詳細な使用方法 |
| [docs/DESIGN_PRINCIPLES.md](docs/DESIGN_PRINCIPLES.md) | 設計思想・原則 |
| [docs/LESSONS_LEARNED.md](docs/LESSONS_LEARNED.md) | 実践から学んだ教訓 |
| [docs/MULTI_AGENT_ORCHESTRATION.md](docs/MULTI_AGENT_ORCHESTRATION.md) | マルチエージェント構成 |

### テンプレート

| テンプレート | 用途 |
|-------------|------|
| [docs/templates/VERIFICATION_CASES.template.md](docs/templates/VERIFICATION_CASES.template.md) | 検証ケース定義 |
| [docs/templates/VERIFICATION_REPORT.template.md](docs/templates/VERIFICATION_REPORT.template.md) | 検証レポート |

## ディレクトリ構成

```
agent-verification-flow/
├── README.md                    # このファイル
├── config.yaml.example          # 設定テンプレート
├── config.yaml                  # 実際の設定（.gitignore）
├── .gitignore
│
├── scripts/
│   ├── cognito_auth.sh          # Cognito認証
│   ├── api_call.sh              # Bearer Token API呼び出し
│   └── session_api.sh           # Session API呼び出し
│
├── docs/
│   ├── USAGE.md                 # 詳細な使用方法
│   ├── DESIGN_PRINCIPLES.md     # 設計思想
│   ├── MULTI_AGENT_ORCHESTRATION.md  # マルチエージェント構成
│   └── templates/
│       ├── VERIFICATION_CASES.template.md
│       └── VERIFICATION_REPORT.template.md
│
└── examples/
    └── verify_pr.sh.example     # PR検証スクリプト例
```

## 環境要件

### 必須

- `bash` 3.2+
- `curl`
- `jq`

### オプション

- `aws` CLI（Cognito認証用）
- `yq`（YAML解析用、なくても動作）

## AIエージェントとの連携

AIエージェントがこれらのスクリプトを自動実行して検証を行います：

```
User: 対象環境でAPIの動作確認をして

AI: 1. ./scripts/cognito_auth.sh でJWT取得
    2. 各APIエンドポイントを呼び出し
    3. レスポンスを確認
    4. 結果をレポート
```

### 発展: マルチエージェント構成

複雑な検証では、複数のエージェントが協調して動作する構成が有効です。
詳細は [docs/MULTI_AGENT_ORCHESTRATION.md](docs/MULTI_AGENT_ORCHESTRATION.md) を参照。

## カスタマイズ

プロジェクト固有の検証ロジックは `examples/` のサンプルを参考に作成してください。

### サンプルスクリプト

| サンプル | 用途 |
|---------|------|
| `verify_pr.sh.example` | PR検証スクリプトのテンプレート |
| `get_session_playwright.sh.example` | PlaywrightでSession情報を半自動取得 |
| `api_wrapper.sh.example` | JWT/Session認証の自動選択ラッパー |

```bash
# PR検証スクリプトの作成例
cp examples/verify_pr.sh.example my_verify.sh
# 必要に応じて編集

# Session情報の半自動取得
LOGIN_URL=https://your-app.example.com/login ./examples/get_session_playwright.sh.example
```

## ライセンス

MIT License
