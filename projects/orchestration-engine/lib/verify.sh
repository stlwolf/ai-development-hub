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

# グローバル変数: oe_verify_envelope_create / oe_verify_spawn / oe_verify_prompt_build の戻り値
OE_VERIFY_ENVELOPE_PATH=""
OE_VERIFY_PANE_ID=""
OE_VERIFY_PROMPT_PATH=""

# oe_verify_envelope_create — 検証用 envelope を生成し validate-envelope.sh で検証
#
# 引数:
#   reviewer_session_id    検証 agent のセッション ID (ULID)
#   reviewer_pane_id       検証 agent が起動するペイン ID (oe_spawn_prepare_pane の出力)
#   target_pane_id         被検証ペイン ID
#   target_session_id      被検証セッション ID (= bin/oe メインの session_id)
#   target_envelope_path   被検証ペインの envelope JSON のパス
#   [verify_prompt_path]   Phase C で oe_verify_prompt_build が生成した 3 入力ファイル (optional)
#                          指定時は read_docs に 5 件目として追加 (Phase B 後方互換)
#
# 戻り値: OE_VERIFY_ENVELOPE_PATH に生成ファイルパスを設定
# 検証失敗時は exit 1 (set -e による自動終了)
oe_verify_envelope_create() {
  local reviewer_session_id="$1"
  local reviewer_pane_id="$2"
  local target_pane_id="$3"
  local target_session_id="$4"
  local target_envelope_path="$5"
  local verify_prompt_path="${6:-}"

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

  # read_docs 配列を構築 (verify_prompt_path が指定されたら 5 件目に追加)
  local read_docs_json
  if [[ -n "$verify_prompt_path" ]]; then
    read_docs_json="$(jq -cn \
      --arg skill "$skill_path" \
      --arg tenv "$target_envelope_path" \
      --arg taudit "$audit_path" \
      --arg tkvs "$kvs_path" \
      --arg tprompt "$verify_prompt_path" \
      '[$skill, $tenv, $taudit, $tkvs, $tprompt]')"
  else
    read_docs_json="$(jq -cn \
      --arg skill "$skill_path" \
      --arg tenv "$target_envelope_path" \
      --arg taudit "$audit_path" \
      --arg tkvs "$kvs_path" \
      '[$skill, $tenv, $taudit, $tkvs]')"
  fi

  jq -n \
    --arg sid "$reviewer_session_id" \
    --argjson pid "$reviewer_pane_id" \
    --arg desc "$task_desc" \
    --arg odir "$PROJECT_DIR" \
    --argjson timeout "$OE_CB_TIMEOUT" \
    --argjson read_docs "$read_docs_json" \
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
        read_docs: $read_docs,
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

# oe_verify_prompt_build — Compliance Review に渡す 3 入力 (要件・完了報告・変更ファイル) を
# envelope / audit JSONL / KVS から抽出し、構造化マークダウンとして書き出す。
#
# 引数:
#   reviewer_session_id   検証 agent のセッション ID (出力ファイル名に使用)
#   target_pane_id        被検証ペイン ID (未使用、将来拡張用、API 安定化のため引数として保持)
#   target_session_id     被検証セッション ID (audit / KVS パスの解決に使用)
#   target_envelope_path  被検証ペインの envelope JSON のパス
#
# 戻り値: OE_VERIFY_PROMPT_PATH に生成ファイルパスを設定
#
# F4: engine は skill prompt 本文を組み立てない。3 入力の構造化抽出のみ。
#     検証 agent が use_skills + read_docs で skill を読んで自分でプロンプトを組み立てる。
# F7: outputs[] は MVP では常に空配列のため、git diff --name-only パスが常時選択される。
#     outputs[] の書き込み拡張は本 Step スコープ外。
oe_verify_prompt_build() {
  local reviewer_session_id="$1"
  # shellcheck disable=SC2034  # API 安定化のため引数として保持 (将来 per-pane 拡張で使用予定)
  local target_pane_id="$2"
  local target_session_id="$3"
  local target_envelope_path="$4"

  OE_VERIFY_PROMPT_PATH=""

  local prompt_path="/tmp/oe-${reviewer_session_id}-verify-inputs.md"
  local audit_path="${OE_AUDIT_DIR}/${target_session_id}.jsonl"
  local kvs_path="${OE_STATE_DIR}/${target_session_id}.state.json"

  # 要件: target envelope の task.description (envelope は事前に存在する前提)
  local task_description
  if [[ -f "$target_envelope_path" ]]; then
    task_description="$(jq -r '.task.description // "(no description)"' "$target_envelope_path")"
  else
    task_description="(target envelope not found: $target_envelope_path)"
  fi

  # 完了報告: audit JSONL から最後の state_change イベントを抽出
  local last_state_change
  if [[ -f "$audit_path" ]]; then
    last_state_change="$(jq -s 'map(select(.event_type == "state_change")) | last // null' "$audit_path")"
    if [[ "$last_state_change" == "null" ]]; then
      last_state_change="(no state_change events recorded in audit log)"
    fi
  else
    last_state_change="(audit log not found: $audit_path)"
  fi

  # 変更ファイル: KVS の outputs[] を優先、空なら git diff --name-only にフォールバック (F7)
  local changed_files_block
  local outputs_count=0
  if [[ -f "$kvs_path" ]]; then
    outputs_count="$(jq '(.outputs // []) | length' "$kvs_path")"
  fi

  if [[ "$outputs_count" -gt 0 ]]; then
    changed_files_block="$(jq -r '.outputs[] | "- " + .' "$kvs_path")"
  else
    # フォールバック: git diff --name-only (MVP では常にこちらが選択される)
    local git_output
    if git_output="$(git diff --name-only 2>/dev/null)" && [[ -n "$git_output" ]]; then
      changed_files_block="$(printf '%s\n' "$git_output" | awk 'NF { print "- " $0 }')"
    else
      changed_files_block="(no changes detected from KVS outputs[] or git diff)"
    fi
  fi

  # 構造化マークダウンとして書き出し
  {
    printf '# Compliance Review Inputs\n\n'
    printf 'reviewer_session_id: %s\n' "$reviewer_session_id"
    printf 'target_session_id: %s\n' "$target_session_id"
    printf 'target_pane_id: %s\n\n' "$target_pane_id"
    printf '## 要件 (Task description)\n\n'
    printf '%s\n\n' "$task_description"
    printf '## 完了報告 (Latest state_change event)\n\n'
    # shellcheck disable=SC2016  # backticks in single quotes are literal Markdown fences here
    printf '```json\n%s\n```\n\n' "$last_state_change"
    printf '## 変更ファイル (Changed files)\n\n'
    printf '%s\n' "$changed_files_block"
  } > "$prompt_path"

  OE_VERIFY_PROMPT_PATH="$prompt_path"
}

# oe_verify_spawn — 検証 agent ペインを準備 + プロンプト構築 + envelope 生成 + 送信 + verification_started emit
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
#   OE_VERIFY_PROMPT_PATH     構築されたプロンプト (3 入力) ファイルパス
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

  # Phase C: プロンプト (3 入力の構造化抽出) を先に構築
  oe_verify_prompt_build \
    "$reviewer_session_id" \
    "$target_pane_id" \
    "$target_session_id" \
    "$target_envelope_path"

  # envelope 生成 (read_docs に OE_VERIFY_PROMPT_PATH を含む 5 件)
  oe_verify_envelope_create \
    "$reviewer_session_id" \
    "$reviewer_pane_id" \
    "$target_pane_id" \
    "$target_session_id" \
    "$target_envelope_path" \
    "$OE_VERIFY_PROMPT_PATH"

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

# oe_verify_write_kvs — Step 4-3 Phase D: 検証結果を KVS の verification (pane-keyed map) に書き込む
#
# 引数:
#   target_session_id     被検証セッション ID
#   target_pane_id        被検証ペイン ID (verification map のキー)
#   reviewer_session_id   検証 agent セッション ID
#   reviewer_pane_id      検証 agent ペイン ID
#   result                "pass" | "fail" | "warn" (@@OE_VERIFY: の値)
#   [issues_count]        skill 出力からの問題件数 (デフォルト 0)
#   [marker_raw]          捕捉したマーカー原文 (デフォルト "@@OE_VERIFY:{result}")
#
# F5 反映: pane-keyed map で書き込む。既存 verification map に他 pane エントリがあれば維持する。
# atomic rename パターン (Step 4-2 oe_capture_write_kvs と同様)。
oe_verify_write_kvs() {
  local target_session_id="$1"
  local target_pane_id="$2"
  local reviewer_session_id="$3"
  local reviewer_pane_id="$4"
  local result="$5"
  local issues_count="${6:-0}"
  local marker_raw="${7:-@@OE_VERIFY:${result}}"

  local state_file="${OE_STATE_DIR}/${target_session_id}.state.json"
  local tmp_file="${OE_STATE_DIR}/.${target_session_id}.state.json.$$"

  if [[ ! -f "$state_file" ]]; then
    echo "oe_verify_write_kvs: state file not found: $state_file" >&2
    return 1
  fi

  local completed_at
  completed_at="$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")"

  # verification.{target_pane_id} を更新 (既存 map は維持)
  jq \
    --arg pid "$target_pane_id" \
    --arg result "$result" \
    --arg rsid "$reviewer_session_id" \
    --argjson rpid "$reviewer_pane_id" \
    --argjson issues "$issues_count" \
    --arg marker_raw "$marker_raw" \
    --arg completed_at "$completed_at" \
    '.verification = ((.verification // {}) | .[$pid] = {
       result: $result,
       reviewer_session_id: $rsid,
       reviewer_pane_id: $rpid,
       issues_count: $issues,
       marker_raw: $marker_raw,
       completed_at: $completed_at
     })' \
    "$state_file" > "$tmp_file"

  mv -f "$tmp_file" "$state_file"
  return 0
}

