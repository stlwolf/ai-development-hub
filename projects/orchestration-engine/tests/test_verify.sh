#!/usr/bin/env bash
set -euo pipefail

# test_verify.sh — Step 4-3 verify.sh のユニットテスト (Phase B)
#
# Phase B 対象:
#   - oe_verify_envelope_create: 検証用 envelope の生成 + validate-envelope.sh PASS
#   - oe_verify_spawn: wez モック経由のペイン準備 + 送信 + verification_started emit
# Phase C/D で追加: oe_verify_prompt_build, KVS 書き込み, verification_completed emit

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
export PROJECT_DIR

_TMP_DIR="${SCRIPT_DIR}/.tmp_test_verify_$$"
mkdir -p "$_TMP_DIR/bin" "$_TMP_DIR/logs" "$_TMP_DIR/data/state" "$_TMP_DIR/data/audit"
trap 'rm -rf "$_TMP_DIR"; rm -f /tmp/oe-RTEST_REVIEWER_01-verify-envelope.json /tmp/oe-RTEST_REVIEWER_02-verify-envelope.json /tmp/oe-RTEST_SPAWN_REVIEWER_01-verify-envelope.json /tmp/oe-RTEST_SPAWN_REVIEWER_01-verify-inputs.md /tmp/oe-RTEST_PROMPT_01-verify-inputs.md /tmp/oe-RTEST_PROMPT_02-verify-inputs.md /tmp/oe-RTEST_PROMPT_GIT-verify-inputs.md /tmp/oe-RTEST_ENV_WITH_PROMPT-verify-envelope.json' EXIT

PASS=0
FAIL=0

assert_eq() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $label"
    (( PASS++ )) || true
  else
    echo "  FAIL: $label (expected='$expected', actual='$actual')"
    (( FAIL++ )) || true
  fi
}

# --- git モック (Phase C: outputs[] 空 → git diff フォールバックの検証用) ---
# OE_MOCK_GIT_FILES が設定されていればそれを返し、未設定なら空文字列を返す
cat > "${_TMP_DIR}/bin/git" <<'EOF'
#!/usr/bin/env bash
# iter2 #3252519559 反映: verify.sh は `git -C "$PROJECT_DIR" ...` 形式で呼ぶ。先頭の -C <dir> を skip。
# #92 (設計 D): commit 範囲評価のため diff <range> / log / rev-parse を追加でモックする。
args=("$@")
i=0
if [[ "${args[0]:-}" == "-C" && -n "${args[1]:-}" ]]; then
  i=2
fi
sub="${args[i]:-}"
if [[ "$sub" == "diff" && "${args[$((i+1))]:-}" == "--name-only" ]]; then
  # range 引数 (args[i+2]) の有無で range diff / working-tree diff を分岐:
  #   range あり → OE_MOCK_GIT_RANGE_FILES (commit 範囲) / range なし → OE_MOCK_GIT_FILES (working-tree)
  if [[ -n "${args[$((i+2))]:-}" ]]; then
    [[ -n "${OE_MOCK_GIT_RANGE_FILES:-}" ]] && printf '%s\n' "${OE_MOCK_GIT_RANGE_FILES}"
  else
    [[ -n "${OE_MOCK_GIT_FILES:-}" ]] && printf '%s\n' "${OE_MOCK_GIT_FILES}"
  fi
  exit 0
fi
if [[ "$sub" == "log" ]]; then
  [[ -n "${OE_MOCK_GIT_LOG:-}" ]] && printf '%s\n' "${OE_MOCK_GIT_LOG}"
  exit 0
fi
if [[ "$sub" == "ls-files" ]]; then
  [[ -n "${OE_MOCK_GIT_UNTRACKED:-}" ]] && printf '%s\n' "${OE_MOCK_GIT_UNTRACKED}"
  exit 0
fi
if [[ "$sub" == "rev-parse" ]]; then
  printf '%s\n' "${OE_MOCK_GIT_HEAD:-0000000000000000000000000000000000000000}"
  exit 0
fi
if [[ "$sub" == "status" ]]; then
  [[ -n "${OE_MOCK_GIT_DIRTY:-}" ]] && printf '%s\n' "${OE_MOCK_GIT_DIRTY}"
  exit 0
fi
# その他の git は素通り (実 git を使う)
exec /usr/bin/env -i PATH=/usr/bin:/bin /usr/bin/git "$@"
EOF
chmod +x "${_TMP_DIR}/bin/git"

# --- wez モック: split / send を記録 ---
cat > "${_TMP_DIR}/bin/wez" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

log_dir="${OE_MOCK_LOG_DIR:?}"

