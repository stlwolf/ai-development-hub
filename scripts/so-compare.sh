#!/usr/bin/env bash
# so-compare.sh - セカンドオピニオン比較実行スクリプト（使い捨て可）
# 同一プロンプトを Codex CLI / Claude Code / Cursor CLI (agent) に投げて結果をファイルに保存する

set -euo pipefail

usage() {
    cat <<'USAGE'
Usage:
  so-compare.sh "プロンプトテキスト"
  so-compare.sh -f prompt.txt
  echo "プロンプト" | so-compare.sh -

Options:
  -f FILE        プロンプトをファイルから読み込み
  -c FILE...     コンテキストファイルを添付（プロンプトに内容を追記）
                 注意: -c はプロンプト肥大化の原因になるため非推奨。-w の使用を推奨
  -w PATH        ワークスペースパス（Codex/Claude にパス参照で渡す）
  -o DIR         出力ディレクトリを指定（デフォルト: tmp/so-YYYYMMDD-HHMMSS）
  -s MODE        Codex sandbox モード（デフォルト: read-only）
  --with LIST    実行プロバイダを明示指定（カンマ区切り: codex,claude,cursor）
                 例: --with codex,cursor / --with claude,cursor
                 --codex-only 等のレガシーフラグとは併用不可
  --codex-only   Codex のみ実行
  --claude-only  Claude のみ実行
  --cursor       Cursor CLI (agent) も実行（デフォルト: 無効）
  --cursor-only  Cursor のみ実行
  --cursor-model MODEL  Cursor で使用するモデル（デフォルト: auto）
  --claude-model MODEL  Claude で使用するモデル（エイリアス opus/sonnet/haiku 可。デフォルト: CLI 既定）
  --codex-model MODEL   Codex で使用するモデル（デフォルト: CLI 既定）
  --claude-effort LEVEL Claude のエフォート level（low/medium/high/xhigh/max。デフォルト: CLI 既定）
  --claude-web   Claude Code に WebFetch を許可（-p モードで外部URL参照を要するタスク用）
  --prev DIR     前回の so-compare 出力ディレクトリ
                 回答をプロンプトに追記（上限: PREV_MAX_BYTES, デフォルト4000）
  -h, --help     このヘルプを表示

Environment:
  PREV_MAX_BYTES   --prev で追記する回答の上限バイト数（デフォルト: 4000）
  SO_TIMEOUT       codex / cursor のタイムアウト秒数（整数、デフォルト: 240）
  SO_CLAUDE_TIMEOUT claude のタイムアウト秒数（整数、デフォルト: 900）
                   claude は同じプロンプトでも他レーンの2倍以上かかるため既定を分けている
  SO_CURSOR_MODEL  Cursor のデフォルトモデル（デフォルト: auto。--cursor-model で上書き可）
  SO_CLAUDE_MODEL  Claude のデフォルトモデル（--claude-model で上書き可）
  SO_CODEX_MODEL   Codex のデフォルトモデル（--codex-model で上書き可）
  SO_CLAUDE_EFFORT Claude のデフォルトエフォート（--claude-effort で上書き可）

Exit codes:
  0  全プロバイダ成功
  1  部分成功（一部のプロバイダのみ応答）
  2  全プロバイダ失敗
USAGE
}

# --- 設定 ---
CODEX_CMD="codex"
CLAUDE_CMD="claude-safe"
CURSOR_CMD="agent"
SANDBOX_MODE="read-only"
OUT_DIR=""
PROMPT=""
CONTEXT_FILES=()
PREV_DIR=""
WORKSPACE=""
RUN_CODEX=true
RUN_CLAUDE=true
RUN_CURSOR=false
PROVIDERS_RAW=""
WITH_SPECIFIED=false
LEGACY_PROVIDER_FLAG=false
CLAUDE_WEB=false
CURSOR_MODEL="${SO_CURSOR_MODEL:-auto}"
CLAUDE_MODEL="${SO_CLAUDE_MODEL:-}"
CODEX_MODEL="${SO_CODEX_MODEL:-}"
CLAUDE_EFFORT="${SO_CLAUDE_EFFORT:-}"
SO_TIMEOUT="${SO_TIMEOUT:-240}"
# claude は同じプロンプトでも他レーンの2〜3倍の時間を要する（実測値は
# canonical/skills/so-compare/SKILL.md に記載）。共通の既定（240秒）では初回も
# リトライ（×1.5 = 360秒）も届かないため、claude だけが構造的に返らず、
# 「この環境では claude レーンは返らない」という誤った通説ができていた。
# 環境が非対応なのではなく、単にタイムアウトが短かった（#295）。
#
# 既定 1200秒 の根拠: レビュー級のプロンプト2件で 652秒 と 777秒 を実測した。
# 所要はプロンプトの大きさではなく要求される分析の深さで決まり（小さいほうの
# プロンプトが長くかかった）、事前に読みにくい。最大実測 777秒 に対して約54%の
# 余裕を取っている。
SO_CLAUDE_TIMEOUT="${SO_CLAUDE_TIMEOUT:-1200}"
SO_RETRY_TIMEOUT_FACTOR=1.5

