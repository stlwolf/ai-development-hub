# shellcheck shell=bash
# shellcheck disable=SC2034
# spawn.sh — ペイン生成 + セッション開始（source 専用）

# グローバル変数: oe_spawn() の戻り値
OE_SPAWN_PANE_ID=""

# oe_spawn_prepare_pane — 新ペインを作成し OE_SPAWN_PANE_ID に保存
oe_spawn_prepare_pane() {
  OE_SPAWN_PANE_ID=""
  # --wait-ready: 新ペインが入力受付可能になるまで待機（tmux auto-attach 等のタイミング問題の緩和）
  OE_SPAWN_PANE_ID="$(wez pane split --bottom --percent 30 --wait-ready --timeout "$OE_SPAWN_WAIT_READY_SEC")"
}

# _oe_spawn_build_cli_command — AI CLI ごとに正しい invocation を組み立てる
# (Step 4-4 Phase A #91 反映、Phase A Step 1 物理前提実機確認結果に従う)
#
# 引数:
#   ai_cli         "cursor-agent" | "cursor" | "claude" | "claude-safe" | "codex"
#   ai_model       モデル名 (例: "composer-2", "claude-sonnet-4-6")
#   envelope_path  envelope JSON のパス (target / verify 両用)
#   [workspace]    workspace ディレクトリ (cursor-agent --workspace 用、デフォルト = PROJECT_DIR)
#
# stdout に組み立てた CLI コマンド文字列を出力。未対応 CLI は exit 1。
#
# Phase A Step 1 で確認した invocation 仕様:
# - cursor-agent: --print --model <model> --workspace <path> --force '<prompt>'
# - claude: -p '<prompt>' --model <model> --add-dir <repo_root> --add-dir /tmp \
#           --output-format text --no-session-persistence --max-budget-usd 1.0
# - codex: スタブ (claude と同形式、本 Step では動作確認なし)
_oe_spawn_build_cli_command() {
  local ai_cli="$1"
  local ai_model="$2"
  local envelope_path="$3"
  local workspace="${4:-${PROJECT_DIR}}"

  local prompt="Read ${envelope_path} and execute the task"

  # repo_root は claude の --add-dir 用 (skill ファイル workspace 外アクセス)
  local repo_root
  repo_root="$(cd "${PROJECT_DIR}/../.." && pwd)"

  case "$ai_cli" in
    cursor-agent|cursor)
      printf "cursor-agent --print --model %s --workspace %s --force '%s'" \
        "$ai_model" "$workspace" "$prompt"
      ;;
    claude|claude-safe)
      # claude 直接 (wez pane の独立 pty で TTY 競合なし、Step 4-4 Phase A Step 1 F-7 確認)
      printf "claude -p '%s' --model %s --add-dir %s --add-dir /tmp --output-format text --no-session-persistence --max-budget-usd 1.0" \
        "$prompt" "$ai_model" "$repo_root"
      ;;
    codex)
      # Step 4-4 ではスタブ。動作確認は Step 4-5 以降で必要なら実施
      printf "codex -p '%s' --model %s -w %s" \
        "$prompt" "$ai_model" "$workspace"
      ;;
    *)
      echo "_oe_spawn_build_cli_command: unsupported ai_cli '${ai_cli}' (supported: cursor-agent, cursor, claude, claude-safe, codex)" >&2
      return 1
      ;;
  esac
}

# oe_spawn_send — 既存ペインに AI CLI コマンド + マーカー emit を送信
#
# 引数:
#   session_id, pane_id, envelope_path,
#   [ai_cli]    (デフォルト: ${OE_TARGET_AI_CLI:-cursor-agent})
#   [ai_model]  (デフォルト: ${OE_TARGET_AI_MODEL:-composer-2})
#   [workspace] (デフォルト: ${PROJECT_DIR})
#
# Step 4-4 Phase A 反映: ai_cli / ai_model の伝播 + ディスパッチャ経由化 (F-8)
oe_spawn_send() {
  local session_id="$1"
  local pane_id="$2"
  local envelope_path="$3"
  local ai_cli="${4:-${OE_TARGET_AI_CLI:-cursor-agent}}"
  local ai_model="${5:-${OE_TARGET_AI_MODEL:-composer-2}}"
  local workspace="${6:-${PROJECT_DIR}}"

  local base_cli_command
  base_cli_command="$(_oe_spawn_build_cli_command "$ai_cli" "$ai_model" "$envelope_path" "$workspace")"

  local cli_command
  cli_command="${base_cli_command} ; printf '\\n@@OE_EXIT:%d\\n' \$?"

  wez pane send "$pane_id" "$cli_command"

  # session_start の state は audit schema（failure-taxonomy）と整合するため null
  oe_audit_emit "session_start" "$session_id" "$pane_id" "" "{}"
}

# oe_spawn — 後方互換ラッパー（prepare → send）
#
# 引数: session_id, envelope_path,
#       [ai_cli]    (デフォルト: ${OE_TARGET_AI_CLI:-cursor-agent})
#       [ai_model]  (デフォルト: ${OE_TARGET_AI_MODEL:-composer-2})
# 戻り値: OE_SPAWN_PANE_ID にペイン ID を設定
#
# Step 4-4 Phase A 反映 (F-8): ai_model 引数追加 + oe_spawn_send への伝播
oe_spawn() {
  local session_id="$1"
  local envelope_path="$2"
  local ai_cli="${3:-${OE_TARGET_AI_CLI:-cursor-agent}}"
  local ai_model="${4:-${OE_TARGET_AI_MODEL:-composer-2}}"

  oe_spawn_prepare_pane
  oe_spawn_send "$session_id" "$OE_SPAWN_PANE_ID" "$envelope_path" "$ai_cli" "$ai_model"
}
