#!/bin/bash
# APIラッパースクリプト（JWT認証用）
# JWT Bearer Tokenを自動付与してREST API呼び出し
#
# 使用方法:
#   ./api_call.sh GET /api/users
#   ./api_call.sh POST /api/items -d '{"key":"value"}'
#   ./api_call.sh GET /api/users --raw    # JSON整形なし
#
# 環境変数:
#   API_BASE_URL: APIベースURL（デフォルト: config.yamlから読み込み）
#   ACCESS_TOKEN: JWTトークン（デフォルト: .tokenファイルから読み込み）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-${SCRIPT_DIR}/../config.yaml}"
TOKEN_FILE="${TOKEN_FILE:-${SCRIPT_DIR}/../.token}"

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_debug() { [[ "${DEBUG:-}" == "true" ]] && echo -e "${CYAN}[DEBUG]${NC} $1" >&2 || true; }

# 使用方法
usage() {
    cat <<EOF >&2
使用方法: $(basename "$0") <METHOD> <PATH> [OPTIONS]

引数:
  METHOD    HTTPメソッド (GET, POST, PUT, DELETE, PATCH)
  PATH      APIパス (例: /api/users)

オプション:
  -d, --data DATA     リクエストボディ (JSON文字列)
  -f, --file FILE     リクエストボディをファイルから読み込み
  -q, --query PARAMS  クエリパラメータ (例: "page=1&limit=10")
  --raw               JSON整形をしない
  --status-only       HTTPステータスコードのみ出力
  -v, --verbose       詳細出力
  -h, --help          このヘルプを表示

例:
  $(basename "$0") GET /api/users
  $(basename "$0") GET /api/users -q "page=1&per_page=10"
  $(basename "$0") POST /api/items -d '{"data":[]}'
  $(basename "$0") GET /api/me --verbose
EOF
    exit 1
}

# 設定読み込み
load_config() {
    # APIベースURL
    if [[ -z "${API_BASE_URL:-}" ]]; then
        if [[ -f "$CONFIG_FILE" ]]; then
            if command -v yq &> /dev/null; then
                API_BASE_URL=$(yq -r '.api.base_url // .staging.api_base // empty' "$CONFIG_FILE")
            else
                API_BASE_URL=$(grep -E '(api_base|base_url):' "$CONFIG_FILE" | head -1 | sed 's/.*: *//' | tr -d '"')
            fi
        fi
        if [[ -z "${API_BASE_URL:-}" ]]; then
            log_error "API_BASE_URL が設定されていません"
            log_info "config.yaml に api.base_url を設定するか、環境変数 API_BASE_URL を設定してください"
            exit 1
        fi
    fi

    # アクセストークン
    if [[ -z "${ACCESS_TOKEN:-}" ]]; then
        if [[ -f "$TOKEN_FILE" ]]; then
            ACCESS_TOKEN=$(cat "$TOKEN_FILE")
        else
            log_error "JWTトークンファイルが見つかりません: $TOKEN_FILE"
            log_info "先にJWT認証を実行してください: ./scripts/cognito_auth.sh"
            exit 1
        fi
    fi
}

# API呼び出し
call_api() {
    local method="$1"
    local path="$2"
    local data="${3:-}"
    local query="${4:-}"
    local raw="${5:-false}"
    local status_only="${6:-false}"
    local verbose="${7:-false}"

    # URLの組み立て
    local url="${API_BASE_URL}${path}"
    [[ -n "$query" ]] && url="${url}?${query}"

    # curlオプションの組み立て
    local curl_opts=(
        -s
        -w "\n%{http_code}"
        -X "$method"
        -H "Authorization: Bearer $ACCESS_TOKEN"
        -H "Content-Type: application/json"
        -H "Accept: application/json"
    )

    # リクエストボディ
    [[ -n "$data" ]] && curl_opts+=(-d "$data")

    # 詳細出力
    if [[ "$verbose" == "true" ]]; then
        log_info "Request: $method $url"
        [[ -n "$data" ]] && log_debug "Body: $data"
    fi

    # API呼び出し
    local response
    response=$(curl "${curl_opts[@]}" "$url" 2>&1) || {
        log_error "curl実行エラー"
        exit 1
    }

    # レスポンスとステータスコードを分離
    local http_code
    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | sed '$d')

    # ステータスコードのみ
    if [[ "$status_only" == "true" ]]; then
        echo "$http_code"
        return 0
    fi

    # 結果出力
    if [[ "$verbose" == "true" ]]; then
        log_info "HTTP Status: $http_code"
    fi

    # HTTPステータスチェック
    if [[ "$http_code" -ge 400 ]]; then
        log_error "HTTP $http_code"
        if [[ "$raw" == "true" ]]; then
            echo "$body"
        else
            echo "$body" | jq . 2>/dev/null || echo "$body"
        fi
        return 1
    fi

    # JSON整形出力
    if [[ "$raw" == "true" ]]; then
        echo "$body"
    else
        echo "$body" | jq . 2>/dev/null || echo "$body"
    fi

    return 0
}

# メイン処理
main() {
    [[ $# -lt 2 ]] && usage

    local method
    method=$(echo "$1" | tr '[:lower:]' '[:upper:]')  # 大文字変換
    local path="$2"
    shift 2

    local data=""
    local query=""
    local raw="false"
    local status_only="false"
    local verbose="false"

    # オプション解析
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--data)
                data="$2"
                shift 2
                ;;
            -f|--file)
                data=$(cat "$2")
                shift 2
                ;;
            -q|--query)
                query="$2"
                shift 2
                ;;
            --raw)
                raw="true"
                shift
                ;;
            --status-only)
                status_only="true"
                shift
                ;;
            -v|--verbose)
                verbose="true"
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                log_error "不明なオプション: $1"
                usage
                ;;
        esac
    done

    load_config
    call_api "$method" "$path" "$data" "$query" "$raw" "$status_only" "$verbose"
}

main "$@"
