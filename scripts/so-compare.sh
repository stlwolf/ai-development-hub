#!/usr/bin/env bash
# so-compare.sh - セカンドオピニオン比較実行スクリプト（使い捨て可）
# 同一プロンプトを Codex CLI / Claude Code に投げて結果をファイルに保存する
#
# Usage:
#   so-compare.sh "プロンプトテキスト"
#   so-compare.sh -f prompt.txt
#   echo "プロンプト" | so-compare.sh -
#
# Options:
#   -f FILE     プロンプトをファイルから読み込み
#   -c FILE...  コンテキストファイルを添付（プロンプトに内容を追記）
#   -o DIR      出力ディレクトリを指定（デフォルト: tmp/so-YYYYMMDD-HHMMSS）
#   -s MODE     Codex sandbox モード（デフォルト: read-only）
#   --codex-only   Codex のみ実行
#   --claude-only  Claude のみ実行

set -euo pipefail

# --- 設定 ---
CODEX_CMD="codex"
CLAUDE_CMD="claude-safe"
SANDBOX_MODE="read-only"
OUT_DIR=""
PROMPT=""
CONTEXT_FILES=()
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
        -)
            PROMPT=$(cat)
            shift
            ;;
        -*)
            echo "Unknown option: $1" >&2
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
    echo "Usage: so-compare.sh \"プロンプトテキスト\"" >&2
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
