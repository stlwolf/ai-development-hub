# 詳細な使用方法

## 対象アーキテクチャ

本ツールは以下のような一般的なWebサービス構成を想定しています:

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   SPA Frontend  │────▶│   REST API      │────▶│   Database      │
│   (React/Vue等) │     │   (Backend)     │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
         │                      │
         │                      ▼
         │              ┌─────────────────┐
         └─────────────▶│   IdP (Cognito  │
                        │   Auth0, etc)   │
                        └─────────────────┘
```

| 要素 | 説明 |
|------|------|
| **SPA** | Single Page Application（React, Vue, Angular等） |
| **REST API** | OpenAPI/Swagger で定義されたバックエンドAPI |
| **認証** | JWT（OAuth2/OIDC）または Session + CSRF |
| **IdP** | Identity Provider（Cognito, Auth0, Firebase Auth等） |

---

## セットアップ

### 1. 設定ファイルの作成

```bash
cd local/ai_verify_generic
cp config.yaml.example config.yaml
```

`config.yaml` を編集：

```yaml
api:
  base_url: "https://your-app.example.com/api"

cognito:
  region: ap-northeast-1
  user_pool_id: "ap-northeast-1_xxxxxxxxx"
  client_id: "xxxxxxxxxxxxxxxxxxxxxxxxxx"

auth:
  username: "your-email@example.com"
  password: "your-password"
```

### 2. 環境変数の設定（オプション）

```bash
# エラー監視API Token（Sentry等の確認時に必要）
export SENTRY_AUTH_TOKEN="your-sentry-token"

# AWS Profile（オプション、デフォルトプロファイル以外を使う場合）
export AWS_PROFILE="your-profile"

# API Base URL（config.yaml より優先）
export API_BASE_URL="https://your-app.example.com/api"
```

---

## 認証方式の選択

どちらのスクリプトを使うか迷った場合は、以下のフローチャートを参考にしてください。

```
API呼び出し時の認証選択:

1. OpenAPI/Swagger定義がある
   → api_call.sh (JWT認証)

2. ブラウザからしかアクセスできない（管理画面系など）
   → session_api.sh (Session認証)

3. どちらでも動く
   → api_call.sh を優先（セッション管理不要で簡単）

4. api_call.sh で 401 エラーが返る
   → session_api.sh を試す
```

| スクリプト | 認証方式 | 使うべき場面 |
|---|---|---|
| `api_call.sh` | JWT Bearer Token | OpenAPI定義があるモダンなREST API |
| `session_api.sh` | Cookie + CSRF | ブラウザセッション前提の従来型API、管理画面系 |

---

## cognito_auth.sh（JWT取得）

Cognito USER_PASSWORD_AUTH フローでJWTアクセストークンを取得。

> **Note**: Auth0, Firebase Auth等を使用する場合は、このスクリプトを参考に各IdP用のスクリプトを作成してください。

### 基本使用

```bash
# config.yaml から認証情報を読み込み
./scripts/cognito_auth.sh

# 環境変数から認証情報を読み込み
COGNITO_USER_POOL_ID=xxx COGNITO_CLIENT_ID=xxx AUTH_USERNAME=xxx AUTH_PASSWORD=xxx \
  ./scripts/cognito_auth.sh --env
```

### 出力

- 成功: `.token` ファイルにJWTアクセストークンを保存
- 失敗: エラーメッセージを標準エラー出力

### トークンの有効期限

- デフォルト: 1時間（IdP設定による）
- 期限切れの場合は再実行で更新

---

## api_call.sh（JWT認証API）

JWT Bearer Token を使用してAPIを呼び出す。モダンなREST API向け。

### 基本使用

```bash
./scripts/api_call.sh <METHOD> <PATH> [OPTIONS]
```

### 引数

| 引数 | 説明 | 例 |
|------|------|-----|
| METHOD | HTTPメソッド | GET, POST, PUT, DELETE |
| PATH | APIパス | /api/users |

### オプション

| オプション | 説明 | 例 |
|------------|------|-----|
| `-d, --data` | リクエストボディ | `-d '{"key":"value"}'` |
| `-f, --file` | ボディをファイルから | `-f request.json` |
| `-q, --query` | クエリパラメータ | `-q "page=1&limit=10"` |
| `--raw` | JSON整形をしない | |
| `--status-only` | ステータスコードのみ出力 | |
| `-v, --verbose` | 詳細出力 | |

### 使用例

```bash
# 基本
./scripts/api_call.sh GET /api/users

