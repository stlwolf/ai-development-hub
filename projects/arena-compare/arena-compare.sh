#!/usr/bin/env bash
# arena-compare.sh - Cursor CLI (agent) でマルチモデル並列比較
# Cursor サブスクのモデルを使い、同一プロンプトを複数モデルに並列投入して結果を比較する

set -euo pipefail

usage() {
    cat <<'USAGE'
Usage:
  arena-compare.sh "プロンプトテキスト"
  arena-compare.sh -f prompt.txt
  arena-compare.sh -m "opus-4.6,gpt-5.2,gemini-3-flash" "プロンプト"

Options:
  -f FILE          プロンプトをファイルから読み込み
  -m MODELS        比較モデル（カンマ区切り）
                   デフォルト: opus-4.6,gpt-5.2,gemini-3-flash
  -c FILE...       コンテキストファイルを添付（プロンプトに内容を追記）
  -o DIR           出力ディレクトリを指定（デフォルト: tmp/arena-YYYYMMDD-HHMMSS）
  -w PATH          ワークスペースパス（デフォルト: カレントディレクトリ）
  --mode MODE      agent モード: agent | plan | ask（デフォルト: ask）
  --list-models    利用可能なモデル一覧を表示して終了
  --dry-run        実行せずコマンドを表示
  -h, --help       このヘルプを表示

Environment:
  ARENA_MODELS     デフォルトモデル（カンマ区切り）
  ARENA_TIMEOUT    タイムアウト秒数（デフォルト: 300）
USAGE
}

# --- デフォルト設定 ---
AGENT_CMD="agent"
DEFAULT_MODELS="${ARENA_MODELS:-opus-4.6,gpt-5.2,gemini-3-flash}"
MODELS_STR=""
PROMPT=""
CONTEXT_FILES=()
OUT_DIR=""
WORKSPACE="$(pwd)"
AGENT_MODE="ask"
DRY_RUN=false
TIMEOUT="${ARENA_TIMEOUT:-300}"

# --- 引数解析 ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -f)
            PROMPT=$(cat "$2")
            shift 2
            ;;
        -m)
            MODELS_STR="$2"
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
        -w)
            WORKSPACE="$2"
            shift 2
            ;;
        --mode)
            AGENT_MODE="$2"
            shift 2
            ;;
        --list-models)
            exec $AGENT_CMD models
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
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

# モデルリスト確定
if [[ -z "$MODELS_STR" ]]; then
    MODELS_STR="$DEFAULT_MODELS"
fi
IFS=',' read -ra MODELS <<< "$MODELS_STR"

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
    OUT_DIR="tmp/arena-$(date +%Y%m%d-%H%M%S)"
fi
mkdir -p "$OUT_DIR"

# --- プロンプト保存 ---
echo "$PROMPT" > "$OUT_DIR/prompt.txt"

echo "=== Arena Compare ==="
echo "出力先: $OUT_DIR"
echo "モデル: ${MODELS[*]}"
echo "モード: $AGENT_MODE"
echo "ワークスペース: $WORKSPACE"
echo "タイムアウト: ${TIMEOUT}秒"
echo "プロンプト長: $(echo "$PROMPT" | wc -c | tr -d ' ') bytes"
echo ""

# --- モデル実行関数 ---
run_model() {
    local model="$1"
    local prompt="$2"
    local out_dir="$3"
    local workspace="$4"
    local mode="$5"

    echo "[$model] 実行中..."
    local start end elapsed exit_code
    start=$(date +%s)

    local -a mode_args=()
    if [[ "$mode" != "agent" ]]; then
        mode_args=(--mode "$mode")
    fi

    if $DRY_RUN; then
        echo "  CMD: nohup $AGENT_CMD -p -f --model $model ${mode_args[*]:-} --workspace $workspace --output-format text <prompt>"
        echo "model=$model" > "$out_dir/${model}-meta.txt"
        echo "dry_run=true" >> "$out_dir/${model}-meta.txt"
        return 0
    fi

    # nohup で TTY 分離（claude-safe パターン）
    if timeout "$TIMEOUT" nohup $AGENT_CMD -p -f \
        --model "$model" \
        "${mode_args[@]}" \
        --workspace "$workspace" \
        --output-format text \
        "$prompt" \
        > "$out_dir/${model}-stdout.txt" 2> "$out_dir/${model}-stderr.txt"; then
        exit_code=0
    else
        exit_code=$?
    fi

    end=$(date +%s)
    elapsed=$((end - start))

    echo "[$model] 完了 (${elapsed}秒, exit=${exit_code})"

    {
        echo "model=$model"
        echo "exit_code=$exit_code"
        echo "elapsed_seconds=$elapsed"
        echo "stdout_lines=$(wc -l < "$out_dir/${model}-stdout.txt" | tr -d ' ')"
        echo "stdout_bytes=$(wc -c < "$out_dir/${model}-stdout.txt" | tr -d ' ')"
        echo "stderr_bytes=$(wc -c < "$out_dir/${model}-stderr.txt" | tr -d ' ')"
    } > "$out_dir/${model}-meta.txt"
}

# --- 全モデル並列実行（スタガー付き） ---
# agent CLI は起動時に cli-config.json を書き換えるため、
# 同時起動するとレースコンディションが発生する。2秒ずつずらして起動する。
STAGGER_SEC=2
declare -A PIDS

for i in "${!MODELS[@]}"; do
    model="${MODELS[$i]}"
    if (( i > 0 )); then
        sleep "$STAGGER_SEC"
    fi
    run_model "$model" "$PROMPT" "$OUT_DIR" "$WORKSPACE" "$AGENT_MODE" &
    PIDS[$model]=$!
done

# 完了待ち
FAILED=0
for model in "${MODELS[@]}"; do
    if ! wait "${PIDS[$model]}" 2>/dev/null; then
        echo "Warning: [$model] の実行に問題がありました" >&2
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "=== 結果サマリ ==="

for model in "${MODELS[@]}"; do
    meta="$OUT_DIR/${model}-meta.txt"
    if [[ -f "$meta" ]]; then
        # shellcheck disable=SC1090
        source "$meta"
        # shellcheck disable=SC2154
        printf "[%-20s] %3s秒 / %4s行 / %6sbytes / exit=%s\n" \
            "$model" "$elapsed_seconds" "$stdout_lines" "$stdout_bytes" "$exit_code"
    else
        printf "[%-20s] (メタデータなし)\n" "$model"
    fi
done

echo ""
echo "=== ファイル一覧 ==="
ls -la "$OUT_DIR"/

echo ""
echo "=== 結果確認コマンド ==="
for model in "${MODELS[@]}"; do
    echo "  cat $OUT_DIR/${model}-stdout.txt"
done

if [[ $FAILED -gt 0 ]]; then
    echo ""
    echo "⚠ ${FAILED}/${#MODELS[@]} モデルで問題が発生しました"
    exit 1
fi
