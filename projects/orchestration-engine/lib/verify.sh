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

  # task.description: 検証指示の概要 + skill 出力 → @@OE_VERIFY マッピング (F-SO-1)
  # skill prompt 本文は engine に持たない (F4)。skill 規約 (Spec Compliant / Issues Found) と
  # engine プロトコル (@@OE_VERIFY:pass/fail/warn) の対応を明示しないと検証 agent ごとに揺れる。
  local task_desc
  task_desc="Compliance Review per the adversarial-review skill listed in task.use_skills. Read task.read_docs in order (skill, target envelope, audit JSONL, KVS, verify-inputs) and execute the review.

Emit exactly one of the following on a new line at the very end, immediately before exiting:
- @@OE_VERIFY:pass — when the skill report concludes \"Status: Spec Compliant\" with no critical issues (advisory recommendations are acceptable for pass)
- @@OE_VERIFY:fail — when the skill report concludes \"Status: Issues Found\" with one or more critical issues (Missing requirements / Extra unneeded work / Misunderstandings that affect functionality)
- @@OE_VERIFY:warn — when the skill report concludes \"Status: Spec Compliant\" but the Recommendations section is non-trivial, or when issues are observed but are minor / advisory / non-blocking

The marker must be on its own line, no surrounding spaces, exact case. The shell will append @@OE_EXIT:0 automatically."

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
        shared_kvs_path: null
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

  # 完了報告: audit JSONL から target_pane_id の最後の state_change イベントを抽出
  # Copilot #3 反映: 全セッションの最後の state_change ではなく、target_pane_id でフィルタする
  # (oe_verify_run_phase は複数 target pane を順次扱うため、混線を避ける)
  local last_state_change
  if [[ -f "$audit_path" ]]; then
    last_state_change="$(jq -s --argjson pid "$target_pane_id" \
      'map(select(.event_type == "state_change" and .pane_id == $pid)) | last // null' \
      "$audit_path")"
    if [[ "$last_state_change" == "null" ]]; then
      last_state_change="(no state_change events recorded for target_pane_id=${target_pane_id} in audit log)"
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
    # iter2 #3252519559 反映: PROJECT_DIR で git を実行することで、caller の CWD に依存しない安定した
    # 結果を得る。target task の実際の output_dir に紐づけるのは派生 Issue #92 のスコープ。
    local git_output
    if git_output="$(git -C "$PROJECT_DIR" diff --name-only 2>/dev/null)" && [[ -n "$git_output" ]]; then
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
#   [ai_cli]              使用する AI CLI (デフォルト: ${OE_VERIFY_AI_CLI:-claude})
#   [ai_model]            使用するモデル   (デフォルト: ${OE_VERIFY_AI_MODEL:-claude-sonnet-4-6})
#
# 戻り値:
#   OE_VERIFY_PANE_ID         検証 agent ペイン ID
#   OE_VERIFY_ENVELOPE_PATH   検証用 envelope パス
#   OE_VERIFY_PROMPT_PATH     構築されたプロンプト (3 入力) ファイルパス
#
# Step 4-4 Phase A 反映 (F-8): ai_model 引数追加 + ディスパッチャ (_oe_spawn_build_cli_command) 経由化
oe_verify_spawn() {
  local reviewer_session_id="$1"
  local target_pane_id="$2"
  local target_session_id="$3"
  local target_envelope_path="$4"
  local ai_cli="${5:-${OE_VERIFY_AI_CLI:-claude}}"
  local ai_model="${6:-${OE_VERIFY_AI_MODEL:-claude-sonnet-4-6}}"

  OE_VERIFY_PANE_ID=""

  # 検証 agent 用ペインを準備 (Step 4-2 の lib/spawn.sh を再利用)
  oe_spawn_prepare_pane
  local reviewer_pane_id="$OE_SPAWN_PANE_ID"

  # Copilot #5 反映: prepare_pane 直後に OE_VERIFY_MANAGED_PANES に追加。
  # 以降の envelope 生成 / send / audit emit のいずれかで失敗しても、cleanup.sh が
  # 確実にこの reviewer pane を kill できるようにする (orphan pane 防止)。
  OE_VERIFY_MANAGED_PANES+=("$reviewer_pane_id")

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

  # 送信コマンド: ai_cli ディスパッチャ経由で組み立て + サブシェルで @@OE_EXIT 付与 + tee で file 出力。
  # Step 4-4 Phase C.5 反映: wez pane capture 経路 (viewport-only + tail 後処理) では
  # 長文 review markdown 中の @@OE_VERIFY 行が scrollback に押し出されて拾えない。
  # `( cmd 2>&1 ; printf @@OE_EXIT ) | tee log_path` の形にすることで:
  #   - claude/cursor の stdout/stderr と @@OE_EXIT の両方を 1 つの log file に同順序で記録
  #   - pane (TTY) には引き続き出力されるので人間可視性は維持
  #   - bash の PIPESTATUS 依存を回避 (内側 sub-shell 内の $? で claude exit code を反映)
  # scan は file 経路 (_oe_verify_scan_log_file → capture.sh:_oe_scan_log_file) に切替済み。
  #
  # umask 077: reviewer transcript も秘密情報を含み得るため共有 /tmp 上で world-readable に
  #   しない (target と統一・実装SO #114 反映)。tee はパイプライン側なので umask はパイプライン
  #   全体を囲う外側 subshell で設定する。→ ログは 0600。
  #   rm -f: umask は新規作成時のみ mode を決めるため、既存ログ (前回 run 残り等) があると tee が
  #   既存 mode を保持して 0600 保証が崩れる。tee 直前に削除して必ず作り直す (Copilot PR #216 指摘・target と対称)。
  local log_path="/tmp/oe-${reviewer_session_id}-reviewer.log"
  local base_cli_command
  base_cli_command="$(_oe_spawn_build_cli_command "$ai_cli" "$ai_model" "$OE_VERIFY_ENVELOPE_PATH" "$PROJECT_DIR")"
  local cli_command
  cli_command="( umask 077 ; rm -f \"${log_path}\" ; ( ${base_cli_command} 2>&1 ; printf '\\n@@OE_EXIT:%d\\n' \$? ) | tee \"${log_path}\" )"

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
#   [exit_code]           F-SO-2: 検証 agent の exit_code が非 0 のとき指定。空文字は省略扱い
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
  local exit_code="${8:-}"

  local state_file="${OE_STATE_DIR}/${target_session_id}.state.json"
  local tmp_file="${OE_STATE_DIR}/.${target_session_id}.state.json.$$"

  if [[ ! -f "$state_file" ]]; then
    echo "oe_verify_write_kvs: state file not found: $state_file" >&2
    return 1
  fi

  local completed_at
  completed_at="$(date -u +"%Y-%m-%dT%H:%M:%S+00:00")"

  # verification.{target_pane_id} を更新 (既存 map は維持)
  # F-SO-2: exit_code が指定された場合のみ exit_code フィールドを含める
  if [[ -n "$exit_code" ]]; then
    jq \
      --arg pid "$target_pane_id" \
      --arg result "$result" \
      --arg rsid "$reviewer_session_id" \
      --argjson rpid "$reviewer_pane_id" \
      --argjson issues "$issues_count" \
      --arg marker_raw "$marker_raw" \
      --arg completed_at "$completed_at" \
      --argjson exit_code "$exit_code" \
      '.verification = ((.verification // {}) | .[$pid] = {
         result: $result,
         reviewer_session_id: $rsid,
         reviewer_pane_id: $rpid,
         issues_count: $issues,
         marker_raw: $marker_raw,
         completed_at: $completed_at,
         exit_code: $exit_code
       })' \
      "$state_file" > "$tmp_file"
  else
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
  fi

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

  local total passed failed warned protocol_errors timeouts
  total="$(jq '(.verification // {}) | length' "$state_file")"
  passed="$(jq '(.verification // {}) | to_entries | map(select(.value.result == "pass")) | length' "$state_file")"
  failed="$(jq '(.verification // {}) | to_entries | map(select(.value.result == "fail")) | length' "$state_file")"
  warned="$(jq '(.verification // {}) | to_entries | map(select(.value.result == "warn")) | length' "$state_file")"
  # F-SO-2/12: exit_code が non-zero として記録されたエントリ数
  protocol_errors="$(jq '(.verification // {}) | to_entries | map(select(.value.exit_code != null and .value.exit_code != 0)) | length' "$state_file")"
  # Copilot #2 反映: timeout / exit_without_verify_marker で verification entry を残せなかった件数
  # (oe_verify_run_phase が OE_VERIFY_TIMEOUTS_LOCAL でカウント)
  timeouts="${OE_VERIFY_TIMEOUTS_LOCAL:-0}"

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
    --argjson protocol_errors "$protocol_errors" \
    --argjson timeouts "$timeouts" \
    '.verification_summary = {
       total: $total,
       passed: $passed,
       failed: $failed,
       warned: $warned,
       fail_rate: $fail_rate,
       protocol_errors: $protocol_errors,
       timeouts: $timeouts
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

