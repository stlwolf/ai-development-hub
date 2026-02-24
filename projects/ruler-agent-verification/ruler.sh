#!/usr/bin/env bash
# ruler.sh - Cursor agent CLI 経由でルーラーエージェントを実行
# arena-compare.sh と同じ agent 実行パターンを使用

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROMPT_TEMPLATE="$SCRIPT_DIR/prompts/ruler-v1.txt"

AGENT_CMD="${RULER_AGENT_CMD:-cursor-agent}"
DEFAULT_MODEL="gemini-3.1-pro"
DEFAULT_MODE="ask"
TIMEOUT="${RULER_TIMEOUT:-180}"

usage() {
    cat <<'USAGE'
Usage:
  ruler.sh "タスクの説明"
  ruler.sh -f task.txt
  ruler.sh -m gpt-5.2 "タスクの説明"

Options:
  -f FILE        タスク説明をファイルから読み込み
  -m MODEL       使用モデル（デフォルト: gemini-3.1-pro）
  -t TEMPLATE    プロンプトテンプレート（デフォルト: prompts/ruler-v1.txt）
  -o DIR         出力ディレクトリ（デフォルト: tmp/ruler-YYYYMMDD-HHMMSS）
  -w PATH        ワークスペースパス（デフォルト: リポジトリルート）
  --dry-run      実行せずコマンドを表示
  -h, --help     このヘルプを表示

Environment:
  RULER_TIMEOUT  タイムアウト秒数（デフォルト: 180）
USAGE
}

MODEL="$DEFAULT_MODEL"
TASK=""
WORKSPACE="$REPO_ROOT"
OUT_DIR=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f) TASK=$(cat "$2"); shift 2 ;;
        -m) MODEL="$2"; shift 2 ;;
        -t) PROMPT_TEMPLATE="$2"; shift 2 ;;
        -o) OUT_DIR="$2"; shift 2 ;;
        -w) WORKSPACE="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        -h|--help) usage; exit 0 ;;
        -*) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
        *) TASK="$1"; shift ;;
    esac
done

if [[ -z "$TASK" ]]; then
    echo "Error: タスク説明が指定されていません" >&2
    usage >&2
    exit 1
fi

if [[ ! -f "$PROMPT_TEMPLATE" ]]; then
    echo "Error: テンプレートが見つかりません: $PROMPT_TEMPLATE" >&2
    exit 1
fi

# --- プロンプト構築 ---
PROMPT=$(sed "s|{{TASK_DESCRIPTION}}|$TASK|" "$PROMPT_TEMPLATE")

# --- 出力ディレクトリ ---
if [[ -z "$OUT_DIR" ]]; then
    OUT_DIR="tmp/ruler-$(date +%Y%m%d-%H%M%S)"
fi
mkdir -p "$OUT_DIR"
echo "$PROMPT" > "$OUT_DIR/prompt.txt"

echo "=== Ruler Agent ==="
echo "出力先: $OUT_DIR"
echo "モデル: $MODEL"
echo "ワークスペース: $WORKSPACE"
echo "タイムアウト: ${TIMEOUT}秒"
echo "プロンプト長: $(echo "$PROMPT" | wc -c | tr -d ' ') bytes"
echo ""

# --- チャットID作成（arena-compare.sh と同じパターン） ---
CHAT_ID=$($AGENT_CMD create-chat 2>/dev/null | grep -oE '[0-9a-f-]{36}') || true
if [[ -z "$CHAT_ID" ]]; then
    echo "Error: チャットID取得に失敗" >&2
    exit 1
fi
echo "$CHAT_ID" > "$OUT_DIR/chat-id.txt"

if $DRY_RUN; then
    echo "CHAT_ID: $CHAT_ID"
    echo "CMD: nohup $AGENT_CMD -p -f --resume=$CHAT_ID --model $MODEL --mode $DEFAULT_MODE --workspace $WORKSPACE --output-format text <prompt>"
    exit 0
fi

echo "[$MODEL] 実行中..."
start=$(date +%s)

# --- 実行（arena-compare.sh と完全に同じパターン） ---
if timeout "$TIMEOUT" nohup $AGENT_CMD -p -f \
    --resume="$CHAT_ID" \
    --model "$MODEL" \
    --mode "$DEFAULT_MODE" \
    --workspace "$WORKSPACE" \
    --output-format text \
    "$PROMPT" \
    > "$OUT_DIR/stdout.txt" 2> "$OUT_DIR/stderr.txt"; then
    exit_code=0
else
    exit_code=$?
fi

end=$(date +%s)
elapsed=$((end - start))

echo "[$MODEL] 完了 (${elapsed}秒, exit=${exit_code})"

# --- メタデータ保存 ---
{
    echo "model=$MODEL"
    echo "chat_id=$CHAT_ID"
    echo "exit_code=$exit_code"
    echo "elapsed_seconds=$elapsed"
    echo "stdout_lines=$(wc -l < "$OUT_DIR/stdout.txt" | tr -d ' ')"
    echo "stdout_bytes=$(wc -c < "$OUT_DIR/stdout.txt" | tr -d ' ')"
    echo "stderr_bytes=$(wc -c < "$OUT_DIR/stderr.txt" | tr -d ' ')"
} > "$OUT_DIR/meta.txt"

echo ""
echo "=== 結果サマリ ==="
cat "$OUT_DIR/meta.txt"
echo ""
echo "結果確認:"
echo "  cat $OUT_DIR/stdout.txt"

# stdout を表示
if [[ -s "$OUT_DIR/stdout.txt" ]]; then
    echo ""
    echo "=== ルーラー出力 ==="
    cat "$OUT_DIR/stdout.txt"
fi
