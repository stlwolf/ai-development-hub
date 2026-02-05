#!/bin/bash
# JWT認証スクリプト（AWS Cognito用）
# USER_PASSWORD_AUTH フローでJWTアクセストークンを取得
# Note: Auth0, Firebase Auth等を使用する場合は、このスクリプトを参考に各IdP用に調整してください
#
# 使用方法:
#   ./cognito_auth.sh              # config.yamlから設定読み込み
#   ./cognito_auth.sh --env        # 環境変数から設定読み込み
#
# 出力:
#   成功時: アクセストークンを .token ファイルに保存し、標準出力にも出力
#   失敗時: エラーメッセージを標準エラー出力

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-${SCRIPT_DIR}/../config.yaml}"
TOKEN_FILE="${TOKEN_FILE:-${SCRIPT_DIR}/../.token}"

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# 設定値の読み込み
load_config() {
    if [[ "$1" == "--env" ]]; then
        # 環境変数から読み込み
        COGNITO_REGION="${COGNITO_REGION:-ap-northeast-1}"
        COGNITO_USER_POOL_ID="${COGNITO_USER_POOL_ID:?環境変数 COGNITO_USER_POOL_ID が必要です}"
        COGNITO_CLIENT_ID="${COGNITO_CLIENT_ID:?環境変数 COGNITO_CLIENT_ID が必要です}"
        AUTH_USERNAME="${AUTH_USERNAME:?環境変数 AUTH_USERNAME が必要です}"
        AUTH_PASSWORD="${AUTH_PASSWORD:?環境変数 AUTH_PASSWORD が必要です}"
    else
        # config.yamlから読み込み
        if [[ ! -f "$CONFIG_FILE" ]]; then
            log_error "設定ファイルが見つかりません: $CONFIG_FILE"
            log_info "config.yaml.example をコピーして設定してください:"
            log_info "  cp config.yaml.example config.yaml"
            exit 1
        fi

        # yqがない場合はgrepとsedで代用
        if command -v yq &> /dev/null; then
            COGNITO_REGION=$(yq -r '.cognito.region' "$CONFIG_FILE")
            COGNITO_USER_POOL_ID=$(yq -r '.cognito.user_pool_id' "$CONFIG_FILE")
            COGNITO_CLIENT_ID=$(yq -r '.cognito.client_id' "$CONFIG_FILE")
            AUTH_USERNAME=$(yq -r '.auth.username' "$CONFIG_FILE")
            AUTH_PASSWORD=$(yq -r '.auth.password' "$CONFIG_FILE")
        else
            # シンプルなYAMLパーサー（yqがない環境用）
            COGNITO_REGION=$(grep 'region:' "$CONFIG_FILE" | head -1 | sed 's/.*: *//' | tr -d '"')
            COGNITO_USER_POOL_ID=$(grep 'user_pool_id:' "$CONFIG_FILE" | sed 's/.*: *//' | tr -d '"')
            COGNITO_CLIENT_ID=$(grep 'client_id:' "$CONFIG_FILE" | head -1 | sed 's/.*: *//' | tr -d '"')
            AUTH_USERNAME=$(grep 'username:' "$CONFIG_FILE" | sed 's/.*: *//' | tr -d '"')
            AUTH_PASSWORD=$(grep 'password:' "$CONFIG_FILE" | sed 's/.*: *//' | tr -d '"')
        fi
    fi

    # バリデーション
    [[ -z "$COGNITO_USER_POOL_ID" || "$COGNITO_USER_POOL_ID" == "YOUR_USER_POOL_ID" ]] && {
        log_error "COGNITO_USER_POOL_ID が設定されていません"
        exit 1
    }
    [[ -z "$COGNITO_CLIENT_ID" || "$COGNITO_CLIENT_ID" == "YOUR_CLIENT_ID" ]] && {
        log_error "COGNITO_CLIENT_ID が設定されていません"
        exit 1
    }
    [[ -z "$AUTH_USERNAME" || "$AUTH_USERNAME" == *"example.com" ]] && {
        log_error "AUTH_USERNAME が設定されていません"
        exit 1
    }
}

# Cognito認証実行
authenticate() {
    log_info "Cognito認証を開始..."
    log_info "UserPool: $COGNITO_USER_POOL_ID"
    log_info "User: $AUTH_USERNAME"

    # USER_PASSWORD_AUTH フローで認証
    local response
    response=$(aws cognito-idp initiate-auth \
        --region "$COGNITO_REGION" \
        --auth-flow USER_PASSWORD_AUTH \
        --client-id "$COGNITO_CLIENT_ID" \
        --auth-parameters USERNAME="$AUTH_USERNAME",PASSWORD="$AUTH_PASSWORD" \
        2>&1) || {
        log_error "Cognito認証に失敗しました"
        log_error "$response"
        exit 1
    }

    # アクセストークンを抽出
    local access_token
    access_token=$(echo "$response" | jq -r '.AuthenticationResult.AccessToken')

    if [[ -z "$access_token" || "$access_token" == "null" ]]; then
        log_error "アクセストークンの取得に失敗しました"
        log_error "Response: $response"
        exit 1
    fi

    # トークンをファイルに保存
    echo "$access_token" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"

    log_info "認証成功！トークンを保存しました: $TOKEN_FILE"

    # 標準出力にもトークンを出力（パイプ用）
    echo "$access_token"
}

# メイン処理
main() {
    local mode="${1:-}"
    load_config "$mode"
    authenticate
}

# 実行
main "$@"