# _oe_verify_scan_log_file — Step 4-4 Phase C.5: reviewer の出力 log file を tail で走査し
# 既存の _oe_capture_scan_parse に流して二値 (OE_SCAN_EXIT_CODE / OE_SCAN_VERIFY_RESULT) を設定する。
#
# 引数:
#   log_path   reviewer の stdout+stderr+@@OE_EXIT が書かれる file path
#   [lines]    末尾何行を読むか (デフォルト 5000、claude review は markdown + diff 引用で千行になり得るため大きめ)
#
# 戻り値: OE_SCAN_* 変数群を設定 (_oe_capture_scan_parse と同じインターフェース)
#         file 不在時は OE_SCAN_* を空のまま return 0 (cleanup と race しても無害に継続)
#
# 設計背景:
#   wez pane capture --lines N は wezterm cli get-text の viewport-only 出力に tail -n N を
#   適用する実装 (wezterm-ai-mode ADR-004:65)。長文 markdown では @@OE_VERIFY が viewport 外に
#   押し出されて拾えない。reviewer 送信側で `( cmd ; printf @@OE_EXIT ) | tee log_path` に
#   切替えており、本関数は log file 経路で同じ parse を行う。
#
# #114/#98: log-file 走査の実体は capture.sh:_oe_scan_log_file に集約済み (target 経路と共有する
#   単一 primitive)。本関数は reviewer 呼び出し側の名前を維持する薄いラッパ。正規化 (#112) も
#   共通コア側で適用される。
_oe_verify_scan_log_file() {
  _oe_scan_log_file "$1" "${2:-5000}"
}