if [[ "${1:-}" == "pane" && "${2:-}" == "split" ]]; then
  shift 2
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --bottom|--right|--left|--top|--wait-ready|--json) shift ;;
      --percent|--timeout|--pane-id|--cwd)
        [[ $# -ge 2 ]] || exit 1
        shift 2
        ;;
      *)
        echo "unexpected wez split option: $1" >&2
        exit 1
        ;;
    esac
  done
  # 連番ペイン ID (888, 889, ...) を返す
  count_file="${log_dir}/split_count"
  current=888
  [[ -f "$count_file" ]] && current=$(<"$count_file")
  echo "$current" > "$count_file"
  next=$(( current + 1 ))
  echo "$next" > "$count_file"
  echo "$current"
  exit 0
fi

if [[ "${1:-}" == "pane" && "${2:-}" == "send" ]]; then
  pane_id="${3:-}"
  payload="${4:-}"
  printf '%s|%s\n' "$pane_id" "$payload" >> "${log_dir}/send.log"
  exit 0
fi

echo "unexpected wez call: $*" >&2
exit 1
EOF
chmod +x "${_TMP_DIR}/bin/wez"

export PATH="${_TMP_DIR}/bin:${PATH}"
export OE_MOCK_LOG_DIR="${_TMP_DIR}/logs"
export OE_DATA_DIR="${_TMP_DIR}/data"

# constants.sh / audit.sh / envelope.sh / spawn.sh / verify.sh をロード
# shellcheck source=../lib/constants.sh
source "${PROJECT_DIR}/lib/constants.sh"
# shellcheck source=../lib/audit.sh
source "${PROJECT_DIR}/lib/audit.sh"
# shellcheck source=../lib/envelope.sh
source "${PROJECT_DIR}/lib/envelope.sh"
# shellcheck source=../lib/spawn.sh
source "${PROJECT_DIR}/lib/spawn.sh"
# shellcheck source=../lib/verify.sh
source "${PROJECT_DIR}/lib/verify.sh"

# ---- oe_verify_envelope_create ----
echo "=== oe_verify_envelope_create ==="

# 被検証 envelope (target) を先に生成 (read_docs から参照される)
target_session_id="01KRMYHMET73WDE32JXD1TZ0A4"
target_pane_id=42
target_envelope_path="/tmp/oe-${target_session_id}-envelope.json"
oe_envelope_create "$target_session_id" "$target_pane_id" "Target task description" "./output" 300
# oe_envelope_create が生成したファイルパスを target として使う
target_envelope_path="$OE_ENVELOPE_PATH"

reviewer_session_id="RTEST_REVIEWER_01"
reviewer_pane_id=888

echo "-- 検証用 envelope を生成 + validate-envelope.sh PASS --"
oe_verify_envelope_create \
  "$reviewer_session_id" \
  "$reviewer_pane_id" \
  "$target_pane_id" \
  "$target_session_id" \
  "$target_envelope_path"

assert_eq "OE_VERIFY_ENVELOPE_PATH set" "/tmp/oe-${reviewer_session_id}-verify-envelope.json" "$OE_VERIFY_ENVELOPE_PATH"
assert_eq "verify envelope file exists" "true" "$( [[ -f "$OE_VERIFY_ENVELOPE_PATH" ]] && echo true || echo false )"

JSON="$OE_VERIFY_ENVELOPE_PATH"

echo "-- envelope フィールド検証 --"
assert_eq "session_id" "$reviewer_session_id" "$(jq -r '.session_id' "$JSON")"
assert_eq "pane_id" "$reviewer_pane_id" "$(jq -r '.pane_id' "$JSON")"
assert_eq "task.exit_conditions.marker" "@@OE_VERIFY" "$(jq -r '.task.exit_conditions.marker' "$JSON")"
assert_eq "task.exit_conditions.timeout_seconds" "$OE_CB_TIMEOUT" "$(jq -r '.task.exit_conditions.timeout_seconds' "$JSON")"
assert_eq "task.use_skills" '["adversarial-review"]' "$(jq -c '.task.use_skills' "$JSON")"
assert_eq "context.parent_session_id" "$target_session_id" "$(jq -r '.context.parent_session_id' "$JSON")"
# F-SO-3: shared_kvs_path は null (schema 意図 = UC-2 並列協調用ディレクトリパス と乖離するため)
# KVS パスは read_docs 経由で参照する
assert_eq "context.shared_kvs_path = null (F-SO-3)" "null" \
  "$(jq -r '.context.shared_kvs_path' "$JSON")"

echo "-- task.read_docs に skill / 被検証 envelope / audit / KVS が含まれる --"
assert_eq "read_docs 件数" "4" "$(jq '.task.read_docs | length' "$JSON")"
assert_eq "read_docs[0] = skill path" "true" \
  "$(jq -r '.task.read_docs[0] | endswith("canonical/skills/adversarial-review/SKILL.md")' "$JSON")"
assert_eq "read_docs[1] = target envelope" "$target_envelope_path" "$(jq -r '.task.read_docs[1]' "$JSON")"
assert_eq "read_docs[2] = audit JSONL" "true" \
  "$(jq -r --arg sid "$target_session_id" '.task.read_docs[2] | endswith($sid + ".jsonl")' "$JSON")"
assert_eq "read_docs[3] = KVS state" "true" \
  "$(jq -r --arg sid "$target_session_id" '.task.read_docs[3] | endswith($sid + ".state.json")' "$JSON")"

echo "-- task.description に @@OE_VERIFY 指示が含まれる --"
assert_eq "description references @@OE_VERIFY" "true" \
  "$(jq -r '.task.description | test("@@OE_VERIFY")' "$JSON")"

# F-SO-1: skill 出力 → @@OE_VERIFY マッピング (Spec Compliant→pass / Issues Found→fail / advisory→warn) 明示
assert_eq "F-SO-1: description に Spec Compliant マッピング" "true" \
  "$(jq -r '.task.description | test("Spec Compliant")' "$JSON")"
assert_eq "F-SO-1: description に Issues Found マッピング" "true" \
  "$(jq -r '.task.description | test("Issues Found")' "$JSON")"
assert_eq "F-SO-1: description に @@OE_VERIFY:pass" "true" \
  "$(jq -r '.task.description | test("@@OE_VERIFY:pass")' "$JSON")"
assert_eq "F-SO-1: description に @@OE_VERIFY:fail" "true" \
  "$(jq -r '.task.description | test("@@OE_VERIFY:fail")' "$JSON")"
assert_eq "F-SO-1: description に @@OE_VERIFY:warn" "true" \
  "$(jq -r '.task.description | test("@@OE_VERIFY:warn")' "$JSON")"

echo ""
echo "-- 異なる reviewer_session_id で再生成 --"
oe_verify_envelope_create \
  "RTEST_REVIEWER_02" \
  889 \
  43 \
  "$target_session_id" \
  "$target_envelope_path"
assert_eq "OE_VERIFY_ENVELOPE_PATH 更新" "/tmp/oe-RTEST_REVIEWER_02-verify-envelope.json" "$OE_VERIFY_ENVELOPE_PATH"
assert_eq "session_id 更新" "RTEST_REVIEWER_02" "$(jq -r '.session_id' "$OE_VERIFY_ENVELOPE_PATH")"
assert_eq "pane_id 更新" "889" "$(jq -r '.pane_id' "$OE_VERIFY_ENVELOPE_PATH")"

# ---- oe_verify_spawn (wez モック経由) ----
echo ""
echo "=== oe_verify_spawn (wez mock) ==="

# split mock が次に返す ID は 888
echo "888" > "${OE_MOCK_LOG_DIR}/split_count"

reviewer_session_id_for_spawn="RTEST_SPAWN_REVIEWER_01"
oe_verify_spawn \
  "$reviewer_session_id_for_spawn" \
  "$target_pane_id" \
  "$target_session_id" \
  "$target_envelope_path"

assert_eq "OE_VERIFY_PANE_ID set (mock の split で 888 を返した)" "888" "$OE_VERIFY_PANE_ID"
assert_eq "OE_VERIFY_ENVELOPE_PATH (spawn 後)" "/tmp/oe-${reviewer_session_id_for_spawn}-verify-envelope.json" "$OE_VERIFY_ENVELOPE_PATH"

echo "-- wez pane send 呼び出し記録 --"
send_log="${OE_MOCK_LOG_DIR}/send.log"
assert_eq "send.log にエントリ" "true" "$( [[ -s "$send_log" ]] && echo true || echo false )"
assert_eq "send pane_id" "888" "$(awk -F'|' 'NR==1{print $1}' "$send_log")"
assert_eq "send payload に verify envelope パス" "true" \
  "$(awk -F'|' -v sid="$reviewer_session_id_for_spawn" 'index($0, "/tmp/oe-" sid "-verify-envelope.json"){found=1} END{print (found+0==1) ? "true" : "false"}' "$send_log")"
assert_eq "send payload に @@OE_EXIT printf" "true" \
  "$(awk -F'|' 'index($0, "@@OE_EXIT"){found=1} END{print (found+0==1) ? "true" : "false"}' "$send_log")"

# Copilot #5: prepare_pane 直後に OE_VERIFY_MANAGED_PANES に追加されている (orphan pane 防止)
echo "-- Copilot #5: OE_VERIFY_MANAGED_PANES に reviewer pane が追加される --"
assert_eq "OE_VERIFY_MANAGED_PANES に 888 が含まれる" "true" \
  "$(printf '%s\n' "${OE_VERIFY_MANAGED_PANES[@]}" | grep -q '^888$' && echo true || echo false)"

echo "-- verification_started audit emit (target session の audit log に追記) --"
target_audit="${OE_AUDIT_DIR}/${target_session_id}.jsonl"
assert_eq "audit file exists" "true" "$( [[ -f "$target_audit" ]] && echo true || echo false )"
assert_eq "verification_started 1 件" "1" \
  "$(jq -r 'select(.event_type=="verification_started") | 1' "$target_audit" | wc -l | tr -d ' ')"
assert_eq "verification_started.pane_id = target_pane_id" "$target_pane_id" \
  "$(jq -r 'select(.event_type=="verification_started") | .pane_id' "$target_audit")"
assert_eq "verification_started.state = null" "null" \
  "$(jq -r 'select(.event_type=="verification_started") | .state' "$target_audit")"
assert_eq "payload.target_pane_id" "$target_pane_id" \
  "$(jq -r 'select(.event_type=="verification_started") | .payload.target_pane_id' "$target_audit")"
assert_eq "payload.target_session_id" "$target_session_id" \
  "$(jq -r 'select(.event_type=="verification_started") | .payload.target_session_id' "$target_audit")"
assert_eq "payload.reviewer_pane_id" "888" \
  "$(jq -r 'select(.event_type=="verification_started") | .payload.reviewer_pane_id' "$target_audit")"
assert_eq "payload.reviewer_session_id" "$reviewer_session_id_for_spawn" \
  "$(jq -r 'select(.event_type=="verification_started") | .payload.reviewer_session_id' "$target_audit")"

# ---- Phase C: oe_verify_prompt_build (#92 設計 D: commit 範囲 baseline..end 評価) ----
echo ""
echo "=== oe_verify_prompt_build (Phase C・#92 commit 範囲) ==="

# 補助シグナルの state_change (engine 分類状態)
oe_audit_emit "state_change" "$target_session_id" "$target_pane_id" "success" '{"from":"progress","to":"success"}'

target_kvs_file="${OE_STATE_DIR}/${target_session_id}.state.json"
_empty_outputs_kvs() {
  cat > "$target_kvs_file" <<'JSON'
{
  "session_id": "01KRMYHMET73WDE32JXD1TZ0A4",
  "pane_id": 42,
  "state": "success",
  "last_updated": "2026-05-15T12:34:56Z",
  "outputs": [],
  "blockers": []
}
JSON
}

# -- Case A: baseline からの全 footprint (committed + untracked) + commit log + pre-existing 注記 --
echo "-- Case A: 全 footprint (committed + untracked/uncommitted) --"
oe_audit_emit "session_start" "$target_session_id" "$target_pane_id" "" '{"git_head":"BASE111","baseline_dirty":["docs/preexisting.md"]}'
oe_audit_emit "session_end" "$target_session_id" "$target_pane_id" "success" '{"git_head":"END222"}'
_empty_outputs_kvs
# git diff <baseline> (committed + 未コミット tracked) と ls-files (untracked) の両方を footprint に含む。
export OE_MOCK_GIT_RANGE_FILES="lib/feature.sh
docs/preexisting.md"
export OE_MOCK_GIT_UNTRACKED="newfile.txt"
export OE_MOCK_GIT_LOG="- abc123 feat: add feature
- def456 wip: docs"
oe_verify_prompt_build "RTEST_PROMPT_RANGE" "$target_pane_id" "$target_session_id" "$target_envelope_path"
unset OE_MOCK_GIT_RANGE_FILES OE_MOCK_GIT_UNTRACKED OE_MOCK_GIT_LOG
P="$OE_VERIFY_PROMPT_PATH"

assert_eq "OE_VERIFY_PROMPT_PATH set" "/tmp/oe-RTEST_PROMPT_RANGE-verify-inputs.md" "$P"
assert_eq "prompt file exists" "true" "$( [[ -f "$P" ]] && echo true || echo false )"
assert_eq "section: 要件" "true" "$(grep -q '^## 要件' "$P" && echo true || echo false)"
assert_eq "section: 完了報告 (commit log)" "true" "$(grep -q '^## 完了報告 (Commit log: BASE111..END222)' "$P" && echo true || echo false)"
assert_eq "section: engine 分類状態" "true" "$(grep -q '^## engine 分類状態' "$P" && echo true || echo false)"
assert_eq "section: 変更ファイル" "true" "$(grep -q '^## 変更ファイル' "$P" && echo true || echo false)"
assert_eq "commit_range メタ = BASE111..END222" "true" "$(grep -q '^commit_range: BASE111..END222' "$P" && echo true || echo false)"
assert_eq "要件 = target.task.description" "true" \
  "$(grep -q 'Target task description' "$P" && echo true || echo false)"
assert_eq "完了報告に commit log (abc123)" "true" \
  "$(grep -q 'abc123 feat: add feature' "$P" && echo true || echo false)"
assert_eq "engine 分類状態に state_change イベント" "true" \
  "$(grep -qE '"event_type": ?"state_change"' "$P" && echo true || echo false)"
assert_eq "footprint に committed file (lib/feature.sh)" "true" \
  "$(grep -q '^- lib/feature.sh' "$P" && echo true || echo false)"
assert_eq "footprint に untracked/uncommitted file (newfile.txt) [codex 欠陥修正]" "true" \
  "$(grep -q '^- newfile.txt' "$P" && echo true || echo false)"
assert_eq "変更ファイル note に footprint 明示" "true" \
  "$(grep -q 'footprint' "$P" && echo true || echo false)"
assert_eq "pre-existing 注記 (docs/preexisting.md)" "true" \
  "$(grep -qF -- '- docs/preexisting.md  ⚠ pre-existing' "$P" && echo true || echo false)"

# -- Case B: commits あり but footprint 空 (空/revert コミット) → placeholder (degraded に誤フォールバックしない) --
echo ""
echo "-- Case B: commits あり + footprint 空 → 'no file changes since baseline' [cursor 欠陥修正] --"
# session_start/end は Case A の pane42 baseline BASE111..END222 が残る。
# git diff <baseline> / untracked を空に、commit log は非空 (空 or revert コミットの想定)。
_empty_outputs_kvs
export OE_MOCK_GIT_LOG="- ccc333 revert: undo previous"
oe_verify_prompt_build "RTEST_PROMPT_EMPTY" "$target_pane_id" "$target_session_id" "$target_envelope_path"
unset OE_MOCK_GIT_LOG
PE="$OE_VERIFY_PROMPT_PATH"

assert_eq "empty footprint: 完了報告に commit (ccc333)" "true" \
  "$(grep -q 'ccc333 revert' "$PE" && echo true || echo false)"
assert_eq "empty footprint: 変更ファイルは 'no file changes since baseline'" "true" \
  "$(grep -q 'no file changes since baseline' "$PE" && echo true || echo false)"
assert_eq "empty footprint: degraded/未コミット と誤表示しない" "false" \
  "$(grep -qE 'degraded|worker が未コミット' "$PE" && echo true || echo false)"

# -- Case C: KVS outputs[] は commit 範囲より優先される --
echo ""
echo "-- Case C: KVS outputs[] 優先 --"
cat > "$target_kvs_file" <<'JSON'
{
  "session_id": "01KRMYHMET73WDE32JXD1TZ0A4",
  "pane_id": 42,
  "state": "success",
  "last_updated": "2026-05-15T12:34:56Z",
  "outputs": ["src/foo.sh", "tests/test_foo.sh"],
  "blockers": []
}
JSON
export OE_MOCK_GIT_RANGE_FILES="lib/should_not_appear.sh"
oe_verify_prompt_build "RTEST_PROMPT_OUTPUTS" "$target_pane_id" "$target_session_id" "$target_envelope_path"
unset OE_MOCK_GIT_RANGE_FILES
PO="$OE_VERIFY_PROMPT_PATH"

assert_eq "outputs[] 優先: src/foo.sh" "true" \
  "$(grep -q '^- src/foo.sh' "$PO" && echo true || echo false)"
assert_eq "outputs[] 優先: range file は出ない" "false" \
  "$(grep -q 'should_not_appear' "$PO" && echo true || echo false)"

# -- Case D: baseline / state_change は target_pane_id でフィルタ (別 pane を混入させない) --
echo ""
echo "-- Case D: pane_id フィルタ (baseline + state_change) --"
# 別 pane 99 の session_start / state_change を混入させても pane 42 の baseline / 分類が選ばれる。
oe_audit_emit "session_start" "$target_session_id" 99 "" '{"git_head":"OTHERBASE","baseline_dirty":[]}'
oe_audit_emit "state_change" "$target_session_id" 99 "partial" '{"from":"progress","to":"partial","note":"different pane"}'
_empty_outputs_kvs
export OE_MOCK_GIT_RANGE_FILES="lib/pane42.sh"
export OE_MOCK_GIT_LOG="- aaa111 pane42 commit"
oe_verify_prompt_build "RTEST_PROMPT_FILTER" "$target_pane_id" "$target_session_id" "$target_envelope_path"
unset OE_MOCK_GIT_RANGE_FILES OE_MOCK_GIT_LOG
filter_prompt_path="$OE_VERIFY_PROMPT_PATH"

assert_eq "pane フィルタ: commit_range は pane 42 baseline (BASE111)" "true" \
  "$(grep -q '^commit_range: BASE111..END222' "$filter_prompt_path" && echo true || echo false)"
assert_eq "pane フィルタ: 別 pane baseline (OTHERBASE) は使わない" "false" \
  "$(grep -q 'OTHERBASE' "$filter_prompt_path" && echo true || echo false)"
assert_eq "pane フィルタ: prompt に target pane_id=42" "true" \
  "$(grep -q '"pane_id": 42' "$filter_prompt_path" && echo true || echo false)"
assert_eq "pane フィルタ: 別 pane 99 の state_change は混入しない" "false" \
  "$(grep -q '"pane_id": 99' "$filter_prompt_path" && echo true || echo false)"

# -- Case E: baseline 未解決 (session_start なし) → degraded working-tree diff --
echo ""
echo "-- Case E: baseline 未解決 → degraded working-tree diff --"
# 別 session (audit に session_start なし) を使い baseline を未解決にする。
nobase_sid="RTEST_NOBASE_SID"
export OE_MOCK_GIT_FILES="lib/degraded.sh"
oe_verify_prompt_build "RTEST_PROMPT_NOBASE" "$target_pane_id" "$nobase_sid" "$target_envelope_path"
unset OE_MOCK_GIT_FILES
PN="$OE_VERIFY_PROMPT_PATH"

assert_eq "degraded: commit_range 未解決" "true" \
  "$(grep -q '^commit_range: <未解決>' "$PN" && echo true || echo false)"
assert_eq "degraded: working-tree diff file (lib/degraded.sh)" "true" \
  "$(grep -q '^- lib/degraded.sh' "$PN" && echo true || echo false)"
assert_eq "degraded: 変更ファイル note に degraded + baseline 未解決 明示" "true" \
  "$(grep -q 'degraded: baseline 未解決' "$PN" && echo true || echo false)"

rm -f "/tmp/oe-RTEST_PROMPT_RANGE-verify-inputs.md" \
  "/tmp/oe-RTEST_PROMPT_EMPTY-verify-inputs.md" \
  "/tmp/oe-RTEST_PROMPT_OUTPUTS-verify-inputs.md" \
  "/tmp/oe-RTEST_PROMPT_FILTER-verify-inputs.md" \
  "/tmp/oe-RTEST_PROMPT_NOBASE-verify-inputs.md"

# ---- Phase C: oe_verify_envelope_create に prompt path を渡すと read_docs に 5 件目が追加される ----
echo ""
echo "=== oe_verify_envelope_create + verify_prompt_path (Phase C) ==="

oe_verify_envelope_create \
  "RTEST_ENV_WITH_PROMPT" \
  900 \
  "$target_pane_id" \
  "$target_session_id" \
  "$target_envelope_path" \
  "$OE_VERIFY_PROMPT_PATH"

JSON_WP="$OE_VERIFY_ENVELOPE_PATH"
assert_eq "read_docs 件数 (prompt 含む)" "5" "$(jq '.task.read_docs | length' "$JSON_WP")"
assert_eq "read_docs[4] = prompt path" "$OE_VERIFY_PROMPT_PATH" "$(jq -r '.task.read_docs[4]' "$JSON_WP")"
assert_eq "read_docs[0] = skill path (5 件版)" "true" \
  "$(jq -r '.task.read_docs[0] | endswith("canonical/skills/adversarial-review/SKILL.md")' "$JSON_WP")"

# ---- Phase C: oe_verify_spawn が prompt_build → envelope (5 件 read_docs) を経由 ----
echo ""
echo "=== oe_verify_spawn が prompt_build を内部呼び出しする (Phase C) ==="

# spawn を再実行 (前回の split mock state を更新)
echo "888" > "${OE_MOCK_LOG_DIR}/split_count"
rm -f "${OE_MOCK_LOG_DIR}/send.log"

reviewer_spawn_c="RTEST_SPAWN_PHASE_C"
oe_verify_spawn \
  "$reviewer_spawn_c" \
  "$target_pane_id" \
  "$target_session_id" \
  "$target_envelope_path"

assert_eq "OE_VERIFY_PROMPT_PATH set after spawn" "/tmp/oe-${reviewer_spawn_c}-verify-inputs.md" "$OE_VERIFY_PROMPT_PATH"
assert_eq "spawn-generated prompt file exists" "true" "$( [[ -f "$OE_VERIFY_PROMPT_PATH" ]] && echo true || echo false )"
assert_eq "spawn-generated envelope read_docs 5 件" "5" \
  "$(jq '.task.read_docs | length' "$OE_VERIFY_ENVELOPE_PATH")"
assert_eq "spawn-generated envelope read_docs[4] = prompt" "$OE_VERIFY_PROMPT_PATH" \
  "$(jq -r '.task.read_docs[4]' "$OE_VERIFY_ENVELOPE_PATH")"

# クリーンアップ追加
rm -f "/tmp/oe-${reviewer_spawn_c}-verify-envelope.json" "/tmp/oe-${reviewer_spawn_c}-verify-inputs.md"

# ---- Phase D Step 9-10: KVS pane-keyed map 書き込み + summary 集計 + audit emit ----
echo ""
echo "=== oe_verify_write_kvs / oe_verify_summary_update / oe_verify_emit_completed (Phase D) ==="

# Phase D テスト用に target KVS を初期化 (oe_capture_write_kvs 経由で legacy 形式)
# shellcheck source=../lib/capture.sh
source "${PROJECT_DIR}/lib/capture.sh"
oe_capture_write_kvs "$target_session_id" "$target_pane_id" "success"

echo "-- Pane 42 の検証結果を書き込み (pass) --"
oe_verify_write_kvs \
  "$target_session_id" \
  "$target_pane_id" \
  "01KRMYHMETZZZZZZZZZZZZZZZZ" \
  101 \
  "pass" \
  0 \
  "@@OE_VERIFY:pass"

state_file="${OE_STATE_DIR}/${target_session_id}.state.json"
assert_eq "state file 維持" "true" "$( [[ -f "$state_file" ]] && echo true || echo false )"
assert_eq "verification.42.result" "pass" "$(jq -r '.verification."42".result' "$state_file")"
assert_eq "verification.42.reviewer_session_id" "01KRMYHMETZZZZZZZZZZZZZZZZ" \
  "$(jq -r '.verification."42".reviewer_session_id' "$state_file")"
assert_eq "verification.42.reviewer_pane_id" "101" \
  "$(jq -r '.verification."42".reviewer_pane_id' "$state_file")"
assert_eq "verification.42.issues_count" "0" \
  "$(jq -r '.verification."42".issues_count' "$state_file")"
assert_eq "verification.42.marker_raw" "@@OE_VERIFY:pass" \
  "$(jq -r '.verification."42".marker_raw' "$state_file")"
assert_eq "verification.42.completed_at 存在" "true" \
  "$(jq -r '.verification."42".completed_at | length > 0' "$state_file")"

echo "-- 既存 state ({session_id, pane_id, state, ...}) は維持 --"
assert_eq "session_id 維持" "$target_session_id" "$(jq -r '.session_id' "$state_file")"
assert_eq "state 維持" "success" "$(jq -r '.state' "$state_file")"

echo "-- Pane 43 の検証結果を追加書き込み (fail, issues=3) --"
oe_verify_write_kvs \
  "$target_session_id" \
  43 \
  "01KRMYHMETZZZZZZZZZZZZZZZY" \
  102 \
  "fail" \
  3 \
  "@@OE_VERIFY:fail"

assert_eq "verification map 件数" "2" "$(jq '.verification | length' "$state_file")"
assert_eq "verification.42 維持 (上書きなし)" "pass" "$(jq -r '.verification."42".result' "$state_file")"
assert_eq "verification.43.result" "fail" "$(jq -r '.verification."43".result' "$state_file")"
assert_eq "verification.43.issues_count" "3" "$(jq -r '.verification."43".issues_count' "$state_file")"

echo "-- Pane 44 を warn で追加書き込み --"
oe_verify_write_kvs \
  "$target_session_id" \
  44 \
  "01KRMYHMETZZZZZZZZZZZZZZZX" \
  103 \
  "warn" \
  1 \
  "@@OE_VERIFY:warn"

assert_eq "verification map 件数 (3 pane)" "3" "$(jq '.verification | length' "$state_file")"

echo ""
echo "-- oe_verify_summary_update でセッション集計 --"
oe_verify_summary_update "$target_session_id"

assert_eq "verification_summary.total" "3" "$(jq -r '.verification_summary.total' "$state_file")"
assert_eq "verification_summary.passed" "1" "$(jq -r '.verification_summary.passed' "$state_file")"
assert_eq "verification_summary.failed" "1" "$(jq -r '.verification_summary.failed' "$state_file")"
assert_eq "verification_summary.warned" "1" "$(jq -r '.verification_summary.warned' "$state_file")"
assert_eq "verification_summary.fail_rate" "0.333" \
  "$(jq -r '.verification_summary.fail_rate' "$state_file")"

echo ""
echo "-- 集計後の KVS が validate-session-state.sh で PASS --"
if "${PROJECT_DIR}/scripts/validate-session-state.sh" "$state_file" > /dev/null 2>&1; then
  echo "  PASS: validate-session-state.sh"
  (( PASS++ )) || true
else
  echo "  FAIL: validate-session-state.sh"
  "${PROJECT_DIR}/scripts/validate-session-state.sh" "$state_file" 2>&1 | sed 's/^/    /'
  (( FAIL++ )) || true
fi

echo ""
echo "-- fail のみ (total=1, failed=1, fail_rate=1.000) のケース --"
# 別 target session で完全 fail パターンを検証
fail_session="01KRFAIL000000000000000001"
oe_capture_write_kvs "$fail_session" 50 "success"
oe_verify_write_kvs "$fail_session" 50 "01KRMYHMETZZZZZZZZZZZZZZZW" 200 "fail" 5 "@@OE_VERIFY:fail"
oe_verify_summary_update "$fail_session"

fail_state_file="${OE_STATE_DIR}/${fail_session}.state.json"
assert_eq "fail-only total" "1" "$(jq -r '.verification_summary.total' "$fail_state_file")"
assert_eq "fail-only failed" "1" "$(jq -r '.verification_summary.failed' "$fail_state_file")"
assert_eq "fail-only fail_rate" "1.000" "$(jq -r '.verification_summary.fail_rate' "$fail_state_file")"

echo ""
echo "-- oe_verify_emit_completed が target audit log に追記 --"
target_audit_file="${OE_AUDIT_DIR}/${target_session_id}.jsonl"
oe_verify_emit_completed "$target_session_id" "$target_pane_id" "pass" 0 "@@OE_VERIFY:pass"
oe_verify_emit_completed "$target_session_id" 43 "fail" 3 "@@OE_VERIFY:fail"

assert_eq "verification_completed 件数" "2" \
  "$(jq -r 'select(.event_type=="verification_completed") | 1' "$target_audit_file" | wc -l | tr -d ' ')"

# 最初の verification_completed (pane 42, pass)
assert_eq "verification_completed[0].pane_id" "$target_pane_id" \
  "$(jq -s 'map(select(.event_type=="verification_completed")) | .[0].pane_id' "$target_audit_file")"
assert_eq "verification_completed[0].payload.result" "pass" \
  "$(jq -s -r 'map(select(.event_type=="verification_completed")) | .[0].payload.result' "$target_audit_file")"
assert_eq "verification_completed[0].payload.issues_count" "0" \
  "$(jq -s -r 'map(select(.event_type=="verification_completed")) | .[0].payload.issues_count' "$target_audit_file")"
assert_eq "verification_completed[0].payload.marker_raw" "@@OE_VERIFY:pass" \
  "$(jq -s -r 'map(select(.event_type=="verification_completed")) | .[0].payload.marker_raw' "$target_audit_file")"

# 2 件目 (pane 43, fail, issues=3)
assert_eq "verification_completed[1].pane_id" "43" \
  "$(jq -s 'map(select(.event_type=="verification_completed")) | .[1].pane_id' "$target_audit_file")"
assert_eq "verification_completed[1].payload.result" "fail" \
  "$(jq -s -r 'map(select(.event_type=="verification_completed")) | .[1].payload.result' "$target_audit_file")"
assert_eq "verification_completed[1].payload.issues_count" "3" \
  "$(jq -s -r 'map(select(.event_type=="verification_completed")) | .[1].payload.issues_count' "$target_audit_file")"

echo ""
echo "-- F6: verification_started は本 Phase D で emit されない --"
echo "   (Phase B 初回 oe_verify_spawn + Phase C 再 oe_verify_spawn の 2 件のみ、Phase D は emit しない)"
assert_eq "verification_started 件数 (Phase B + Phase C spawn の 2 件)" "2" \
  "$(jq -r 'select(.event_type=="verification_started") | 1' "$target_audit_file" | wc -l | tr -d ' ')"

# ---- F-SO-2: exit_code 非 0 のとき verification_protocol_error + KVS に exit_code 併記 ----
echo ""
echo "=== F-SO-2: protocol error 経路 (exit_code != 0) ==="

# 新しい target session を別途用意 (既存の集計と分離)
proto_session="01KRSTERR00000000000000001"
oe_capture_write_kvs "$proto_session" 60 "success"

# exit_code=1 のケース: write_kvs に 8 引数目を渡す
oe_verify_write_kvs \
  "$proto_session" \
  60 \
  "01KRMYHMETZZZZZZZZZZZZZZZV" \
  300 \
  "pass" \
  0 \
  "@@OE_VERIFY:pass" \
  1

proto_state_file="${OE_STATE_DIR}/${proto_session}.state.json"
assert_eq "F-SO-2: verification.60.exit_code 記録" "1" "$(jq -r '.verification."60".exit_code' "$proto_state_file")"
assert_eq "F-SO-2: result は記録される (pass)" "pass" "$(jq -r '.verification."60".result' "$proto_state_file")"

# exit_code=0 / 未指定なら exit_code フィールドは無い
oe_verify_write_kvs \
  "$proto_session" \
  61 \
  "01KRMYHMETZZZZZZZZZZZZZZZS" \
  301 \
  "pass" \
  0 \
  "@@OE_VERIFY:pass"
assert_eq "F-SO-2: exit_code 未指定なら欠落" "false" \
  "$(jq -r '.verification."61" | has("exit_code")' "$proto_state_file")"

# summary に protocol_errors が記録される
oe_verify_summary_update "$proto_session"
assert_eq "F-SO-2: verification_summary.protocol_errors=1" "1" \
  "$(jq -r '.verification_summary.protocol_errors' "$proto_state_file")"
assert_eq "F-SO-2: total=2 (両エントリ集計対象)" "2" \
  "$(jq -r '.verification_summary.total' "$proto_state_file")"

# validate-session-state.sh で PASS (exit_code 拡張 + protocol_errors 拡張)
if "${PROJECT_DIR}/scripts/validate-session-state.sh" "$proto_state_file" > /dev/null 2>&1; then
  echo "  PASS: F-SO-2: validate-session-state.sh で拡張 KVS が PASS"
  (( PASS++ )) || true
else
  echo "  FAIL: F-SO-2: validate-session-state.sh で拡張 KVS が FAIL"
  "${PROJECT_DIR}/scripts/validate-session-state.sh" "$proto_state_file" 2>&1 | sed 's/^/    /'
  (( FAIL++ )) || true
fi

# ---- F-SO-4: oe_capture_scan の 2 引数目 (lines) 動作 ----
echo ""
echo "=== F-SO-4: oe_capture_scan の lines 引数 ==="

# capture.sh が直接 source されていないので import
# shellcheck source=../lib/capture.sh
source "${PROJECT_DIR}/lib/capture.sh"

# capture が wez を適切な --lines で呼ぶことを確認するため、wez モックを差し替える。
# oe_capture_scan は wez を $(...) subshell 内で呼ぶため、変数記録は失われる。
# ファイル経由で記録する。
_F_SO_4_log="${_TMP_DIR}/f_so_4_lines.log"
: > "$_F_SO_4_log"
# shellcheck disable=SC2317  # wez は関数として PATH より優先される (function takes precedence)
wez() {
  if [[ "${1:-}" == "pane" && "${2:-}" == "capture" ]]; then
    # arg3 = pane_id, arg4 = --lines, arg5 = lines value
    printf '%s\n' "${5:-}" >> "$_F_SO_4_log"
    echo "@@OE_EXIT:0"
    return 0
  fi
  return 1
}
export -f wez

oe_capture_scan "888"  # デフォルト lines=50
assert_eq "F-SO-4: デフォルト lines=50" "50" "$(tail -1 "$_F_SO_4_log")"

oe_capture_scan "888" 200  # 検証ペイン用 lines=200
assert_eq "F-SO-4: lines=200 を渡せる" "200" "$(tail -1 "$_F_SO_4_log")"

unset -f wez

# ---- #112: log-file 経路でも字下げ marker を正規化して検出する (Copilot 指摘) ----
echo ""
echo "=== #112: _oe_verify_scan_log_file の字下げ marker 正規化 ==="

# capture 経路と verify(log-file)経路で正規化が共通ヘルパー化されたことの回帰。
# 全角空白(U+3000)字下げの @@OE_VERIFY / @@OE_EXIT がログ経路でもロケール非依存で拾えること。
_VERIFY_NORM_LOG="${_TMP_DIR}/verify_norm_indent.log"
printf '%s\n' "reviewer output" $'\xE3\x80\x80@@OE_VERIFY:pass' $'\xE3\x80\x80@@OE_EXIT:0' > "$_VERIFY_NORM_LOG"
_oe_verify_scan_log_file "$_VERIFY_NORM_LOG"
assert_eq "log経路 U+3000字下げ VERIFY" "pass" "$OE_SCAN_VERIFY_RESULT"
assert_eq "log経路 U+3000字下げ EXIT" "0" "$OE_SCAN_EXIT_CODE"

# 字下げなし marker は従来どおり検出 (回帰)
printf '%s\n' "@@OE_VERIFY:fail" > "$_VERIFY_NORM_LOG"
_oe_verify_scan_log_file "$_VERIFY_NORM_LOG"
assert_eq "log経路 字下げなし VERIFY (回帰)" "fail" "$OE_SCAN_VERIFY_RESULT"

# ---- #100: _oe_verify_scan_log_file の主要ケース (marker 発見 / 未発見 / 長文 / 破損 / 欠落 / lines) ----
# verify 経路の入口 (reviewer log 走査)。共通コア capture.sh:_oe_scan_log_file への薄い委譲だが、
# oe_verify_run_phase は本ラッパ経由で OE_SCAN_VERIFY_RESULT と OE_SCAN_EXIT_CODE の **二値** を
# 消費する (verify.sh:672 の記録分岐)。reviewer log は
# `( claude ... 2>&1 ; printf @@OE_EXIT:%d ) | tee log` 形式で、reviewer が @@OE_VERIFY:<result> を
# 出してから exit するため、正典ログは両 marker が並ぶ。test_capture.sh の _oe_scan_log_file 節は
# EXIT のみを file 経由で検証しており、verify 語彙 (pass/fail/warn) + 二値の file 経由検証は本節が担う。
echo ""
echo "=== #100: _oe_verify_scan_log_file (verify 経路の入口・二値検出) ==="

_S100_LOG="${_TMP_DIR}/s100_scan.log"

echo "-- marker 発見: 複数行 reviewer log + @@OE_VERIFY:pass + @@OE_EXIT:0 (正典・二値) --"
printf '%s\n' \
  'Compliance Review: reading target envelope and audit log' \
  'Requirement coverage looks complete.' \
  '@@OE_VERIFY:pass' \
  '@@OE_EXIT:0' > "$_S100_LOG"
_oe_verify_scan_log_file "$_S100_LOG"
assert_eq "pass/0: VERIFY_RESULT" "pass" "$OE_SCAN_VERIFY_RESULT"
assert_eq "pass/0: EXIT_CODE" "0" "$OE_SCAN_EXIT_CODE"
assert_eq "pass/0: MARKER_TYPE (両検出は EXIT 優先で後方互換)" "EXIT" "$OE_SCAN_MARKER_TYPE"

echo "-- marker 発見: @@OE_VERIFY:fail + @@OE_EXIT:0 (issues あり・clean exit) --"
printf '%s\n' 'Issues Found: missing requirement X' '@@OE_VERIFY:fail' '@@OE_EXIT:0' > "$_S100_LOG"
_oe_verify_scan_log_file "$_S100_LOG"
assert_eq "fail/0: VERIFY_RESULT" "fail" "$OE_SCAN_VERIFY_RESULT"
assert_eq "fail/0: EXIT_CODE" "0" "$OE_SCAN_EXIT_CODE"

echo "-- marker 発見: @@OE_VERIFY:warn + @@OE_EXIT:0 --"
printf '%s\n' 'Spec Compliant with advisory recommendations' '@@OE_VERIFY:warn' '@@OE_EXIT:0' > "$_S100_LOG"
_oe_verify_scan_log_file "$_S100_LOG"
assert_eq "warn/0: VERIFY_RESULT" "warn" "$OE_SCAN_VERIFY_RESULT"

echo "-- 長文 log の末尾 marker (tail で拾う = viewport-only 非依存・verify 二値版) --"
{ for i in $(seq 1 400); do echo "review markdown line $i"; done; printf '@@OE_VERIFY:pass\n@@OE_EXIT:0\n'; } > "$_S100_LOG"
_oe_verify_scan_log_file "$_S100_LOG"
assert_eq "長文: VERIFY_RESULT (末尾でも検出)" "pass" "$OE_SCAN_VERIFY_RESULT"
assert_eq "長文: EXIT_CODE (末尾でも検出)" "0" "$OE_SCAN_EXIT_CODE"

echo "-- marker 未発見: reviewer 出力途中 (verdict 未出力) → 二値とも空 --"
printf '%s\n' 'analysis still in progress' 'no verdict emitted yet' > "$_S100_LOG"
_oe_verify_scan_log_file "$_S100_LOG"
assert_eq "未発見: VERIFY_RESULT 空" "" "$OE_SCAN_VERIFY_RESULT"
assert_eq "未発見: EXIT_CODE 空" "" "$OE_SCAN_EXIT_CODE"
assert_eq "未発見: MARKER_TYPE 空" "" "$OE_SCAN_MARKER_TYPE"

echo "-- @@OE_EXIT のみ (reviewer が marker を出さず終了) → protocol error 形状 --"
printf '%s\n' 'reviewer aborted before emitting verdict' '@@OE_EXIT:1' > "$_S100_LOG"
_oe_verify_scan_log_file "$_S100_LOG"
assert_eq "EXIT のみ: EXIT_CODE=1" "1" "$OE_SCAN_EXIT_CODE"
assert_eq "EXIT のみ: VERIFY_RESULT 空" "" "$OE_SCAN_VERIFY_RESULT"

echo "-- 破損入力: 不正な VERIFY 値 → 無視 (EXIT は拾う) --"
printf '%s\n' '@@OE_VERIFY:maybe' '@@OE_EXIT:0' > "$_S100_LOG"
_oe_verify_scan_log_file "$_S100_LOG"
assert_eq "不正 VERIFY 値: VERIFY_RESULT 空" "" "$OE_SCAN_VERIFY_RESULT"
assert_eq "不正 VERIFY 値: EXIT_CODE=0" "0" "$OE_SCAN_EXIT_CODE"

echo "-- 破損入力: envelope 指示文のエコー (marker + 後置テキスト) → 行末アンカーで無視 --"
# reviewer envelope (verify.sh) は本文に @@OE_VERIFY:pass を含むため transcript にエコーされ得る。
printf '%s\n' '@@OE_VERIFY:pass — when the skill report concludes Spec Compliant' > "$_S100_LOG"
_oe_verify_scan_log_file "$_S100_LOG"
assert_eq "エコー行: VERIFY_RESULT 空 (誤検知しない)" "" "$OE_SCAN_VERIFY_RESULT"

echo "-- ファイル欠落 → OE_SCAN_* 空・return 0 (cleanup と race しても無害) --"
_s100_rc=0
_oe_verify_scan_log_file "${_TMP_DIR}/s100_absent.log" || _s100_rc=$?
assert_eq "欠落: return 0" "0" "$_s100_rc"
assert_eq "欠落: VERIFY_RESULT 空" "" "$OE_SCAN_VERIFY_RESULT"
assert_eq "欠落: EXIT_CODE 空" "" "$OE_SCAN_EXIT_CODE"
assert_eq "欠落: MARKER_TYPE 空" "" "$OE_SCAN_MARKER_TYPE"

echo "-- lines 引数 (第2引数) の委譲: 小さい窓では先頭 marker を tail が窓外に落とす --"
{ printf '@@OE_VERIFY:pass\n@@OE_EXIT:0\n'; for i in $(seq 1 10); do echo "trailing filler $i"; done; } > "$_S100_LOG"
_oe_verify_scan_log_file "$_S100_LOG" 3
assert_eq "lines=3: 先頭 marker は窓外 → VERIFY_RESULT 空" "" "$OE_SCAN_VERIFY_RESULT"
assert_eq "lines=3: 先頭 marker は窓外 → EXIT_CODE 空" "" "$OE_SCAN_EXIT_CODE"
_oe_verify_scan_log_file "$_S100_LOG"
assert_eq "既定 lines (5000): 先頭 marker も窓内 → VERIFY_RESULT=pass" "pass" "$OE_SCAN_VERIFY_RESULT"

echo ""
echo "=== Results: PASS=$PASS FAIL=$FAIL ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