# oe_verify_summary_update — KVS の verification map を集計し verification_summary に書き込む
#
# 引数: target_session_id
#
# total = verification map のキー数
# passed/failed/warned = 各 result 値の件数
# fail_rate = failed / total を awk で 3 桁丸め (Bash 3.2 整数演算回避)
oe_verify_summary_update() {
  local target_session_id="$1"

  local state_file="${OE_STATE_DIR}/${target_session_id}.state.json"
  local tmp_file="${OE_STATE_DIR}/.${target_session_id}.state.json.$$"

  if [[ ! -f "$state_file" ]]; then
    echo "oe_verify_summary_update: state file not found: $state_file" >&2
    return 1
  fi

  local total passed failed warned
  total="$(jq '(.verification // {}) | length' "$state_file")"
  passed="$(jq '(.verification // {}) | to_entries | map(select(.value.result == "pass")) | length' "$state_file")"
  failed="$(jq '(.verification // {}) | to_entries | map(select(.value.result == "fail")) | length' "$state_file")"
  warned="$(jq '(.verification // {}) | to_entries | map(select(.value.result == "warn")) | length' "$state_file")"

  local fail_rate
  if [[ "$total" -gt 0 ]]; then
    fail_rate="$(awk -v f="$failed" -v t="$total" 'BEGIN{ printf "%.3f", f/t }')"
  else
    fail_rate="0.000"
  fi

  jq \
    --argjson total "$total" \
    --argjson passed "$passed" \
    --argjson failed "$failed" \
    --argjson warned "$warned" \
    --argjson fail_rate "$fail_rate" \
    '.verification_summary = {
       total: $total,
       passed: $passed,
       failed: $failed,
       warned: $warned,
       fail_rate: $fail_rate
     }' \
    "$state_file" > "$tmp_file"

  mv -f "$tmp_file" "$state_file"
  return 0
}