# タイムアウト値は timeout コマンドと awk の両方へ渡る。非数値だと awk が 0 を返し、
# リトライが `timeout 0`（＝無制限）になって永久に待つ。入口で弾く。
for _t_var in SO_TIMEOUT SO_CLAUDE_TIMEOUT; do
    if [[ ! "${!_t_var}" =~ ^[1-9][0-9]*$ ]]; then
        echo "Error: ${_t_var} は正の整数（秒）で指定してください: ${!_t_var}" >&2
        exit 1
    fi
done
unset _t_var

# レーンごとの基準タイムアウト。リトライ時間の算出にも使う。
base_timeout_for() {
    case "$1" in
        claude) printf '%s\n' "$SO_CLAUDE_TIMEOUT" ;;
        *)      printf '%s\n' "$SO_TIMEOUT" ;;
    esac
}

# --- カラー出力（tty 時のみ） ---
if [[ -t 1 ]]; then
    C_RED='\033[1;31m'
    C_YELLOW='\033[1;33m'
    C_GREEN='\033[0;32m'
    C_RESET='\033[0m'
else
    C_RED='' C_YELLOW='' C_GREEN='' C_RESET=''
fi

# --- 引数解析 ---
require_arg() {
    if [[ $# -lt 2 || "$2" =~ ^- ]]; then
        echo "Error: $1 にはアーギュメントが必要です" >&2
        exit 1
    fi
}

trim_ws() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

apply_providers() {
    RUN_CODEX=false
    RUN_CLAUDE=false
    RUN_CURSOR=false
    local seen=()
    local parts=()
    local raw p s

    IFS=',' read -r -a parts <<< "$PROVIDERS_RAW"
    for raw in "${parts[@]}"; do
        p=$(trim_ws "$raw")
        if [[ -z "$p" ]]; then
            echo "Error: --with のプロバイダリストに空要素があります" >&2
            exit 1
        fi
        if [[ ${#seen[@]} -gt 0 ]]; then
            for s in "${seen[@]}"; do
                if [[ "$s" == "$p" ]]; then
                    echo "Error: プロバイダが重複しています: $p" >&2
                    exit 1
                fi
            done
        fi
        seen+=("$p")
        case "$p" in
            codex)  RUN_CODEX=true ;;
            claude) RUN_CLAUDE=true ;;
            cursor) RUN_CURSOR=true ;;
            *)
                echo "Error: 未知のプロバイダ: ${p} (codex / claude / cursor を指定)" >&2
                exit 1
                ;;
        esac
    done
    if [[ ${#seen[@]} -eq 0 ]]; then
        echo "Error: --with に有効なプロバイダが指定されていません" >&2
        exit 1
    fi
}

providers_label() {
    local labels=()
    $RUN_CODEX && labels+=(codex)
    $RUN_CLAUDE && labels+=(claude)
    $RUN_CURSOR && labels+=(cursor)
    local IFS=','
    echo "${labels[*]}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f)
            require_arg "$1" "${2:-}"
            PROMPT=$(cat "$2")
            shift 2
            ;;
        -c)
            shift
            while [[ $# -gt 0 && ! "$1" =~ ^- ]]; do
                CONTEXT_FILES+=("$1")
                shift
            done
            ;;
        -w)
            require_arg "$1" "${2:-}"
            WORKSPACE="$2"
            shift 2
            ;;
        -o)
            require_arg "$1" "${2:-}"
            OUT_DIR="$2"
            shift 2
            ;;
        -s)
            require_arg "$1" "${2:-}"
            SANDBOX_MODE="$2"
            shift 2
            ;;
        --with)
            require_arg "$1" "${2:-}"
            PROVIDERS_RAW="$2"
            WITH_SPECIFIED=true
            shift 2
            ;;
        --codex-only)
            LEGACY_PROVIDER_FLAG=true
            RUN_CLAUDE=false
            RUN_CURSOR=false
            shift
            ;;
        --claude-only)
            LEGACY_PROVIDER_FLAG=true
            RUN_CODEX=false
            RUN_CURSOR=false
            shift
            ;;
        --cursor)
            LEGACY_PROVIDER_FLAG=true
            RUN_CURSOR=true
            shift
            ;;
        --cursor-only)
            LEGACY_PROVIDER_FLAG=true
            RUN_CODEX=false
            RUN_CLAUDE=false
            RUN_CURSOR=true
            shift
            ;;
        --cursor-model)
            require_arg "$1" "${2:-}"
            CURSOR_MODEL="$2"
            shift 2
            ;;
        --claude-model)
            require_arg "$1" "${2:-}"
            CLAUDE_MODEL="$2"
            shift 2
            ;;
        --codex-model)
            require_arg "$1" "${2:-}"
            CODEX_MODEL="$2"
            shift 2
            ;;
        --claude-effort)
            require_arg "$1" "${2:-}"
            CLAUDE_EFFORT="$2"
            shift 2
            ;;
        --claude-web)
            CLAUDE_WEB=true
            shift
            ;;
        --prev)
            require_arg "$1" "${2:-}"
            PREV_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -)
            PROMPT=$(cat)
            shift
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
        *)
            PROMPT="$1"
            shift
            ;;
    esac
done