# _oe_verify_generate_session_id — 検証 agent 用の ULID 形式セッション ID を生成
# (bin/oe の oe_generate_session_id と同フォーマット: 14 桁数字 + 12 桁 Crockford base32)
#
# Copilot #4 反映: tr の出力を head -c で早期 close すると tr に SIGPIPE が飛び、
# set -o pipefail 環境下で assignment が失敗する。/dev/urandom から固定バイト数を先に
# 読んでから tr で filter する形に変更 (パイプの早期 close を回避)。
_oe_verify_generate_session_id() {
  local ts raw rand
  ts="$(date -u +%Y%m%d%H%M%S)"
  # 4096 バイト読めば Crockford base32 alphabet (32/256 = 12.5%) で期待 ~512 valid 文字、
  # 12 文字必要なので統計的に十分なマージン
  raw="$(LC_ALL=C head -c 4096 /dev/urandom | LC_ALL=C tr -dc '0-9A-HJKMNP-TV-Z')"
  rand="${raw:0:12}"
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
# F-SO-2: OE_SCAN_EXIT_CODE 非 0 のとき verification_protocol_error 監査 + KVS に exit_code 併記
# F-SO-4: 検証ペインは verbose 出力のため oe_capture_scan に lines=200 を渡す
# F-SO-6: ai_cli (デフォルト cursor) を引数で受け取り oe_verify_spawn に伝播
#
# Codex P2 + Copilot 反映:
#   - 記録は @@OE_VERIFY と @@OE_EXIT の **両方** が見えた時点で行う (timing window で
#     片方しか見えていない状態の record を避ける)
#   - @@OE_EXIT が先に見えて @@OE_VERIFY が出ない場合は protocol error として早期 break
#   - timeout / protocol-only error の件数を local counter で追跡し、summary に timeouts として記録
#   - OE_VERIFY_PHASE_COMPLETED は「検証フェーズが走った」事実を示すフラグであり、
#     timeouts / protocol_errors の有無は notify 本文で別途表現する (cleanup.sh の wez notify)
oe_verify_run_phase() {
  local target_session_id="$1"
  shift

  # 末尾オプション: ai_cli / ai_model (位置引数ではなく環境変数で渡す設計、後方互換維持)
  # Step 4-4 Phase A 反映: デフォルトを cursor → claude / sonnet-4-6 に変更
  local ai_cli="${OE_VERIFY_AI_CLI:-claude}"
  local ai_model="${OE_VERIFY_AI_MODEL:-claude-sonnet-4-6}"

  if [[ $# -eq 0 ]]; then
    return 0
  fi

  local target_envelope_path="/tmp/oe-${target_session_id}-envelope.json"

  # local counter: 本フェーズで発生した timeout 件数 (verify_result も emit されなかった pane)
  # summary に timeouts として記録するため OE_VERIFY_TIMEOUTS_LOCAL を export
  local timeouts_local=0

  local target_pane_id
  for target_pane_id in "$@"; do
    local reviewer_session_id
    reviewer_session_id="$(_oe_verify_generate_session_id)"
    OE_VERIFY_REVIEWER_SESSION_IDS+=("$reviewer_session_id")

    oe_verify_spawn \
      "$reviewer_session_id" \
      "$target_pane_id" \
      "$target_session_id" \
      "$target_envelope_path" \
      "$ai_cli" \
      "$ai_model"

    local reviewer_pane_id="$OE_VERIFY_PANE_ID"
    # 注: oe_verify_spawn は内部で OE_VERIFY_MANAGED_PANES に append 済み
    # (Copilot #5 反映: prepare_pane 直後に登録、途中失敗時の cleanup 取り逃しを防ぐ)

    # Step 4-4 Phase C.5: reviewer 出力は file redirect (tee) で /tmp に書かれる。
    # wez pane capture (viewport-only + tail 後処理) では scrollback に押し出された
    # @@OE_VERIFY 行を拾えないため、file 経路で走査する。
    local reviewer_log_path="/tmp/oe-${reviewer_session_id}-reviewer.log"

    # 独立ポーリングループ
    local start_seconds=$SECONDS
    local resolved=0
    while true; do
      sleep "$OE_POLL_INTERVAL"
      _oe_verify_scan_log_file "$reviewer_log_path"

      # Codex P2: @@OE_VERIFY と @@OE_EXIT の **両方** が見えるまで待つ
      # 片方しか見えていない状態で記録すると、agent が後で非 0 終了した場合に
      # exit_code を取り逃して protocol error が隠蔽される
      if [[ -n "$OE_SCAN_VERIFY_RESULT" && -n "$OE_SCAN_EXIT_CODE" ]]; then
        # F-SO-2: exit_code が非 0 ならプロトコルエラー監査 + KVS に exit_code 併記
        local exit_code_field=""
        if [[ "$OE_SCAN_EXIT_CODE" != "0" ]]; then
          exit_code_field="$OE_SCAN_EXIT_CODE"
          local protocol_payload
          protocol_payload="$(jq -cn \
            --argjson tpid "$target_pane_id" \
            --arg result "$OE_SCAN_VERIFY_RESULT" \
            --argjson exit_code "$OE_SCAN_EXIT_CODE" \
            --arg marker_raw "@@OE_VERIFY:${OE_SCAN_VERIFY_RESULT}" \
            '{target_pane_id: $tpid, verify_result: $result, exit_code: $exit_code, marker_raw: $marker_raw}')"
          oe_audit_emit "verification_protocol_error" "$target_session_id" "$target_pane_id" "" "$protocol_payload" || true
        fi

        oe_verify_write_kvs \
          "$target_session_id" \
          "$target_pane_id" \
          "$reviewer_session_id" \
          "$reviewer_pane_id" \
          "$OE_SCAN_VERIFY_RESULT" \
          0 \
          "@@OE_VERIFY:${OE_SCAN_VERIFY_RESULT}" \
          "$exit_code_field"
        oe_verify_emit_completed \
          "$target_session_id" \
          "$target_pane_id" \
          "$OE_SCAN_VERIFY_RESULT" \
          0 \
          "@@OE_VERIFY:${OE_SCAN_VERIFY_RESULT}"
        OE_VERIFY_DONE_PANES+=("$reviewer_pane_id")
        resolved=1
        break
      fi

      # Copilot #1 反映 + iter2 #3252519542: @@OE_EXIT は見えたが @@OE_VERIFY が出ていない → protocol error として早期 break
      # exit_code が 0 でも (reviewer が正常終了したが marker emit を忘れた) protocol 違反とする。
      # 30 分の CB timeout 待ちを避け、即座に protocol error として記録する。
      if [[ -z "$OE_SCAN_VERIFY_RESULT" && -n "$OE_SCAN_EXIT_CODE" ]]; then
        local protocol_payload
        protocol_payload="$(jq -cn \
          --argjson tpid "$target_pane_id" \
          --argjson exit_code "$OE_SCAN_EXIT_CODE" \
          '{target_pane_id: $tpid, exit_code: $exit_code, reason: "exit_without_verify_marker"}')"
        oe_audit_emit "verification_protocol_error" "$target_session_id" "$target_pane_id" "" "$protocol_payload" || true
        # verification 結果が無いまま break。verification entry は書かない (timeouts と同様の扱い)
        timeouts_local=$((timeouts_local + 1))
        resolved=1
        break
      fi

      # CB: タイムアウト
      if [[ $((SECONDS - start_seconds)) -ge $OE_CB_TIMEOUT ]]; then
        local cb_payload
        cb_payload="$(jq -cn --argjson tpid "$target_pane_id" \
          '{reason:"verification_timeout", target_pane_id:$tpid}')"
        oe_audit_emit "circuit_breaker_triggered" "$target_session_id" "$target_pane_id" "" "$cb_payload" || true
        timeouts_local=$((timeouts_local + 1))
        break
      fi
    done

    # resolved は将来の拡張 (リトライ判断) で参照する想定 — 現状は debug 用に保持
    : "$resolved"
  done

  # timeout / exit_without_verify_marker 件数を summary_update に渡すため export
  export OE_VERIFY_TIMEOUTS_LOCAL="$timeouts_local"
  oe_verify_summary_update "$target_session_id"
  OE_VERIFY_PHASE_COMPLETED=1
}
