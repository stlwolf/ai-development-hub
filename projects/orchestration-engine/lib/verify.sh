# shellcheck shell=bash
# shellcheck disable=SC2034
# verify.sh — Step 4-3 検証ゲート v1 関数群（source 専用）
#
# 責務:
#   - 検証用 envelope の生成（adversarial-review skill を use_skills + read_docs で疎結合指定）
#   - 検証 agent ペインの spawn と verification_started イベント emit
#   - Phase C で oe_verify_prompt_build を追加（3 入力の構造化抽出）
#   - Phase D で @@OE_VERIFY: パース + KVS pane-keyed map 書き込み + verification_completed emit を追加
#   - Phase E で oe_verify_run_phase の独立ループを追加
#
# 設計方針 (Plan F4 / DI-7):
#   engine は skill prompt の static copy を持たない。検証 agent が envelope の
#   use_skills: ["adversarial-review"] と read_docs から skill を読み、Compliance Review を実行する。

# グローバル変数: oe_verify_envelope_create / oe_verify_spawn の戻り値
OE_VERIFY_ENVELOPE_PATH=""
OE_VERIFY_PANE_ID=""

# oe_verify_envelope_create — 検証用 envelope を生成し validate-envelope.sh で検証
#
# 引数:
#   reviewer_session_id   検証 agent のセッション ID (ULID)
#   reviewer_pane_id      検証 agent が起動するペイン ID (oe_spawn_prepare_pane の出力)
#   target_pane_id        被検証ペイン ID
#   target_session_id     被検証セッション ID (= bin/oe メインの session_id)
#   target_envelope_path  被検証ペインの envelope JSON のパス
#
# 戻り値: OE_VERIFY_ENVELOPE_PATH に生成ファイルパスを設定
# 検証失敗時は exit 1 (set -e による自動終了)
oe_verify_envelope_create() {
  local reviewer_session_id="$1"
  local reviewer_pane_id="$2"
  local target_pane_id="$3"
  local target_session_id="$4"
  local target_envelope_path="$5"

  OE_VERIFY_ENVELOPE_PATH=""

  local envelope_path="/tmp/oe-${reviewer_session_id}-verify-envelope.json"

  # skill のパス: PROJECT_DIR からの相対で canonical/skills/adversarial-review/SKILL.md
  # (リポジトリルートは PROJECT_DIR の親の親)
  local repo_root
  repo_root="$(cd "${PROJECT_DIR}/../.." && pwd)"
  local skill_path="${repo_root}/canonical/skills/adversarial-review/SKILL.md"
  local audit_path="${OE_AUDIT_DIR}/${target_session_id}.jsonl"
  local kvs_path="${OE_STATE_DIR}/${target_session_id}.state.json"

  # task.description は検証指示の概要のみ。skill prompt 本文は engine に持たない (F4)
  local task_desc
  task_desc="Compliance Review per the adversarial-review skill. Read the inputs in read_docs and emit one of: @@OE_VERIFY:pass / @@OE_VERIFY:fail / @@OE_VERIFY:warn on a new line based on your conclusion before exit."

  jq -n \
    --arg sid "$reviewer_session_id" \
    --argjson pid "$reviewer_pane_id" \
    --arg desc "$task_desc" \
    --arg odir "$PROJECT_DIR" \
    --argjson timeout "$OE_CB_TIMEOUT" \
    --arg skill "$skill_path" \
    --arg tenv "$target_envelope_path" \
    --arg taudit "$audit_path" \
    --arg tkvs "$kvs_path" \
    --arg parent "$target_session_id" \
    --argjson max_panes "$OE_CB_MAX_PANES" \
    '{
      session_id: $sid,
      pane_id: $pid,
      task: {
        description: $desc,
        output_dir: $odir,
        exit_conditions: {
          marker: "@@OE_VERIFY",
          timeout_seconds: $timeout
        },
        read_docs: [$skill, $tenv, $taudit, $tkvs],
        use_skills: ["adversarial-review"]
      },
      context: {
        parent_session_id: $parent,
        related_issues: [],
        shared_kvs_path: $tkvs
      },
      constraints: {
        max_panes: $max_panes,
        state_vocabulary: ["spawn","ready","progress","done","blocked"]
      }
    }' > "$envelope_path"

  "${PROJECT_DIR}/scripts/validate-envelope.sh" "$envelope_path" >/dev/null

  OE_VERIFY_ENVELOPE_PATH="$envelope_path"
}

# oe_verify_spawn — 検証 agent ペインを準備 + envelope 生成 + 送信 + verification_started emit
#
# 引数:
#   reviewer_session_id   検証 agent のセッション ID (ULID)
#   target_pane_id        被検証ペイン ID
#   target_session_id     被検証セッション ID
#   target_envelope_path  被検証ペインの envelope JSON のパス
#   [ai_cli]              使用する AI CLI (デフォルト: "cursor")
#
# 戻り値:
#   OE_VERIFY_PANE_ID         検証 agent ペイン ID
#   OE_VERIFY_ENVELOPE_PATH   検証用 envelope パス
oe_verify_spawn() {
  local reviewer_session_id="$1"
  local target_pane_id="$2"
  local target_session_id="$3"
  local target_envelope_path="$4"
  local ai_cli="${5:-cursor}"

  OE_VERIFY_PANE_ID=""

  # 検証 agent 用ペインを準備 (Step 4-2 の lib/spawn.sh を再利用)
  oe_spawn_prepare_pane
  local reviewer_pane_id="$OE_SPAWN_PANE_ID"

  oe_verify_envelope_create \
    "$reviewer_session_id" \
    "$reviewer_pane_id" \
    "$target_pane_id" \
    "$target_session_id" \
    "$target_envelope_path"

  # 送信コマンド: ai_cli に envelope を読ませる + 末尾で shell が @@OE_EXIT を emit
  # 検証 agent 自身は task.description / skill の指示に従って @@OE_VERIFY:{result} を出力する。
  # 二値 (@@OE_VERIFY + @@OE_EXIT) の同時検出は Phase D F3 の二値保持で対応する。
  local cli_command
  cli_command="${ai_cli} --prompt 'Read ${OE_VERIFY_ENVELOPE_PATH} and execute the task' ; printf '\\n@@OE_EXIT:%d\\n' \$?"

  wez pane send "$reviewer_pane_id" "$cli_command"

  # verification_started イベントを target session の audit log に emit (F6: emit は Phase B のみ)
  local payload
  payload="$(jq -cn \
    --argjson tpid "$target_pane_id" \
    --arg tsid "$target_session_id" \
    --argjson rpid "$reviewer_pane_id" \
    --arg rsid "$reviewer_session_id" \
    '{target_pane_id: $tpid, target_session_id: $tsid, reviewer_pane_id: $rpid, reviewer_session_id: $rsid}')"

  oe_audit_emit "verification_started" "$target_session_id" "$target_pane_id" "" "$payload"

  OE_VERIFY_PANE_ID="$reviewer_pane_id"
}