if [[ -z "$PROMPT" ]]; then
    echo "Error: プロンプトが指定されていません" >&2
    echo "" >&2
    usage >&2
    exit 1
fi

if $LEGACY_PROVIDER_FLAG && $WITH_SPECIFIED; then
    echo "Error: --with は --codex-only / --claude-only / --cursor-only / --cursor と併用できません" >&2
    exit 1
fi

if $WITH_SPECIFIED; then
    if [[ -z "$PROVIDERS_RAW" ]]; then
        echo "Error: --with にはプロバイダリストが必要です (例: codex,cursor)" >&2
        exit 1
    fi
    apply_providers
fi

if ! $RUN_CODEX && ! $RUN_CLAUDE && ! $RUN_CURSOR; then
    echo "Error: 実行対象のプロバイダがありません（--codex-only と --claude-only の同時指定等）" >&2
    exit 1
fi

# --- コマンド存在チェック ---
if ! command -v timeout &>/dev/null; then
    echo "Error: timeout コマンドが見つかりません。macOS の場合: brew install coreutils" >&2
    exit 1
fi
if $RUN_CODEX && ! command -v "$CODEX_CMD" &>/dev/null; then
    echo "Error: $CODEX_CMD が見つかりません。--claude-only で Claude のみ実行できます。" >&2
    exit 1
fi
if $RUN_CLAUDE && ! command -v "$CLAUDE_CMD" &>/dev/null; then
    echo "Error: $CLAUDE_CMD が見つかりません。--codex-only で Codex のみ実行できます。" >&2
    exit 1
fi
if $RUN_CURSOR && ! command -v "$CURSOR_CMD" &>/dev/null; then
    echo "Error: $CURSOR_CMD が見つかりません。--cursor を外すか、agent CLI をインストールしてください。" >&2
    exit 1
fi

# claude の解決後モデル記録（#295）は --output-format json と jq に依存する。
# jq が無ければ従来どおり text 形式で実行する。モデル記録は付随情報であり、
# そのために回答本文の取得を落とすことはしない。
CLAUDE_JSON_MODE=true
if ! command -v jq &>/dev/null; then
    CLAUDE_JSON_MODE=false
fi

# --- ワークスペースパスをプロンプトに追記 ---
if [[ -n "$WORKSPACE" ]]; then
    PROMPT="${PROMPT}"$'\n\nワークスペース: '"$WORKSPACE"$'\n上記パス配下のファイルを参照して回答してください。'
fi

