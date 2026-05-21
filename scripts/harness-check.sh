#!/usr/bin/env bash
# harness-check.sh — ハーネス効果確認用ランナー
#
# 指定された prompts ディレクトリ内の各 prompt を CLI agent 経由で実行し、
# 結果をファイルに保存する。各 prompt は fresh session で実行されるため
# first-turn 挙動の観測に適する。
#
# 主な用途:
#   - Cursor / Claude / Codex の rule / skill の発動効果を実測
#   - 低スペックモデルでの first-turn 挙動の検証
#   - モデル間比較
#
# 設計: 1 prompt = 1 fresh session、N runs で繰り返し
#
# Issue #106 (Cursor Composer 2.5 ハーネス強化) の検証から派生した汎用ランナー。

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: scripts/harness-check.sh --prompts-dir DIR [options]

Options:
  --prompts-dir DIR      プロンプトファイル群のディレクトリ（必須）
                         各ファイルが 1 prompt。ファイル名 (拡張子除く) が label
  --cli CLI              cursor | claude | codex (デフォルト: cursor)
                         現状 cursor のみ実装。将来拡張予定
  --model MODEL          モデル名 (デフォルト: cursor=composer-2.5)
  --runs N               各 prompt の実行回数 (デフォルト: 1)
  --workspace PATH       ワークスペース (デフォルト: pwd)
  --out DIR              出力先 (デフォルト: tmp/harness-check-<cli>-<model>-<ts>)
  --dry-run              実行せずコマンドだけ表示
  -h, --help             このヘルプを表示

Examples:
  # Cursor Composer 2.5 で 4 prompts × 3 runs
  scripts/harness-check.sh \
    --prompts-dir docs/issues/106/harness-check-prompts/cursor-composer-2.5/ \
    --runs 3

  # 別モデルで比較
  scripts/harness-check.sh \
    --prompts-dir docs/issues/106/harness-check-prompts/cursor-composer-2.5/ \
    --model composer-2.5-fast \
    --runs 3
EOF
}

PROMPTS_DIR=""
CLI="cursor"
MODEL=""
RUNS=1
WORKSPACE="$(pwd)"
OUT_DIR=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --prompts-dir) PROMPTS_DIR="$2"; shift 2;;
        --cli)         CLI="$2"; shift 2;;
        --model)       MODEL="$2"; shift 2;;
        --runs)        RUNS="$2"; shift 2;;
        --workspace)   WORKSPACE="$2"; shift 2;;
        --out)         OUT_DIR="$2"; shift 2;;
        --dry-run)     DRY_RUN=true; shift;;
        -h|--help)     usage; exit 0;;
        *) echo "Unknown option: $1" >&2; usage; exit 1;;
    esac
done

# Validation
if [[ -z "$PROMPTS_DIR" ]]; then
    echo "Error: --prompts-dir is required" >&2
    usage
    exit 1
fi

if [[ ! -d "$PROMPTS_DIR" ]]; then
    echo "Error: prompts dir not found: $PROMPTS_DIR" >&2
    exit 1
fi

# Default model per CLI
case "$CLI" in
    cursor) : "${MODEL:=composer-2.5}";;
    claude) : "${MODEL:=sonnet}";;
    codex)  : "${MODEL:=gpt-5.3-codex}";;
    *) echo "Error: unknown CLI: $CLI (expected: cursor | claude | codex)" >&2; exit 1;;
esac

# Default output dir
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
: "${OUT_DIR:=tmp/harness-check-${CLI}-${MODEL}-${TIMESTAMP}}"

mkdir -p "$OUT_DIR"

# Metadata
{
    echo "CLI: $CLI"
    echo "Model: $MODEL"
    echo "Runs per prompt: $RUNS"
    echo "Workspace: $WORKSPACE"
    echo "Prompts dir: $PROMPTS_DIR"
    echo "Started: $(date -Iseconds)"
} > "$OUT_DIR/_metadata.txt"

# CLI dispatch
run_agent() {
    local prompt="$1"
    local out_file="$2"

    case "$CLI" in
        cursor)
            cursor-agent --print \
                --model "$MODEL" \
                --workspace "$WORKSPACE" \
                --output-format text \
                --force \
                "$prompt" > "$out_file" 2>&1
            ;;
        claude)
            echo "Error: claude CLI dispatch not yet implemented" >&2
            return 1
            ;;
        codex)
            echo "Error: codex CLI dispatch not yet implemented" >&2
            return 1
            ;;
    esac
}

# Main loop
TOTAL=0
FAILED=0

for prompt_file in "$PROMPTS_DIR"/*; do
    [[ -f "$prompt_file" ]] || continue

    prompt_name="$(basename "$prompt_file")"
    prompt_label="${prompt_name%.*}"
    prompt_out_dir="$OUT_DIR/$prompt_label"
    mkdir -p "$prompt_out_dir"

    prompt_content="$(cat "$prompt_file")"

    for run in $(seq 1 "$RUNS"); do
        out_file="$prompt_out_dir/run-${run}.md"
        TOTAL=$((TOTAL + 1))

        echo "[$TOTAL] ${prompt_label} run ${run}/${RUNS} → ${out_file}"

        if $DRY_RUN; then
            echo "  (dry-run) ${CLI} agent / model=${MODEL}"
            continue
        fi

        if ! run_agent "$prompt_content" "$out_file"; then
            FAILED=$((FAILED + 1))
            echo "  FAILED (continuing)" >&2
        fi
    done
done

# Footer metadata
{
    echo ""
    echo "Finished: $(date -Iseconds)"
    echo "Total runs: $TOTAL"
    echo "Failed: $FAILED"
} >> "$OUT_DIR/_metadata.txt"

echo ""
echo "Results saved to: $OUT_DIR"
echo "Total: $TOTAL, Failed: $FAILED"
