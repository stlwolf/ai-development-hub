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
                   デフォルトはモード別:
                     ask/plan: gpt-5.2,gemini-3.1-pro,composer-1.5
                     agent:    gpt-5.3-codex-high,gemini-3.1-pro,composer-1.5
  -c FILE...       コンテキストファイルを添付（プロンプトに内容を追記）
  -o DIR           出力ディレクトリを指定（デフォルト: tmp/arena-YYYYMMDD-HHMMSS）
  -w PATH          ワークスペースパス（デフォルト: カレントディレクトリ）
  --mode MODE      agent モード: agent | plan | ask（デフォルト: ask）
  --resume-from DIR  前回の出力ディレクトリからセッションを再開
  --list-models    利用可能なモデル一覧を表示して終了
  --dry-run        実行せずコマンドを表示
  -h, --help       このヘルプを表示

Environment:
  ARENA_MODELS     デフォルトモデル（カンマ区切り）
  ARENA_TIMEOUT    タイムアウト秒数（デフォルト: 180）
USAGE
}

# --- デフォルト設定 ---
AGENT_CMD="agent"
MODELS_STR=""
PROMPT=""
CONTEXT_FILES=()
OUT_DIR=""
WORKSPACE="$(pwd)"
AGENT_MODE="ask"
DRY_RUN=false
TIMEOUT="${ARENA_TIMEOUT:-180}"
RESUME_FROM=""

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
        --resume-from)
            RESUME_FROM="$2"
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

# モデルリスト確定（モード別デフォルト）
if [[ -z "$MODELS_STR" ]]; then
    if [[ -n "${ARENA_MODELS:-}" ]]; then
        MODELS_STR="$ARENA_MODELS"
    else
        case "$AGENT_MODE" in
            agent) MODELS_STR="gpt-5.3-codex-high,gemini-3.1-pro,composer-1.5" ;;
            *)     MODELS_STR="gpt-5.2,gemini-3.1-pro,composer-1.5" ;;
        esac
    fi
fi
IFS=',' read -ra MODELS <<< "$MODELS_STR"

# --- resume-from の検証 ---
if [[ -n "$RESUME_FROM" ]]; then
    if [[ ! -d "$RESUME_FROM" ]]; then
        echo "Error: --resume-from ディレクトリが存在しません: $RESUME_FROM" >&2
        exit 1
    fi
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
    OUT_DIR="tmp/arena-$(date +%Y%m%d-%H%M%S)"
fi
mkdir -p "$OUT_DIR"

# --- プロンプト保存 ---
echo "$PROMPT" > "$OUT_DIR/prompt.txt"

# --- resume モード判定 ---
IS_RESUME=false
if [[ -n "$RESUME_FROM" ]]; then
    IS_RESUME=true
fi

echo "=== Arena Compare ==="
echo "出力先: $OUT_DIR"
echo "モデル: ${MODELS[*]}"
if $IS_RESUME; then
    echo "モード: resume (from: $RESUME_FROM)"
else
    echo "モード: $AGENT_MODE"
fi
echo "ワークスペース: $WORKSPACE"
echo "タイムアウト: ${TIMEOUT}秒"
echo "プロンプト長: $(echo "$PROMPT" | wc -c | tr -d ' ') bytes"
echo ""

# --- チャットID 取得/読み込み ---
get_chat_id() {
    local model="$1"
    local resume_dir="$2"

    if [[ -n "$resume_dir" && -f "$resume_dir/${model}-chat-id.txt" ]]; then
        echo "resumed:$(cat "$resume_dir/${model}-chat-id.txt")"
    else
        local id
        id=$($AGENT_CMD create-chat 2>/dev/null | grep -oE '[0-9a-f-]{36}') || true
        if [[ -n "$id" ]]; then
            echo "new:$id"
        fi
    fi
}

# --- モデル実行関数 ---
run_model() {
    local model="$1"
    local prompt="$2"
    local out_dir="$3"
    local workspace="$4"
    local mode="$5"
    local resume_from="$6"

    echo "[$model] 実行中..."
    local start end elapsed exit_code chat_id
    start=$(date +%s)

    local -a mode_args=()
    if [[ "$mode" != "agent" ]]; then
        mode_args=(--mode "$mode")
    fi

    # チャットID 取得（"new:UUID" or "resumed:UUID"）
    local chat_id_raw is_new_chat
    chat_id_raw=$(get_chat_id "$model" "$resume_from")
    if [[ -z "$chat_id_raw" ]]; then
        echo "[$model] Error: チャットID取得に失敗" >&2
        return 1
    fi
    is_new_chat=false
    if [[ "$chat_id_raw" == new:* ]]; then
        is_new_chat=true
    fi
    chat_id="${chat_id_raw#*:}"
    echo "$chat_id" > "$out_dir/${model}-chat-id.txt"

    if $DRY_RUN; then
        echo "  CHAT_ID: $chat_id ($(if $is_new_chat; then echo "new"; else echo "resumed"; fi))"
        echo "  CMD: nohup $AGENT_CMD -p -f --resume=$chat_id --model $model --workspace $workspace --output-format text <prompt>"
        {
            echo "model=$model"
            echo "chat_id=$chat_id"
            echo "dry_run=true"
            echo "exit_code=0"
            echo "elapsed_seconds=0"
            echo "stdout_lines=0"
            echo "stdout_bytes=0"
            echo "stderr_bytes=0"
        } > "$out_dir/${model}-meta.txt"
        return 0
    fi

    # 既存チャットの resume 時は --mode を付けない（ハング回避: agent CLI の制約）
    # 新規チャット（部分 resume 含む）では --mode を付与する
    local -a resume_args=(--resume="$chat_id")
    local -a effective_mode_args=()
    if $is_new_chat; then
        effective_mode_args=("${mode_args[@]}")
    fi

    if timeout "$TIMEOUT" nohup $AGENT_CMD -p -f \
        "${resume_args[@]}" \
        --model "$model" \
        "${effective_mode_args[@]}" \
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
        echo "chat_id=$chat_id"
        echo "exit_code=$exit_code"
        echo "elapsed_seconds=$elapsed"
        echo "stdout_lines=$(wc -l < "$out_dir/${model}-stdout.txt" | tr -d ' ')"
        echo "stdout_bytes=$(wc -c < "$out_dir/${model}-stdout.txt" | tr -d ' ')"
        echo "stderr_bytes=$(wc -c < "$out_dir/${model}-stderr.txt" | tr -d ' ')"
    } > "$out_dir/${model}-meta.txt"
}

