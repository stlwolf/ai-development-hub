#!/usr/bin/env bash
# so-compare.sh - セカンドオピニオン比較実行スクリプト（使い捨て可）
# 同一プロンプトを Codex CLI / Claude Code に投げて結果をファイルに保存する

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
  --codex-only   Codex のみ実行
  --claude-only  Claude のみ実行
  --prev DIR     前回の so-compare 出力ディレクトリ
                 回答をプロンプトに追記（上限: PREV_MAX_BYTES, デフォルト4000）
  -h, --help     このヘルプを表示

Environment:
  PREV_MAX_BYTES   --prev で追記する回答の上限バイト数（デフォルト: 4000）
  SO_TIMEOUT       各ツールのタイムアウト秒数（デフォルト: 240）
USAGE
}

# --- 設定 ---
CODEX_CMD="codex"
CLAUDE_CMD="claude-safe"
SANDBOX_MODE="read-only"
OUT_DIR=""
PROMPT=""
CONTEXT_FILES=()
PREV_DIR=""
WORKSPACE=""
RUN_CODEX=true
RUN_CLAUDE=true
SO_TIMEOUT="${SO_TIMEOUT:-240}"

# --- 引数解析 ---
require_arg() {
    if [[ $# -lt 2 || "$2" =~ ^- ]]; then
        echo "Error: $1 にはアーギュメントが必要です" >&2
        exit 1
    fi
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
        --codex-only)
            RUN_CLAUDE=false
            shift
            ;;
        --claude-only)
            RUN_CODEX=false
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
        for tool in codex claude; do
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
echo "タイムアウト: ${SO_TIMEOUT}秒"
echo "プロンプト長: $(echo "$PROMPT" | wc -c | tr -d ' ') bytes"
echo ""

# --- 実行関数 ---
run_codex() {
    echo "[Codex] 実行中..."
    local start end elapsed exit_code
    start=$(date +%s)

    local codex_args=("exec" "-s" "$SANDBOX_MODE")
    if [[ -n "$WORKSPACE" ]]; then
        codex_args+=("-C" "$WORKSPACE")
    fi

    if timeout "$SO_TIMEOUT" "$CODEX_CMD" "${codex_args[@]}" "$PROMPT" \
        > "$OUT_DIR/codex-stdout.txt" 2> "$OUT_DIR/codex-stderr.txt"; then
        exit_code=0
    else
        exit_code=$?
    fi

    end=$(date +%s)
    elapsed=$((end - start))

    echo "[Codex] 完了 (${elapsed}秒, exit=${exit_code})"

    {
        echo "tool=codex"
        echo "exit_code=$exit_code"
        echo "elapsed_seconds=$elapsed"
        echo "stdout_lines=$(wc -l < "$OUT_DIR/codex-stdout.txt" | tr -d ' ')"
        echo "stdout_bytes=$(wc -c < "$OUT_DIR/codex-stdout.txt" | tr -d ' ')"
    } > "$OUT_DIR/codex-meta.txt"
}

run_claude() {
    echo "[Claude] 実行中..."
    local start end elapsed exit_code
    start=$(date +%s)

    local claude_args=("-p")
    if [[ -n "$WORKSPACE" ]]; then
        claude_args+=("--add-dir" "$WORKSPACE")
    fi
    claude_args+=("--output-format" "text")

    if timeout "$SO_TIMEOUT" "$CLAUDE_CMD" "${claude_args[@]}" "$PROMPT" \
        > "$OUT_DIR/claude-stdout.txt" 2> "$OUT_DIR/claude-stderr.txt"; then
        exit_code=0
    else
        exit_code=$?
    fi

    end=$(date +%s)
    elapsed=$((end - start))

    echo "[Claude] 完了 (${elapsed}秒, exit=${exit_code})"

    {
        echo "tool=claude"
        echo "exit_code=$exit_code"
        echo "elapsed_seconds=$elapsed"
        echo "stdout_lines=$(wc -l < "$OUT_DIR/claude-stdout.txt" | tr -d ' ')"
        echo "stdout_bytes=$(wc -c < "$OUT_DIR/claude-stdout.txt" | tr -d ' ')"
    } > "$OUT_DIR/claude-meta.txt"
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

# 完了待ち
if $RUN_CODEX; then wait "$CODEX_PID" 2>/dev/null || true; fi
if $RUN_CLAUDE; then wait "$CLAUDE_PID" 2>/dev/null || true; fi

echo ""
echo "=== 結果サマリ ==="

# --- サマリ出力 ---
for tool in codex claude; do
    meta="$OUT_DIR/${tool}-meta.txt"
    if [[ -f "$meta" ]]; then
        meta_exit_code=$(grep '^exit_code=' "$meta" | cut -d= -f2)
        meta_elapsed=$(grep '^elapsed_seconds=' "$meta" | cut -d= -f2)
        meta_lines=$(grep '^stdout_lines=' "$meta" | cut -d= -f2)
        meta_bytes=$(grep '^stdout_bytes=' "$meta" | cut -d= -f2)
        echo "[$tool] ${meta_elapsed}秒 / ${meta_lines}行 / ${meta_bytes}bytes / exit=${meta_exit_code}"
    fi
done

echo ""
echo "=== ファイル一覧 ==="
ls -la "$OUT_DIR"/

echo ""
echo "結果確認:"
if $RUN_CODEX; then echo "  cat $OUT_DIR/codex-stdout.txt"; fi
if $RUN_CLAUDE; then echo "  cat $OUT_DIR/claude-stdout.txt"; fi
