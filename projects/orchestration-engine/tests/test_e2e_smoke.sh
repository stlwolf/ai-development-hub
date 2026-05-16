#!/usr/bin/env bash
set -euo pipefail

# test_e2e_smoke.sh — bin/oe の最小 E2E スモークテスト

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
export PROJECT_DIR

_TMP_DIR="${SCRIPT_DIR}/.tmp_test_e2e_smoke_$$"
mkdir -p "$_TMP_DIR/bin" "$_TMP_DIR/logs" "$_TMP_DIR/data"
trap 'rm -rf "$_TMP_DIR"' EXIT

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
  # 連番 split: 1 回目 = 777 (target)、2 回目 = 888 (reviewer)
  count_file="${log_dir}/split_count"
  current=777
  [[ -f "$count_file" ]] && current=$(<"$count_file")
  echo "$current" > "${log_dir}/split_last"
  next=$(( current + 111 ))
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

if [[ "${1:-}" == "pane" && "${2:-}" == "capture" ]]; then
  pane_id="${3:-}"
  count_file="${log_dir}/capture_count_${pane_id}"
  current=0
  [[ -f "$count_file" ]] && current=$(<"$count_file")
  current=$(( current + 1 ))
  echo "$current" > "$count_file"
  # reviewer pane (888) は @@OE_VERIFY:pass + @@OE_EXIT:0、それ以外は @@OE_EXIT:0 のみ
  if [[ "$pane_id" == "888" ]]; then
    printf 'review output\n@@OE_VERIFY:pass\n@@OE_EXIT:0\n'
  else
    printf 'mock output\n@@OE_EXIT:0\n'
  fi
  exit 0
fi

if [[ "${1:-}" == "pane" && "${2:-}" == "kill" ]]; then
  pane_id="${3:-}"
  printf '%s\n' "$pane_id" >> "${log_dir}/kill.log"
  exit 0
fi

if [[ "${1:-}" == "notify" ]]; then
  title="${2:-}"
  body="${3:-}"
  printf '%s|%s\n' "$title" "$body" >> "${log_dir}/notify.log"
  exit 0
fi

echo "unexpected wez call: $*" >&2
exit 1
EOF
chmod +x "${_TMP_DIR}/bin/wez"

export PATH="${_TMP_DIR}/bin:${PATH}"
export OE_MOCK_LOG_DIR="${_TMP_DIR}/logs"
export OE_DATA_DIR="${_TMP_DIR}/data"

echo "=== bin/oe E2E smoke ==="
bash "${PROJECT_DIR}/bin/oe" "E2E smoke task"

state_file="$(echo "${OE_DATA_DIR}"/state/*.state.json)"
audit_file="$(echo "${OE_DATA_DIR}"/audit/*.jsonl)"
session_id="$(basename "$state_file" .state.json)"

assert_eq "state file exists" "true" "$( [[ -f "$state_file" ]] && echo true || echo false )"
assert_eq "audit file exists" "true" "$( [[ -f "$audit_file" ]] && echo true || echo false )"
assert_eq "state.session_id" "$session_id" "$(jq -r '.session_id' "$state_file")"
assert_eq "session_id matches ULID alphabet pattern" "true" "$( [[ "$session_id" =~ ^[0-9A-HJKMNP-TV-Z]{26}$ ]] && echo true || echo false )"
assert_eq "state.state" "success" "$(jq -r '.state' "$state_file")"
assert_eq "capture target pane (777) called at least once" "true" \
  "$( [[ -f "${OE_MOCK_LOG_DIR}/capture_count_777" && "$(cat "${OE_MOCK_LOG_DIR}/capture_count_777")" -ge 1 ]] && echo true || echo false )"

assert_eq "session_start emitted" "1" \
  "$(jq -r 'select(.event_type=="session_start") | 1' "$audit_file" | wc -l | tr -d ' ')"