# --- コンテキストファイルの内容をプロンプトに追記 ---
if [[ ${#CONTEXT_FILES[@]} -gt 0 ]]; then
    echo "Warning: -c はプロンプト肥大化の原因になります。-w でワークスペースパスを渡す方式を推奨します。" >&2
    PROMPT="${PROMPT}"$'\n\n--- 添付コンテキスト ---'
    for f in "${CONTEXT_FILES[@]}"; do
        if [[ -f "$f" ]]; then
            PROMPT="${PROMPT}"$'\n\n'"### ${f}"$'\n```\n'"$(cat "$f")"$'\n```'
        else
            echo "Warning: ファイルが見つかりません: $f" >&2
        fi
    done
fi

# --- 前回の回答をプロンプトに追記 ---
PREV_MAX_BYTES="${PREV_MAX_BYTES:-4000}"

if [[ -n "$PREV_DIR" ]]; then
    if [[ ! -d "$PREV_DIR" ]]; then
        echo "Warning: 前回の出力ディレクトリが見つかりません: $PREV_DIR" >&2
    else
        PROMPT="${PROMPT}"$'\n\n--- 前回のレビュー回答（参考） ---'
        for tool in codex claude cursor; do
            prev_file="$PREV_DIR/${tool}-stdout.txt"
            if [[ -f "$prev_file" && -s "$prev_file" ]]; then
                prev_content=$(head -c "$PREV_MAX_BYTES" "$prev_file")
                orig_size=$(wc -c < "$prev_file" | tr -d ' ')
                if (( orig_size > PREV_MAX_BYTES )); then
                    prev_content="${prev_content}"$'\n\n[... truncated: '"${orig_size}"' bytes -> '"${PREV_MAX_BYTES}"' bytes ...]'
                fi
                PROMPT="${PROMPT}"$'\n\n'"### 前回の ${tool} の回答"$'\n```\n'"${prev_content}"$'\n```'
            fi
        done
    fi
fi

# --- 出力ディレクトリ ---
if [[ -z "$OUT_DIR" ]]; then
    OUT_DIR="tmp/so-$(date +%Y%m%d-%H%M%S)"
fi
mkdir -p "$OUT_DIR"

# --- プロンプト保存 ---
echo "$PROMPT" > "$OUT_DIR/prompt.txt"

# --- プロンプトサイズ警告 ---
PROMPT_BYTES=$(echo "$PROMPT" | wc -c | tr -d ' ')
if (( PROMPT_BYTES > 50000 )); then
    echo "Warning: プロンプトサイズが ${PROMPT_BYTES} bytes（>50KB）です。タイムアウトやアンカリングの原因になります。-w の使用を検討してください。" >&2
fi

echo "=== Second Opinion Comparison ==="
echo "出力先: $OUT_DIR"
echo "sandbox: $SANDBOX_MODE"
if [[ -n "$WORKSPACE" ]]; then
    echo "ワークスペース: $WORKSPACE"
fi
echo "プロバイダ: $(providers_label)"
if $RUN_CURSOR; then
    echo "Cursor: enabled${CURSOR_MODEL:+ (model: $CURSOR_MODEL)}"
fi
if $RUN_CODEX && [[ -n "$CODEX_MODEL" ]]; then
    echo "Codex: model=$CODEX_MODEL"
fi
if $RUN_CLAUDE && [[ -n "$CLAUDE_MODEL$CLAUDE_EFFORT" ]]; then
    echo "Claude:${CLAUDE_MODEL:+ model=$CLAUDE_MODEL}${CLAUDE_EFFORT:+ effort=$CLAUDE_EFFORT}"
fi
echo "タイムアウト: codex/cursor=${SO_TIMEOUT}秒 claude=${SO_CLAUDE_TIMEOUT}秒"
echo "プロンプト長: $(echo "$PROMPT" | wc -c | tr -d ' ') bytes"
echo ""

# --- 結果分類 ---
# exit_code と stdout の有無から状態を判定する
classify_result() {
    local tool="$1" exit_code="$2"
    local stdout_file="$OUT_DIR/${tool}-stdout.txt"
    if [[ "$exit_code" -eq 0 ]]; then
        if [[ -s "$stdout_file" ]]; then
            echo "success"
        else
            echo "success_empty"
        fi
    elif [[ "$exit_code" -eq 124 ]]; then
        if [[ -s "$stdout_file" ]]; then
            echo "timeout_partial"
        else
            echo "timeout_empty"
        fi
    else
        if [[ -s "$stdout_file" ]]; then
            echo "error_partial"
        else
            echo "error"
        fi
    fi
}

resolve_codex_model() {
    local requested="$1"
    if [[ -n "$requested" ]]; then
        printf '%s\n' "$requested"
        return 0
    fi

    local config_path="${CODEX_HOME:-$HOME/.codex}/config.toml"
    local resolved=""
    if [[ -f "$config_path" ]]; then
        resolved="$(
            awk '
                /^[[:space:]]*\[/ { exit }
                /^[[:space:]]*model[[:space:]]*=/ {
                    sub(/^[[:space:]]*model[[:space:]]*=[[:space:]]*/, "")
                    sub(/[[:space:]]*(#.*)?$/, "")
                    if ($0 ~ /^".*"$/) {
                        sub(/^"/, "")
                        sub(/"$/, "")
                    } else if ($0 ~ /^\047.*\047$/) {
                        sub(/^\047/, "")
                        sub(/\047$/, "")
                    }
                    print
                    exit
                }
            ' "$config_path"
        )"
    fi

    if [[ -n "$resolved" ]]; then
        printf '%s\n' "$resolved"
    else
        printf 'unknown\n'
    fi
}

# --- claude の解決後モデル抽出（#295） ---
#
# claude の --output-format json は .modelUsage を返す。これは「実際に使われた
# モデル ID」をキーに持つオブジェクトで、エイリアス（opus / sonnet 等）と CLI 既定が
# 解決された後の値である。要求値からは確定できない情報がここで確定する。
#
# 注意が2点ある。
#  1. .modelUsage は補助用途のモデル（haiku 等）を含む複数キーを持つ。回答を書いた
#     主モデルを選ぶ必要があるので、トークン投入量（input + cache 読み + cache 作成）が
#     最大のものを主モデルとする。選定が経験則である以上 models_all も併記し、
#     後から検証できるようにする。
#  2. 取得できなかった場合、環境エラー（jq が動かない）とデータ不在（.modelUsage が
#     無い）を別種別として記録する。ここを潰すと「記録漏れ」と「取得不能」が
#     区別できなくなり、#295 が塞ごうとしている穴を実装側で再生産する。
#
# 結果は以下のグローバルへ格納する。
#   CLAUDE_MODEL_RESOLVED : 解決後モデル ID または unavailable:<種別>
#   CLAUDE_MODELS_ALL     : 使われた全モデル ID（カンマ区切り）または unavailable:<種別>
extract_claude_models() {
    local raw="$1" errf="$2"
    local rc=0

    CLAUDE_MODEL_RESOLVED="unavailable:parse-failed"
    CLAUDE_MODELS_ALL="unavailable:parse-failed"

    if ! command -v jq &>/dev/null; then
        CLAUDE_MODEL_RESOLVED="unavailable:query-failed"
        CLAUDE_MODELS_ALL="unavailable:query-failed"
        return 0
    fi
    if [[ ! -s "$raw" ]]; then
        CLAUDE_MODEL_RESOLVED="unavailable:parse-failed"
        CLAUDE_MODELS_ALL="unavailable:parse-failed"
        return 0
    fi

    # 入力が JSON として読めるか確認する。読めない場合、それが「出力が壊れている」のか
    # 「jq 自体が動かない」のかを canary で切り分ける。推測で種別を決めない。
    jq -e 'type == "object"' "$raw" >/dev/null 2>>"$errf" || rc=$?
    if [[ $rc -ne 0 ]]; then
        local canary_rc=0
        printf '{}' | jq -e 'type == "object"' >/dev/null 2>>"$errf" || canary_rc=$?
        if [[ $canary_rc -ne 0 ]]; then
            # jq は存在するが正常に動作していない = 環境エラー
            CLAUDE_MODEL_RESOLVED="unavailable:query-failed"
            CLAUDE_MODELS_ALL="unavailable:query-failed"
        else
            # jq は動く。つまり入力側が JSON として壊れている
            CLAUDE_MODEL_RESOLVED="unavailable:parse-failed"
            CLAUDE_MODELS_ALL="unavailable:parse-failed"
        fi
        return 0
    fi

    # JSON としては読めた。次は .modelUsage の有無を見る。
    # jq -e は「判定が false」なら 1、「実行に失敗」なら 2 以上を返す。この差が
    # そのままデータ不在と環境エラーの差なので、まとめて非ゼロ扱いにしない。
    rc=0
    jq -e 'has("modelUsage") and (.modelUsage | type == "object") and (.modelUsage | length > 0)' \
        "$raw" >/dev/null 2>>"$errf" || rc=$?
    if [[ $rc -eq 1 ]]; then
        # 判定が正常に false を返した = データ不在
        CLAUDE_MODEL_RESOLVED="unavailable:no-modelusage"
        CLAUDE_MODELS_ALL="unavailable:no-modelusage"
        return 0
    elif [[ $rc -ne 0 ]]; then
        # jq の実行自体が失敗した = 環境エラー
        CLAUDE_MODEL_RESOLVED="unavailable:query-failed"
        CLAUDE_MODELS_ALL="unavailable:query-failed"
        return 0
    fi

    # ここから先は .modelUsage が存在することが確定している。したがって以降の
    # 失敗はデータ不在ではなく、想定した形になっていないことを意味する。
    # 例: inputTokens が数値でないと max_by が加算に失敗する。
    local primary="" all=""
    rc=0
    primary="$(jq -r '
        .modelUsage
        | to_entries
        | max_by(
            ((.value.inputTokens // 0)
             + (.value.cacheReadInputTokens // 0)
             + (.value.cacheCreationInputTokens // 0))
          )
        | .key
    ' "$raw" 2>>"$errf")" || rc=$?
    if [[ $rc -ne 0 || -z "$primary" || "$primary" == "null" ]]; then
        CLAUDE_MODEL_RESOLVED="unavailable:schema-unexpected"
        CLAUDE_MODELS_ALL="unavailable:schema-unexpected"
        return 0
    fi

    rc=0
    all="$(jq -r '.modelUsage | keys | join(",")' "$raw" 2>>"$errf")" || rc=$?
    if [[ $rc -ne 0 || -z "$all" ]]; then
        # 主モデルで代用すると失敗が消えるので、失敗は失敗として残す
        all="unavailable:schema-unexpected"
    fi

    # meta は 1 行 key=value で読まれる（grep '^key=' | cut -d= -f2）。値に = や
    # 改行や空白が混ざると行が壊れるので、書く前に形を確かめる。モデル ID は
    # 外部から来る文字列であり、こちらで保証できるものではない。
    # パイプで grep へ渡すと早期終了 consumer になるため、bash の正規表現で完結させる。
    if [[ ! "$primary" =~ ^[A-Za-z0-9._:+-]+$ ]]; then
        primary="unavailable:schema-unexpected"
    fi
    if [[ "$all" != unavailable:* && ! "$all" =~ ^[A-Za-z0-9._:+,-]+$ ]]; then
        all="unavailable:schema-unexpected"
    fi

    CLAUDE_MODEL_RESOLVED="$primary"
    CLAUDE_MODELS_ALL="$all"
    return 0
}

# claude の json 出力から回答本文だけを取り出して stdout.txt へ書く。
#
# <tool>-stdout.txt は so-verdict.sh（oe-refute / oe-review）が VERDICT / REASON を
# 抽出する入力であり、skill / command からも回答本文として読まれる。したがって
# 出力形式を json にしても、このファイルは平文の本文でなければならない。
#
# 取り出せなかった場合、stdout は空のままにする。生の json をここへ複写しては
# いけない。理由が2つある。
#  1. 生 json をここへ書くと、この平文契約が破れたまま so-verdict.sh の入力になる。
#  2. 途中で切れた json は非空なので classify_result が timeout_partial と判定し、
#     timeout_empty 限定のリトライが起きなくなる。text 形式のころの部分出力は
#     そのまま読める回答だったが、壊れた json は回答として使えない。使えない
#     ものを「部分的に成功」と扱うと、再取得の機会まで失う。
# 生の出力は claude-raw.json に残るので、内容が失われるわけではない。
# 戻り値: 0 = 取り出せた / 1 = 取り出せなかった（stdout は空）
extract_claude_body() {
    local raw="$1" dest="$2" errf="$3"
    local rc=0

    : > "$dest"
    if ! command -v jq &>/dev/null || [[ ! -s "$raw" ]]; then
        return 1
    fi

    # .result が文字列のときだけ受け取る。object や array を jq -r に渡すと
    # JSON を整形して出力してしまい、平文のはずの stdout.txt が JSON になる。
    jq -r 'if has("result") and (.result | type == "string") then .result else empty end' \
        "$raw" > "${dest}.tmp" 2>>"$errf" || rc=$?

    if [[ $rc -eq 0 && -s "${dest}.tmp" ]]; then
        mv "${dest}.tmp" "$dest"
        return 0
    fi

    rm -f "${dest}.tmp"
    return 1
}

# --- 実行関数 ---
# shellcheck disable=SC2120  # 引数はリトライ時に渡される（初回はデフォルト値を使用）
run_codex() {
    local tool_timeout="${1:-$SO_TIMEOUT}"
    echo "[Codex] 実行中... (timeout=${tool_timeout}秒)"
    local start end elapsed exit_code
    start=$(date +%s)

    local codex_args=("exec" "-s" "$SANDBOX_MODE")
    if [[ -n "$CODEX_MODEL" ]]; then
        codex_args+=("--model" "$CODEX_MODEL")
    fi
    if [[ -n "$WORKSPACE" ]]; then
        codex_args+=("-C" "$WORKSPACE")
    fi

    if timeout "$tool_timeout" "$CODEX_CMD" "${codex_args[@]}" "$PROMPT" \
        > "$OUT_DIR/codex-stdout.txt" 2> "$OUT_DIR/codex-stderr.txt"; then
        exit_code=0
    else
        exit_code=$?
    fi

    end=$(date +%s)
    elapsed=$((end - start))

    local timeout_status
    timeout_status=$(classify_result "codex" "$exit_code")
    local model_resolved
    model_resolved="$(resolve_codex_model "$CODEX_MODEL")"

    echo "[Codex] 完了 (${elapsed}秒, exit=${exit_code}, status=${timeout_status})"

    {
        echo "tool=codex"
        echo "model_requested=${CODEX_MODEL:-default}"
        echo "model_resolved=$model_resolved"
        # codex の model_resolved は resolve_codex_model() が要求値または
        # ~/.codex/config.toml を読んで組み立てた値であり、実行後の観測ではない。
        # レーンによって model_resolved の確からしさが違うので出所を明示する（#295）。
        echo "model_resolved_source=config"
        echo "exit_code=$exit_code"
        echo "timeout_status=$timeout_status"
        echo "elapsed_seconds=$elapsed"
        echo "stdout_lines=$(wc -l < "$OUT_DIR/codex-stdout.txt" | tr -d ' ')"
        echo "stdout_bytes=$(wc -c < "$OUT_DIR/codex-stdout.txt" | tr -d ' ')"
    } > "$OUT_DIR/codex-meta.txt"
}

# shellcheck disable=SC2120
run_claude() {
    local tool_timeout="${1:-$SO_CLAUDE_TIMEOUT}"
    echo "[Claude] 実行中... (timeout=${tool_timeout}秒)"
    local start end elapsed exit_code
    start=$(date +%s)

    local claude_args=("-p")
    if [[ -n "$CLAUDE_MODEL" ]]; then
        claude_args+=("--model" "$CLAUDE_MODEL")
    fi
    if [[ -n "$CLAUDE_EFFORT" ]]; then
        claude_args+=("--effort" "$CLAUDE_EFFORT")
    fi
    if [[ -n "$WORKSPACE" ]]; then
        claude_args+=("--add-dir" "$WORKSPACE")
    fi
    # 解決後モデルを記録するため json で受ける（#295）。jq が無い環境では
    # 従来どおり text で受け、モデル記録だけを諦める。
    if $CLAUDE_JSON_MODE; then
        claude_args+=("--output-format" "json")
    else
        claude_args+=("--output-format" "text")
    fi
    if $CLAUDE_WEB; then
        # -p (print) モードは対話的承認ができないため、WebFetch を明示許可する必要がある
        claude_args+=("--allowed-tools=WebFetch")
    fi

    local claude_capture="$OUT_DIR/claude-stdout.txt"
    local claude_errmeta="$OUT_DIR/claude-modelmeta-stderr.txt"
    if $CLAUDE_JSON_MODE; then
        claude_capture="$OUT_DIR/claude-raw.json"
        : > "$claude_errmeta"
    fi

    if timeout "$tool_timeout" "$CLAUDE_CMD" "${claude_args[@]}" "$PROMPT" \
        > "$claude_capture" 2> "$OUT_DIR/claude-stderr.txt"; then
        exit_code=0
    else
        exit_code=$?
    fi

    end=$(date +%s)
    elapsed=$((end - start))

    # 本文の取り出しとモデル抽出は classify_result より前に行う。
    # classify_result は claude-stdout.txt の非空判定に依存しているため。
    local body_source="direct"
    local model_source="none"
    CLAUDE_MODEL_RESOLVED="unavailable:query-failed"
    CLAUDE_MODELS_ALL="unavailable:query-failed"
    if $CLAUDE_JSON_MODE; then
        model_source="cli-json"
        if extract_claude_body "$claude_capture" "$OUT_DIR/claude-stdout.txt" "$claude_errmeta"; then
            body_source="json-result"
        else
            # 本文は取り出せなかった。stdout は空なので classify_result は
            # success_empty / timeout_empty 側へ落ち、リトライ判定も正しく働く。
            # 生の出力は claude-raw.json に残っている。
            body_source="extract-failed"
        fi
        extract_claude_models "$claude_capture" "$claude_errmeta"
        # 診断が出ていなければ空ファイルを残さない
        [[ -s "$claude_errmeta" ]] || rm -f "$claude_errmeta"
    fi

    local timeout_status
    timeout_status=$(classify_result "claude" "$exit_code")

    echo "[Claude] 完了 (${elapsed}秒, exit=${exit_code}, status=${timeout_status})"

    {
        echo "tool=claude"
        echo "model_requested=${CLAUDE_MODEL:-default}"
        echo "effort_requested=${CLAUDE_EFFORT:-default}"
        echo "model_resolved=$CLAUDE_MODEL_RESOLVED"
        echo "models_all=$CLAUDE_MODELS_ALL"
        echo "model_resolved_source=$model_source"
        echo "body_source=$body_source"
        echo "exit_code=$exit_code"
        echo "timeout_status=$timeout_status"
        echo "elapsed_seconds=$elapsed"
        echo "stdout_lines=$(wc -l < "$OUT_DIR/claude-stdout.txt" | tr -d ' ')"
        echo "stdout_bytes=$(wc -c < "$OUT_DIR/claude-stdout.txt" | tr -d ' ')"
    } > "$OUT_DIR/claude-meta.txt"
}

# shellcheck disable=SC2120
run_cursor() {
    local tool_timeout="${1:-$SO_TIMEOUT}"
    echo "[Cursor] 実行中... (timeout=${tool_timeout}秒)"
    local start end elapsed exit_code
    start=$(date +%s)

    local cursor_args=(-p -f --mode ask --output-format text)
    if [[ -n "$CURSOR_MODEL" ]]; then
        cursor_args+=(--model "$CURSOR_MODEL")
    fi
    if [[ -n "$WORKSPACE" ]]; then
        cursor_args+=(--workspace "$WORKSPACE")
    fi

    if timeout "$tool_timeout" nohup "$CURSOR_CMD" "${cursor_args[@]}" "$PROMPT" \
        > "$OUT_DIR/cursor-stdout.txt" 2> "$OUT_DIR/cursor-stderr.txt"; then
        exit_code=0
    else
        exit_code=$?
    fi

    end=$(date +%s)
    elapsed=$((end - start))

    local timeout_status
    timeout_status=$(classify_result "cursor" "$exit_code")

    echo "[Cursor] 完了 (${elapsed}秒, exit=${exit_code}, status=${timeout_status})"

    {
        echo "tool=cursor"
        echo "model_requested=${CURSOR_MODEL:-default}"
        # cursor CLI は解決後のモデルを出力しない。json / stream-json に出る model は
        # 表示名（既定の auto では "Auto Balance"）であって具体的なモデル ID ではない。
        # 具体名は Cursor 内部の SQLite（~/.cursor/chats/**/store.db）にあるが、
        # 非公開の内部形式なので自動では依存しない（owner 判断・#295）。
        # 手動で辿る手順は canonical/skills/so-compare/SKILL.md に記載している。
        # 空欄にはしない。空欄だと記録漏れと取得不能が区別できなくなる。
        echo "model_resolved=unavailable:cli-not-exposed"
        echo "model_resolved_source=none"
        echo "exit_code=$exit_code"
        echo "timeout_status=$timeout_status"
        echo "elapsed_seconds=$elapsed"
        echo "stdout_lines=$(wc -l < "$OUT_DIR/cursor-stdout.txt" | tr -d ' ')"
        echo "stdout_bytes=$(wc -c < "$OUT_DIR/cursor-stdout.txt" | tr -d ' ')"
    } > "$OUT_DIR/cursor-meta.txt"
}

# --- 実行 ---
if $RUN_CODEX; then
    run_codex &
    CODEX_PID=$!
fi

if $RUN_CLAUDE; then
    run_claude &
    CLAUDE_PID=$!
fi

if $RUN_CURSOR; then
    run_cursor &
    CURSOR_PID=$!
fi

# 完了待ち
if $RUN_CODEX; then wait "$CODEX_PID" 2>/dev/null || true; fi
if $RUN_CLAUDE; then wait "$CLAUDE_PID" 2>/dev/null || true; fi
if $RUN_CURSOR; then wait "$CURSOR_PID" 2>/dev/null || true; fi

# --- タイムアウト(出力なし)のリトライ（最大1回） ---
for tool in codex claude cursor; do
    meta="$OUT_DIR/${tool}-meta.txt"
    [[ -f "$meta" ]] || continue
    status=$(grep '^timeout_status=' "$meta" | cut -d= -f2 || true)
    if [[ "$status" == "timeout_empty" ]]; then
        retry_timeout=$(awk "BEGIN {printf \"%.0f\", $(base_timeout_for "$tool") * $SO_RETRY_TIMEOUT_FACTOR}")
        echo ""
        echo -e "${C_YELLOW}[${tool}] タイムアウト（出力なし）→ リトライ (${retry_timeout}秒)${C_RESET}"
        # 元の結果をバックアップ
        # raw.json も退避する。claude は生出力をここに置いており、これが
        # 上書きされると1回目の証跡が消える（#295 は証跡を残すための変更である）。
        # 他のレーンには存在しないが、その場合 cp が失敗するだけで害はない。
        for suffix in meta.txt stdout.txt stderr.txt raw.json; do
            cp "$OUT_DIR/${tool}-${suffix}" "$OUT_DIR/${tool}-${suffix}.attempt1" 2>/dev/null || true
        done
        # 同期リトライ（延長タイムアウト）
        "run_${tool}" "$retry_timeout"
        # リトライ情報を metadata に追記
        {
            echo "retry=1"
            echo "retry_timeout=$retry_timeout"
        } >> "$OUT_DIR/${tool}-meta.txt"
    fi
done

# --- 集計 ---
EXPECTED=0
SUCCEEDED=0
PARTIAL=0
FAILED_COUNT=0
TOOLS_RUN=()

if $RUN_CODEX; then EXPECTED=$((EXPECTED + 1)); TOOLS_RUN+=(codex); fi
if $RUN_CLAUDE; then EXPECTED=$((EXPECTED + 1)); TOOLS_RUN+=(claude); fi
if $RUN_CURSOR; then EXPECTED=$((EXPECTED + 1)); TOOLS_RUN+=(cursor); fi

for tool in "${TOOLS_RUN[@]}"; do
    meta="$OUT_DIR/${tool}-meta.txt"
    if [[ -f "$meta" ]]; then
        ts=$(grep '^timeout_status=' "$meta" | cut -d= -f2 || true)
        case "$ts" in
            success)                                      SUCCEEDED=$((SUCCEEDED + 1)) ;;
            success_empty|timeout_partial|error_partial) PARTIAL=$((PARTIAL + 1)) ;;
            *)                             FAILED_COUNT=$((FAILED_COUNT + 1)) ;;
        esac
    else
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
done

echo ""
echo "=== 結果サマリ ==="
echo "期待: ${EXPECTED}者 / 成功: ${SUCCEEDED} / 部分: ${PARTIAL} / 失敗: ${FAILED_COUNT}"
echo ""

# --- 個別ツール結果 ---
for tool in "${TOOLS_RUN[@]}"; do
    meta="$OUT_DIR/${tool}-meta.txt"
    if [[ -f "$meta" ]]; then
        meta_elapsed=$(grep '^elapsed_seconds=' "$meta" | cut -d= -f2 || true)
        meta_lines=$(grep '^stdout_lines=' "$meta" | cut -d= -f2 || true)
        meta_bytes=$(grep '^stdout_bytes=' "$meta" | cut -d= -f2 || true)
        meta_status=$(grep '^timeout_status=' "$meta" | cut -d= -f2 || true)
        meta_retry=$(grep '^retry=' "$meta" | cut -d= -f2 || true)

        status_label=""
        case "$meta_status" in
            success)         status_label="${C_GREEN}成功${C_RESET}" ;;
            success_empty)   status_label="${C_YELLOW}成功(出力なし)${C_RESET}" ;;
            timeout_partial) status_label="${C_YELLOW}タイムアウト(部分出力あり)${C_RESET}" ;;
            timeout_empty)   status_label="${C_RED}タイムアウト(出力なし)${C_RESET}" ;;
            error_partial)   status_label="${C_YELLOW}エラー(部分出力あり)${C_RESET}" ;;
            error)           status_label="${C_RED}エラー${C_RESET}" ;;
        esac
        retry_label=""
        if [[ "${meta_retry:-}" == "1" ]]; then
            retry_label=" (リトライ済)"
        fi

        echo -e "[$tool] ${meta_elapsed}秒 / ${meta_lines}行 / ${meta_bytes}bytes / ${status_label}${retry_label}"
    fi
done

# --- 警告・エラー ---
if (( PARTIAL > 0 )); then
    echo ""
    echo -e "${C_YELLOW}[WARNING] 部分成功です。${SUCCEEDED}/${EXPECTED} 者のみ完全応答。2者レビューには再実行が必要な場合があります${C_RESET}"
fi
if (( FAILED_COUNT > 0 && SUCCEEDED + PARTIAL == 0 )); then
    echo ""
    echo -e "${C_RED}[ERROR] 全プロバイダ失敗。以下を確認してください:${C_RESET}"
    echo "  - SO_TIMEOUT / SO_CLAUDE_TIMEOUT を増やす（現在: codex/cursor=${SO_TIMEOUT}秒 claude=${SO_CLAUDE_TIMEOUT}秒）"
    echo "  - ネットワーク接続・API キーの状態"
    echo "  - -w でワークスペースパスを渡す方式に切り替え"
fi

echo ""
echo "=== ファイル一覧 ==="
ls -la "$OUT_DIR"/

echo ""
echo "結果確認:"
for tool in "${TOOLS_RUN[@]}"; do
    echo "  cat $OUT_DIR/${tool}-stdout.txt"
done

# --- 構造化 exit code ---
if (( SUCCEEDED == EXPECTED )); then
    exit 0
elif (( SUCCEEDED + PARTIAL > 0 )); then
    exit 1
else
    exit 2
fi
