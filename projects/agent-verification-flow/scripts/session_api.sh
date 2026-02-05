#!/bin/bash
# セッションベースAPI呼び出しスクリプト（Session認証用）
# ブラウザのセッション情報（Cookie + CSRF Token）を使用してREST APIを呼び出す
#
# 使用方法:
#   # 1. ブラウザでログイン後、devtoolsからセッション情報を.sessionに保存
#   # 2. このスクリプトでAPI呼び出し
#   ./session_api.sh GET /api/auth/me
#   ./session_api.sh GET /api/dashboard
#
# セッションファイル (.session) の形式:
#   BEARER_TOKEN=<Bearer token>
#   CSRF_TOKEN=<X-CSRF-Token>
#   COOKIES=<Cookie string>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION_FILE="${SESSION_FILE:-${SCRIPT_DIR}/../.session}"
CONFIG_FILE="${CONFIG_FILE:-${SCRIPT_DIR}/../config.yaml}"

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }

usage() {
    cat <<EOF >&2
使用方法: $(basename "$0") <METHOD> <PATH> [OPTIONS]

引数:
  METHOD    HTTPメソッド (GET, POST, PUT, DELETE)
  PATH      APIパス (/api/auth/me, /api/users など)

オプション:
  -d, --data DATA   リクエストボディ (JSON)
  -v, --verbose     詳細出力
  --raw             JSON整形なし
  -h, --help        ヘルプ

セッション設定:
  .session ファイルに以下を設定:
    BEARER_TOKEN=<token>
    CSRF_TOKEN=<csrf>
    COOKIES=<cookies>

例:
  $(basename "$0") GET /api/auth/me
  $(basename "$0") GET /api/users --verbose
  $(basename "$0") POST /api/items -d '{"name":"test"}'
EOF
    exit 1
}

# セッション読み込み
load_session() {
    if [[ ! -f "$SESSION_FILE" ]]; then
        log_error "セッションファイルが見つかりません: $SESSION_FILE"
        log_info "ブラウザでログイン後、以下の情報を $SESSION_FILE に保存してください:"
        echo "  BEARER_TOKEN=<Authorization Bearer token>" >&2
        echo "  CSRF_TOKEN=<x-csrf-token header value>" >&2
        echo "  COOKIES=<full cookie string>" >&2
        exit 1
    fi

    source "$SESSION_FILE"

    if [[ -z "${BEARER_TOKEN:-}" ]] || [[ -z "${CSRF_TOKEN:-}" ]] || [[ -z "${COOKIES:-}" ]]; then
        log_error "セッションファイルに必要な情報がありません"
        exit 1
    fi

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
            exit 1
        fi
    fi
}

# API呼び出し
call_api() {
    local method="$1"
    local path="$2"
    local data="${3:-}"
    local verbose="${4:-false}"
    local raw="${5:-false}"

    local url="${API_BASE_URL}${path}"

    if [[ "$verbose" == "true" ]]; then
        log_info "Request: $method $url"
    fi

    local curl_opts=(
        -s
        -w "\n__HTTP_STATUS__%{http_code}"
        -X "$method"
        -H "accept: application/json"
        -H "authorization: Bearer $BEARER_TOKEN"
        -H "x-csrf-token: $CSRF_TOKEN"
        -b "$COOKIES"
    )

    [[ -n "$data" ]] && curl_opts+=(-H "Content-Type: application/json" -d "$data")

    local response
    response=$(curl "${curl_opts[@]}" "$url" 2>&1)

    local http_code
    http_code=$(echo "$response" | grep '__HTTP_STATUS__' | sed 's/__HTTP_STATUS__//')
    local body
    body=$(echo "$response" | sed '/__HTTP_STATUS__/d')

    if [[ "$verbose" == "true" ]]; then
        log_info "HTTP Status: $http_code"
    fi

    if [[ "$http_code" -ge 400 ]]; then
        log_error "HTTP $http_code"
        echo "$body" | jq . 2>/dev/null || echo "$body"
        return 1
    fi

    if [[ "$raw" == "true" ]]; then
        echo "$body"
    else
        echo "$body" | jq . 2>/dev/null || echo "$body"
    fi
}

# メイン
main() {
    [[ $# -lt 2 ]] && usage

    local method
    method=$(echo "$1" | tr '[:lower:]' '[:upper:]')
    local path="$2"
    shift 2

    local data=""
    local verbose="false"
    local raw="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--data) data="$2"; shift 2 ;;
            -v|--verbose) verbose="true"; shift ;;
            --raw) raw="true"; shift ;;
            -h|--help) usage ;;
            *) log_error "不明なオプション: $1"; usage ;;
        esac
    done

    load_session
    call_api "$method" "$path" "$data" "$verbose" "$raw"
}

main "$@"
