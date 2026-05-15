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
if [[ "${1:-}" == "diff" && "${2:-}" == "--name-only" ]]; then
  if [[ -n "${OE_MOCK_GIT_FILES:-}" ]]; then
    printf '%s\n' "${OE_MOCK_GIT_FILES}"
  fi
  exit 0
fi
# git diff 以外の git は素通り (実 git を使う)
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
assert_eq "context.shared_kvs_path includes target session_id" "true" \
  "$(jq -r --arg sid "$target_session_id" '.context.shared_kvs_path | endswith($sid + ".state.json")' "$JSON")"

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

# ---- Phase C: oe_verify_prompt_build (3 入力の構造化抽出) ----
echo ""
echo "=== oe_verify_prompt_build (Phase C) ==="

# 既に oe_verify_spawn 経由で target session の audit log に verification_started イベントが
# 書かれている。Phase C 用に state_change イベントを追記:
oe_audit_emit "state_change" "$target_session_id" "$target_pane_id" "success" '{"from":"progress","to":"success"}'

# Case 1: KVS に outputs[] が複数あるケース (git フォールバックは呼ばれない)
target_kvs_file="${OE_STATE_DIR}/${target_session_id}.state.json"
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

echo "-- Case 1: KVS の outputs[] を使用 --"
oe_verify_prompt_build "RTEST_PROMPT_01" "$target_pane_id" "$target_session_id" "$target_envelope_path"

assert_eq "OE_VERIFY_PROMPT_PATH set" "/tmp/oe-RTEST_PROMPT_01-verify-inputs.md" "$OE_VERIFY_PROMPT_PATH"
assert_eq "prompt file exists" "true" "$( [[ -f "$OE_VERIFY_PROMPT_PATH" ]] && echo true || echo false )"

assert_eq "section: 要件" "true" "$(grep -q '^## 要件' "$OE_VERIFY_PROMPT_PATH" && echo true || echo false)"
assert_eq "section: 完了報告" "true" "$(grep -q '^## 完了報告' "$OE_VERIFY_PROMPT_PATH" && echo true || echo false)"
assert_eq "section: 変更ファイル" "true" "$(grep -q '^## 変更ファイル' "$OE_VERIFY_PROMPT_PATH" && echo true || echo false)"

assert_eq "要件 = target.task.description" "true" \
  "$(grep -q 'Target task description' "$OE_VERIFY_PROMPT_PATH" && echo true || echo false)"
assert_eq "完了報告に state_change イベント" "true" \
  "$(grep -qE '"event_type": ?"state_change"' "$OE_VERIFY_PROMPT_PATH" && echo true || echo false)"
assert_eq "変更ファイルに outputs[0]" "true" \
  "$(grep -q '^- src/foo.sh' "$OE_VERIFY_PROMPT_PATH" && echo true || echo false)"
assert_eq "変更ファイルに outputs[1]" "true" \
  "$(grep -q '^- tests/test_foo.sh' "$OE_VERIFY_PROMPT_PATH" && echo true || echo false)"

# Case 2: KVS の outputs[] が空 → git diff フォールバック (git mock 経由)
echo ""
echo "-- Case 2: outputs[] 空 → git diff --name-only フォールバック --"

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

export OE_MOCK_GIT_FILES="lib/changed.sh
tests/test_changed.sh"
oe_verify_prompt_build "RTEST_PROMPT_GIT" "$target_pane_id" "$target_session_id" "$target_envelope_path"
unset OE_MOCK_GIT_FILES

assert_eq "prompt path (git fallback)" "/tmp/oe-RTEST_PROMPT_GIT-verify-inputs.md" "$OE_VERIFY_PROMPT_PATH"
assert_eq "git fallback: lib/changed.sh" "true" \
  "$(grep -q '^- lib/changed.sh' "$OE_VERIFY_PROMPT_PATH" && echo true || echo false)"
assert_eq "git fallback: tests/test_changed.sh" "true" \
  "$(grep -q '^- tests/test_changed.sh' "$OE_VERIFY_PROMPT_PATH" && echo true || echo false)"
assert_eq "git fallback: outputs[0] (src/foo.sh) は含まない" "false" \
  "$(grep -q '^- src/foo.sh' "$OE_VERIFY_PROMPT_PATH" && echo true || echo false)"

# Case 3: outputs[] 空 + git 出力も空 → "(no changes detected ...)" プレースホルダ
echo ""
echo "-- Case 3: outputs[] 空 + git 空 → プレースホルダ --"

unset OE_MOCK_GIT_FILES
oe_verify_prompt_build "RTEST_PROMPT_02" "$target_pane_id" "$target_session_id" "$target_envelope_path"
assert_eq "プレースホルダ表示" "true" \
  "$(grep -q 'no changes detected' "$OE_VERIFY_PROMPT_PATH" && echo true || echo false)"

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

echo ""
echo "=== Results: PASS=$PASS FAIL=$FAIL ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