# --- サマリ生成関数 ---
generate_summary() {
    local out_dir="$1"
    shift
    local models=("$@")
    local summary="$out_dir/summary.md"

    local prompt_preview prompt_full
    prompt_full="$(<"$out_dir/prompt.txt")"
    prompt_preview="${prompt_full:0:100}..."
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    {
        echo "# Arena Compare Summary"
        echo ""
        echo "- **プロンプト**: ${prompt_preview}"
        echo "- **日時**: ${timestamp}"
        echo "- **モデル**: $(IFS=', '; echo "${models[*]}")"
        echo ""
        echo "## メタデータ"
        echo ""
        echo "| モデル | 時間 | 行数 | バイト数 | exit |"
        echo "|--------|------|------|----------|------|"

        for m in "${models[@]}"; do
            local meta="$out_dir/${m}-meta.txt"
            if [[ -f "$meta" ]]; then
                local model="" exit_code="" elapsed_seconds="" stdout_lines="" stdout_bytes=""
                # shellcheck disable=SC1090
                source "$meta"
                local time_display="${elapsed_seconds}秒"
                local status_suffix=""
                if [[ "$exit_code" == "124" ]]; then
                    status_suffix=" (タイムアウト)"
                elif [[ "$exit_code" != "0" ]]; then
                    status_suffix=" (異常終了)"
                fi
                echo "| ${model}${status_suffix} | ${time_display} | ${stdout_lines}行 | ${stdout_bytes}B | ${exit_code} |"
            else
                echo "| ${m} | - | - | - | - |"
            fi
        done

        for m in "${models[@]}"; do
            echo ""
            echo "## ${m}"
            echo ""
            local stdout_file="$out_dir/${m}-stdout.txt"
            if [[ -f "$stdout_file" && -s "$stdout_file" ]]; then
                cat "$stdout_file"
            else
                local meta="$out_dir/${m}-meta.txt"
                if [[ -f "$meta" ]]; then
                    local exit_code=""
                    # shellcheck disable=SC1090
                    source "$meta"
                    if [[ "$exit_code" == "124" ]]; then
                        echo "(タイムアウトにより出力なし)"
                    else
                        echo "(出力なし)"
                    fi
                else
                    echo "(実行結果なし)"
                fi
            fi
        done
    } > "$summary"

    echo "$summary"
}

# --- 全モデル並列実行（スタガー付き） ---
# agent CLI は起動時に cli-config.json を書き換えるため、
# 同時起動するとレースコンディションが発生する。2秒ずつずらして起動する。
# create-chat もシリアルで実行し、スタガー内で完結させる。
STAGGER_SEC=2
declare -A PIDS

for i in "${!MODELS[@]}"; do
    model="${MODELS[$i]}"
    if (( i > 0 )); then
        sleep "$STAGGER_SEC"
    fi
    run_model "$model" "$PROMPT" "$OUT_DIR" "$WORKSPACE" "$AGENT_MODE" "$RESUME_FROM" &
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

# --- サマリ生成 ---
if ! $DRY_RUN; then
    SUMMARY_FILE=$(generate_summary "$OUT_DIR" "${MODELS[@]}" 2>/dev/null) || true
fi

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
if [[ -n "${SUMMARY_FILE:-}" && -f "${SUMMARY_FILE:-}" ]]; then
    echo "  cat $OUT_DIR/summary.md"
else
    for model in "${MODELS[@]}"; do
        echo "  cat $OUT_DIR/${model}-stdout.txt"
    done
fi

# resume ヒント
if ! $IS_RESUME; then
    echo ""
    echo "=== セッション継続 ==="
    echo "  $0 --resume-from $OUT_DIR -m \"$MODELS_STR\" \"追加の質問\""
fi

if [[ $FAILED -gt 0 ]]; then
    echo ""
    echo "Warning: ${FAILED}/${#MODELS[@]} モデルで問題が発生しました"
    exit 1
fi