# クエリパラメータ付き
./scripts/api_call.sh GET /api/users -q "page=1&per_page=10"

# POST リクエスト
./scripts/api_call.sh POST /api/items -d '{"name":"test"}'

# ステータスコードのみ確認
./scripts/api_call.sh GET /api/users --status-only
# => 200

# 詳細出力
./scripts/api_call.sh GET /api/me --verbose
```

---

## session_api.sh（Session認証API）

Session Cookie + CSRF Token を使用してAPIを呼び出す。従来型のWeb API向け。

### セッション情報の取得

1. ブラウザでアプリケーションにログイン
2. DevTools (F12) → Network タブ
3. 任意のAPIリクエストを選択
4. 以下の情報をコピー:
   - `Authorization` ヘッダーの Bearer Token（ある場合）
   - `Cookie` ヘッダー全体
   - `X-CSRF-Token` ヘッダー（ある場合）

### .session ファイルの作成

```bash
cat > .session << 'EOF'
BEARER_TOKEN="eyJraWQiOiIrVkh3..."
COOKIES="_ga=GA1.1...; session=eyJraWQi...; csrfToken=abc123..."
CSRF_TOKEN="abc123..."
EOF
```

### 基本使用

```bash
./scripts/session_api.sh <METHOD> <PATH> [OPTIONS]
```

### オプション

`api_call.sh` と同じオプションが使用可能。

### 使用例

```bash
# 認証情報確認
./scripts/session_api.sh GET /api/auth/me

# ユーザー一覧
./scripts/session_api.sh GET /api/users

# CSV出力
./scripts/session_api.sh GET /api/exports/csv --raw > export.csv

# POSTリクエスト
./scripts/session_api.sh POST /api/items -d '{"data":[]}'
```

---

## エラー監視連携（Sentry）

### Issue検索

```bash
ORG="your-org"
ISSUE_ID="1234567890"

curl -fSs "https://sentry.io/api/0/organizations/${ORG}/issues/${ISSUE_ID}/" \
  -H "Authorization: Bearer ${SENTRY_AUTH_TOKEN}" | \
  jq '{shortId, count, lastSeen, culprit}'
```

### 複数Issue一括確認

```bash
ORG="your-org"
for id in 1234567890 1234567891 1234567892; do
  curl -fSs "https://sentry.io/api/0/organizations/${ORG}/issues/${id}/" \
    -H "Authorization: Bearer ${SENTRY_AUTH_TOKEN}" | \
    jq -r '"[\(.shortId)] count:\(.count) lastSeen:\(.lastSeen | .[0:19])"'
done
```

---

## よくあるエラーと対処

### HTTP 401 - Token invalid

```
[ERROR] HTTP 401
{"message": "Token invalid."}
```

**原因**: トークン期限切れ or セッション切れ

**対処**:
```bash
# Cognito Token 再取得
./scripts/cognito_auth.sh

# Session 情報更新（ブラウザから再取得）
```

### bad substitution

```
./api_call.sh: line XX: ${1^^}: bad substitution
```

**原因**: macOSのデフォルトbash (v3) の制限

**対処**: スクリプトは互換性対応済み。それでも出る場合は `bash --version` 確認

### yq: command not found

```
yq: command not found
```

**影響**: なし（grep/sedで代用される）

**対処**（オプション）:
```bash
brew install yq
```

### Permission denied

```
bash: ./scripts/cognito_auth.sh: Permission denied
```

**対処**:
```bash
chmod +x scripts/*.sh
```

---

## 環境変数一覧

| 変数名 | 説明 | デフォルト |
|--------|------|------------|
| `API_BASE_URL` | APIベースURL | config.yamlから |
| `ACCESS_TOKEN` | Cognito Access Token | .tokenファイルから |
| `CONFIG_FILE` | 設定ファイルパス | `../config.yaml` |
| `TOKEN_FILE` | トークンファイルパス | `../.token` |
| `SESSION_FILE` | セッションファイルパス | `../.session` |
| `SENTRY_AUTH_TOKEN` | Sentry API Token | - |
| `AWS_PROFILE` | AWS CLIプロファイル | default |
| `DEBUG` | デバッグ出力有効化 | false |