assert_eq "session_start state null" "null" "$(jq -r 'select(.event_type=="session_start") | .state' "$audit_file")"
assert_eq "session_end emitted" "1" \
  "$(jq -r 'select(.event_type=="session_end") | 1' "$audit_file" | wc -l | tr -d ' ')"
assert_eq "state_change emitted" "1" \
  "$(jq -r 'select(.event_type=="state_change" and .state=="success") | 1' "$audit_file" | wc -l | tr -d ' ')"
assert_eq "cleanup emitted" "1" \
  "$(jq -r 'select(.event_type=="cleanup") | 1' "$audit_file" | wc -l | tr -d ' ')"
assert_eq "envelope path used in send" "1" \
  "$(awk -v sid="$session_id" 'index($0,"/tmp/oe-" sid "-envelope.json"){found=1} END{print found+0}' "${OE_MOCK_LOG_DIR}/send.log")"
assert_eq "spawn send executed" "1" \
  "$(awk -v sid="$session_id" 'index($0,"Read /tmp/oe-" sid "-envelope.json and execute the task"){found=1} END{print found+0}' "${OE_MOCK_LOG_DIR}/send.log")"

# ---- Step 4-3 Phase E: 検証フェーズが 1 サイクルに含まれる ----
echo ""
echo "=== Step 4-3 Phase E: 検証フェーズ完走 ==="

# 検証 agent ペイン (888) が spawn された
assert_eq "reviewer pane (888) split" "true" \
  "$( [[ -f "${OE_MOCK_LOG_DIR}/capture_count_888" ]] && echo true || echo false )"

# 検証用 envelope/inputs が send.log に展開される (target=777, reviewer=888)
assert_eq "reviewer pane に verify envelope を send" "true" \
  "$(awk -F'|' '$1=="888" && index($2, "verify-envelope.json"){found=1} END{print (found+0==1) ? "true" : "false"}' "${OE_MOCK_LOG_DIR}/send.log")"

# verification_started イベントが emit される (target session の audit log)
assert_eq "verification_started 1 件" "1" \
  "$(jq -r 'select(.event_type=="verification_started") | 1' "$audit_file" | wc -l | tr -d ' ')"
assert_eq "verification_started.payload.target_pane_id" "777" \
  "$(jq -r 'select(.event_type=="verification_started") | .payload.target_pane_id' "$audit_file")"
assert_eq "verification_started.payload.reviewer_pane_id" "888" \
  "$(jq -r 'select(.event_type=="verification_started") | .payload.reviewer_pane_id' "$audit_file")"

# verification_completed イベントが emit される (Phase D)
assert_eq "verification_completed 1 件" "1" \
  "$(jq -r 'select(.event_type=="verification_completed") | 1' "$audit_file" | wc -l | tr -d ' ')"
assert_eq "verification_completed.payload.result" "pass" \
  "$(jq -r 'select(.event_type=="verification_completed") | .payload.result' "$audit_file")"
assert_eq "verification_completed.payload.marker_raw" "@@OE_VERIFY:pass" \
  "$(jq -r 'select(.event_type=="verification_completed") | .payload.marker_raw' "$audit_file")"

# KVS に verification (pane-keyed map) が書かれる
assert_eq "verification map 件数" "1" "$(jq '.verification | length' "$state_file")"
assert_eq "verification.777.result" "pass" "$(jq -r '.verification."777".result' "$state_file")"
assert_eq "verification.777.reviewer_pane_id" "888" "$(jq -r '.verification."777".reviewer_pane_id' "$state_file")"
assert_eq "verification.777.completed_at 存在" "true" \
  "$(jq -r '.verification."777".completed_at | length > 0' "$state_file")"

