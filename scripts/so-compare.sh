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
  -o DIR         出力ディレクトリを指定（デフォルト: tmp/so-YYYYMMDD-HHMMSS）
  -s MODE        Codex sandbox モード（デフォルト: read-only）
  --codex-only   Codex のみ実行
  --claude-only  Claude のみ実行
  --prev DIR     前回の so-compare 出力ディレクトリ
                 回答をプロンプトに追記（上限: PREV_MAX_BYTES, デフォルト4000）
  -h, --help     このヘルプを表示

Environment:
  PREV_MAX_BYTES   --prev で追記する回答の上限バイト数（デフォルト: 4000）
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
RUN_CODEX=true
RUN_CLAUDE=true

# --- 引数解析 ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -f)
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
        -o)
            OUT_DIR="$2"
            shift 2
            ;;
        -s)
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

# --- コンテキストファイルの内容をプロンプトに追記 ---
if [[ ${#CONTEXT_FILES[@]} -gt 0 ]]; then
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

echo "=== Second Opinion Comparison ==="
echo "出力先: $OUT_DIR"
echo "sandbox: $SANDBOX_MODE"
echo "プロンプト長: $(echo "$PROMPT" | wc -c | tr -d ' ') bytes"
echo ""

# --- 実行関数 ---
run_codex() {
    echo "[Codex] 実行中..."
    local start end elapsed
    start=$(date +%s)

    if $CODEX_CMD exec -s "$SANDBOX_MODE" "$PROMPT" \
        > "$OUT_DIR/codex-stdout.txt" 2> "$OUT_DIR/codex-stderr.txt"; then
        local exit_code=0
    else
        local exit_code=$?
    fi

    end=$(date +%s)
    elapsed=$((end - start))

    echo "[Codex] 完了 (${elapsed}秒, exit=${exit_code})"

    # メタデータ
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
    local start end elapsed
    start=$(date +%s)

    if $CLAUDE_CMD -p "$PROMPT" --output-format text \
        > "$OUT_DIR/claude-stdout.txt" 2> "$OUT_DIR/claude-stderr.txt"; then
        local exit_code=0
    else
        local exit_code=$?
    fi

    end=$(date +%s)
    elapsed=$((end - start))

    echo "[Claude] 完了 (${elapsed}秒, exit=${exit_code})"

    # メタデータ
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
        # shellcheck disable=SC1090
        source "$meta"
        # shellcheck disable=SC2154
        echo "[$tool] ${elapsed_seconds}秒 / ${stdout_lines}行 / ${stdout_bytes}bytes / exit=${exit_code}"
    fi
done

echo ""
echo "=== ファイル一覧 ==="
ls -la "$OUT_DIR"/

echo ""
echo "結果確認:"
if $RUN_CODEX; then echo "  cat $OUT_DIR/codex-stdout.txt"; fi
if $RUN_CLAUDE; then echo "  cat $OUT_DIR/claude-stdout.txt"; fi
