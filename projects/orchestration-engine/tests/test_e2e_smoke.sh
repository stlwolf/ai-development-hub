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
  echo "777"
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
  printf 'mock output\n@@OE_EXIT:0\n'
  exit 0
fi

if [[ "${1:-}" == "pane" && "${2:-}" == "kill" ]]; then
  pane_id="${3:-}"
  printf '%s\n' "$pane_id" >> "${log_dir}/kill.log"
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
assert_eq "capture called once" "1" "$(cat "${OE_MOCK_LOG_DIR}/capture_count_777")"
assert_eq "cleanup kill called" "777" "$(cat "${OE_MOCK_LOG_DIR}/kill.log")"

assert_eq "session_start emitted" "1" \
  "$(jq -r 'select(.event_type=="session_start") | 1' "$audit_file" | wc -l | tr -d ' ')"
assert_eq "session_start state null" "null" "$(jq -r 'select(.event_type=="session_start") | .state' "$audit_file")"
assert_eq "session_end emitted" "1" \
  "$(jq -r 'select(.event_type=="session_end") | 1' "$audit_file" | wc -l | tr -d ' ')"
assert_eq "state_change emitted" "1" \
  "$(jq -r 'select(.event_type=="state_change" and .state=="success") | 1' "$audit_file" | wc -l | tr -d ' ')"
assert_eq "cleanup emitted" "1" \
  "$(jq -r 'select(.event_type=="cleanup") | 1' "$audit_file" | wc -l | tr -d ' ')"
assert_eq "cleanup payload has killed_pane_ids" "777" "$(jq -r 'select(.event_type=="cleanup") | .payload.killed_pane_ids[0]' "$audit_file")"
assert_eq "envelope path used in send" "1" \
  "$(awk -v sid="$session_id" 'index($0,"/tmp/oe-" sid "-envelope.json"){found=1} END{print found+0}' "${OE_MOCK_LOG_DIR}/send.log")"
assert_eq "spawn send executed" "1" \
  "$(awk -v sid="$session_id" 'index($0,"Read /tmp/oe-" sid "-envelope.json and execute the task"){found=1} END{print found+0}' "${OE_MOCK_LOG_DIR}/send.log")"

echo ""
echo "=== Results: PASS=$PASS FAIL=$FAIL ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