# oe_verify_emit_completed — verification_completed イベントを target session の audit log に emit
#
# 引数:
#   target_session_id     被検証セッション ID
#   target_pane_id        被検証ペイン ID
#   result                "pass" | "fail" | "warn"
#   [issues_count]        問題件数 (デフォルト 0)
#   [marker_raw]          捕捉したマーカー原文 (デフォルト "@@OE_VERIFY:{result}")
#
# F6: verification_started は Phase B (oe_verify_spawn) のみ、本関数は completed のみ emit
oe_verify_emit_completed() {
  local target_session_id="$1"
  local target_pane_id="$2"
  local result="$3"
  local issues_count="${4:-0}"
  local marker_raw="${5:-@@OE_VERIFY:${result}}"

  local payload
  payload="$(jq -cn \
    --argjson tpid "$target_pane_id" \
    --arg result "$result" \
    --argjson issues "$issues_count" \
    --arg marker_raw "$marker_raw" \
    '{target_pane_id: $tpid, result: $result, issues_count: $issues, marker_raw: $marker_raw}')"

  oe_audit_emit "verification_completed" "$target_session_id" "$target_pane_id" "" "$payload"
}

# _oe_verify_generate_session_id — 検証 agent 用の ULID 形式セッション ID を生成
# (bin/oe の oe_generate_session_id と同フォーマット: 14 桁数字 + 12 桁 Crockford base32)
_oe_verify_generate_session_id() {
  local ts rand
  ts="$(date -u +%Y%m%d%H%M%S)"
  rand="$(LC_ALL=C tr -dc '0-9A-HJKMNP-TV-Z' </dev/urandom | head -c 12)"
  printf '%s%s\n' "$ts" "$rand"
}