# verification_summary が集計される (1 件 pass / fail_rate = 0.000)
assert_eq "verification_summary.total" "1" "$(jq -r '.verification_summary.total' "$state_file")"
assert_eq "verification_summary.passed" "1" "$(jq -r '.verification_summary.passed' "$state_file")"
assert_eq "verification_summary.failed" "0" "$(jq -r '.verification_summary.failed' "$state_file")"
assert_eq "verification_summary.fail_rate" "0.000" "$(jq -r '.verification_summary.fail_rate' "$state_file")"

# KVS が validate-session-state.sh で PASS
if "${PROJECT_DIR}/scripts/validate-session-state.sh" "$state_file" > /dev/null 2>&1; then
  echo "  PASS: validate-session-state.sh"
  (( PASS++ )) || true
else
  echo "  FAIL: validate-session-state.sh"
  "${PROJECT_DIR}/scripts/validate-session-state.sh" "$state_file" 2>&1 | sed 's/^/    /'
  (( FAIL++ )) || true
fi

# cleanup で target + reviewer 両ペインが kill される
assert_eq "kill.log にエントリ 2 件" "2" "$(wc -l < "${OE_MOCK_LOG_DIR}/kill.log" | tr -d ' ')"
assert_eq "kill.log に 777" "true" \
  "$(grep -qx 777 "${OE_MOCK_LOG_DIR}/kill.log" && echo true || echo false)"
assert_eq "kill.log に 888" "true" \
  "$(grep -qx 888 "${OE_MOCK_LOG_DIR}/kill.log" && echo true || echo false)"
assert_eq "cleanup payload killed_pane_ids に target + reviewer" "[777,888]" \
  "$(jq -c 'select(.event_type=="cleanup") | .payload.killed_pane_ids' "$audit_file")"

# DI-6: wez notify が呼ばれる (検証完走時)
assert_eq "notify.log 存在" "true" "$( [[ -f "${OE_MOCK_LOG_DIR}/notify.log" ]] && echo true || echo false )"
assert_eq "notify 1 件" "1" "$(wc -l < "${OE_MOCK_LOG_DIR}/notify.log" | tr -d ' ')"
assert_eq "notify タイトル" "orchestration-engine session complete" \
  "$(awk -F'|' 'NR==1{print $1}' "${OE_MOCK_LOG_DIR}/notify.log")"
assert_eq "notify 本文に session_id" "true" \
  "$(awk -F'|' -v sid="$session_id" 'NR==1 && index($2, sid){f=1} END{print (f+0==1) ? "true" : "false"}' "${OE_MOCK_LOG_DIR}/notify.log")"
assert_eq "notify 本文に pass=1" "true" \
  "$(awk -F'|' 'NR==1 && index($2, "pass=1"){f=1} END{print (f+0==1) ? "true" : "false"}' "${OE_MOCK_LOG_DIR}/notify.log")"
assert_eq "notify 本文に fail_rate=0.000" "true" \
  "$(awk -F'|' 'NR==1 && index($2, "fail_rate=0.000"){f=1} END{print (f+0==1) ? "true" : "false"}' "${OE_MOCK_LOG_DIR}/notify.log")"

# Copilot #8 + #2: notify 本文に protocol_errors / timeouts が含まれる (誤った成功通知の防止)
assert_eq "notify 本文に protocol_errors=0" "true" \
  "$(awk -F'|' 'NR==1 && index($2, "protocol_errors=0"){f=1} END{print (f+0==1) ? "true" : "false"}' "${OE_MOCK_LOG_DIR}/notify.log")"
assert_eq "notify 本文に timeouts=0" "true" \
  "$(awk -F'|' 'NR==1 && index($2, "timeouts=0"){f=1} END{print (f+0==1) ? "true" : "false"}' "${OE_MOCK_LOG_DIR}/notify.log")"

# Copilot #2: verification_summary に timeouts フィールドが追加される
assert_eq "verification_summary.timeouts = 0 (正常完了時)" "0" \
  "$(jq -r '.verification_summary.timeouts' "$state_file")"

echo ""
echo "=== Results: PASS=$PASS FAIL=$FAIL ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