# oe_verify_run_phase — Step 4-3 Phase E: end-of-session 発火の検証フェーズ
#
# 引数: target_session_id target_pane_id1 [target_pane_id2 ...]
#
# 各 target pane に対して以下を順次実行 (MVP は逐次):
#   1. reviewer_session_id を生成
#   2. oe_verify_spawn → 検証 agent ペイン起動 + verification_started emit
#   3. 独立ポーリングループ: OE_POLL_INTERVAL 間隔で reviewer pane を scan
#      OE_SCAN_VERIFY_RESULT (Phase D F3 二値保持) を検出するまで待機
#   4. 検出時: oe_verify_write_kvs + oe_verify_emit_completed
#   5. CB タイムアウト (OE_CB_TIMEOUT) 超過時は当該検証スキップ
#
# 完了後: oe_verify_summary_update でセッション集計
# OE_VERIFY_PHASE_COMPLETED=1 をセット (cleanup の wez notify 発火条件)
#
# F1: monitor.sh の責務範囲を膨らませない (独立ループ)
# F2: OE_VERIFY_MANAGED_PANES / OE_VERIFY_DONE_PANES は通常ペイン配列と別物
oe_verify_run_phase() {
  local target_session_id="$1"
  shift

  if [[ $# -eq 0 ]]; then
    return 0
  fi

  local target_envelope_path="/tmp/oe-${target_session_id}-envelope.json"

  local target_pane_id
  for target_pane_id in "$@"; do
    local reviewer_session_id
    reviewer_session_id="$(_oe_verify_generate_session_id)"

    oe_verify_spawn \
      "$reviewer_session_id" \
      "$target_pane_id" \
      "$target_session_id" \
      "$target_envelope_path"

    local reviewer_pane_id="$OE_VERIFY_PANE_ID"
    OE_VERIFY_MANAGED_PANES+=("$reviewer_pane_id")

    # 独立ポーリングループ
    local start_seconds=$SECONDS
    local verified=0
    while true; do
      sleep "$OE_POLL_INTERVAL"
      oe_capture_scan "$reviewer_pane_id"

      if [[ -n "$OE_SCAN_VERIFY_RESULT" ]]; then
        oe_verify_write_kvs \
          "$target_session_id" \
          "$target_pane_id" \
          "$reviewer_session_id" \
          "$reviewer_pane_id" \
          "$OE_SCAN_VERIFY_RESULT" \
          0 \
          "@@OE_VERIFY:${OE_SCAN_VERIFY_RESULT}"
        oe_verify_emit_completed \
          "$target_session_id" \
          "$target_pane_id" \
          "$OE_SCAN_VERIFY_RESULT" \
          0 \
          "@@OE_VERIFY:${OE_SCAN_VERIFY_RESULT}"
        OE_VERIFY_DONE_PANES+=("$reviewer_pane_id")
        verified=1
        break
      fi

      # CB: タイムアウト
      if [[ $((SECONDS - start_seconds)) -ge $OE_CB_TIMEOUT ]]; then
        local cb_payload
        cb_payload="$(jq -cn --argjson tpid "$target_pane_id" \
          '{reason:"verification_timeout", target_pane_id:$tpid}')"
        oe_audit_emit "circuit_breaker_triggered" "$target_session_id" "$target_pane_id" "" "$cb_payload" || true
        break
      fi
    done

    # verified は将来の拡張 (リトライ判断) で参照する想定 — 現状は debug 用に保持
    : "$verified"
  done

  oe_verify_summary_update "$target_session_id"
  OE_VERIFY_PHASE_COMPLETED=1
}
