#!/usr/bin/env bash
# shellcheck disable=SC2034
set -euo pipefail

# test_cleanup.sh — cleanup.sh のユニットテスト

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
export PROJECT_DIR

# shellcheck source=../lib/cleanup.sh
source "${PROJECT_DIR}/lib/cleanup.sh"

PASS=0
FAIL=0

_MOCK_KILL_CALLS=()
_MOCK_AUDIT_CALLS=0
_MOCK_LAST_CLEANUP_PAYLOAD=""

wez() {
  if [[ "${1:-}" == "pane" && "${2:-}" == "kill" ]]; then
    _MOCK_KILL_CALLS+=("${3:-}")
    return 0
  fi
  return 1
}

oe_audit_emit() {
  (( _MOCK_AUDIT_CALLS++ )) || true
  if [[ "${1:-}" == "cleanup" ]]; then
    _MOCK_LAST_CLEANUP_PAYLOAD="${5:-}"
  fi
  return 0
}

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

echo "=== oe_cleanup empty panes ==="
OE_MANAGED_PANES=()
OE_CURRENT_SESSION_ID="EMPTYKILL"
OE_CLEANUP_DONE=""
_MOCK_KILL_CALLS=()
_MOCK_AUDIT_CALLS=0
_MOCK_LAST_CLEANUP_PAYLOAD=""

oe_cleanup

assert_eq "no kill when panes empty" "0" "${#_MOCK_KILL_CALLS[@]}"
assert_eq "cleanup audit once" "1" "$_MOCK_AUDIT_CALLS"
assert_eq "cleanup payload killed_pane_ids empty" "[]" "$(echo "$_MOCK_LAST_CLEANUP_PAYLOAD" | jq -c '.killed_pane_ids')"

echo ""
echo "=== oe_cleanup ==="

_MOCK_KILL_CALLS=()
_MOCK_AUDIT_CALLS=0
_MOCK_LAST_CLEANUP_PAYLOAD=""

OE_MANAGED_PANES=("101" "102")
OE_CURRENT_SESSION_ID="TESTCLEAN"
OE_CLEANUP_DONE=""

tmp_target_1="/tmp/oe-${OE_CURRENT_SESSION_ID}-one.txt"
tmp_target_2="/tmp/oe-${OE_CURRENT_SESSION_ID}-two.txt"
tmp_keep="/tmp/oe-NOT-MATCH-keep.txt"
echo "x" > "$tmp_target_1"
echo "x" > "$tmp_target_2"
echo "x" > "$tmp_keep"

cleanup_files() {
  rm -f "$tmp_target_1" "$tmp_target_2" "$tmp_keep"
}
trap cleanup_files EXIT

oe_cleanup

assert_eq "kill called twice" "2" "${#_MOCK_KILL_CALLS[@]}"
assert_eq "first killed pane" "101" "${_MOCK_KILL_CALLS[0]}"
assert_eq "second killed pane" "102" "${_MOCK_KILL_CALLS[1]}"
assert_eq "session tmp removed #1" "false" "$( [[ -e "$tmp_target_1" ]] && echo true || echo false )"
assert_eq "session tmp removed #2" "false" "$( [[ -e "$tmp_target_2" ]] && echo true || echo false )"
assert_eq "non-session tmp kept" "true" "$( [[ -e "$tmp_keep" ]] && echo true || echo false )"
assert_eq "audit called once" "1" "$_MOCK_AUDIT_CALLS"
assert_eq "cleanup payload killed_pane_ids" "[101,102]" "$(echo "$_MOCK_LAST_CLEANUP_PAYLOAD" | jq -c '.killed_pane_ids')"

oe_cleanup

assert_eq "double run guard kill unchanged" "2" "${#_MOCK_KILL_CALLS[@]}"
assert_eq "double run guard audit unchanged" "1" "$_MOCK_AUDIT_CALLS"

echo ""

# ---- Step 4-4 Phase C: OE_VERIFY_REVIEWER_SESSION_IDS 経由の reviewer 一時ファイル削除 ----
_MOCK_KILL_CALLS=()
_MOCK_AUDIT_CALLS=0
_MOCK_LAST_CLEANUP_PAYLOAD=""

OE_MANAGED_PANES=("701" "702")
OE_CURRENT_SESSION_ID="TESTRVRCLEAN"
OE_CLEANUP_DONE=""

# ダミー reviewer 一時ファイルを作成 (Phase C.5 反映: .log も削除対象)
rsid_a="01TESTRSIDA0000000000000A0"
rsid_b="01TESTRSIDB0000000000000B0"
OE_VERIFY_REVIEWER_SESSION_IDS=("$rsid_a" "$rsid_b")
touch "/tmp/oe-${rsid_a}-verify-envelope.json"
touch "/tmp/oe-${rsid_a}-verify-inputs.md"
touch "/tmp/oe-${rsid_a}-reviewer.log"
touch "/tmp/oe-${rsid_b}-verify-envelope.json"
touch "/tmp/oe-${rsid_b}-verify-inputs.md"
touch "/tmp/oe-${rsid_b}-reviewer.log"

oe_cleanup

assert_eq "reviewer rsid_a envelope removed" "false" "$( [[ -e "/tmp/oe-${rsid_a}-verify-envelope.json" ]] && echo true || echo false )"
assert_eq "reviewer rsid_a inputs removed"   "false" "$( [[ -e "/tmp/oe-${rsid_a}-verify-inputs.md" ]] && echo true || echo false )"
assert_eq "reviewer rsid_a log removed"      "false" "$( [[ -e "/tmp/oe-${rsid_a}-reviewer.log" ]] && echo true || echo false )"
assert_eq "reviewer rsid_b envelope removed" "false" "$( [[ -e "/tmp/oe-${rsid_b}-verify-envelope.json" ]] && echo true || echo false )"
assert_eq "reviewer rsid_b inputs removed"   "false" "$( [[ -e "/tmp/oe-${rsid_b}-verify-inputs.md" ]] && echo true || echo false )"
assert_eq "reviewer rsid_b log removed"      "false" "$( [[ -e "/tmp/oe-${rsid_b}-reviewer.log" ]] && echo true || echo false )"

echo "=== Results: PASS=$PASS FAIL=$FAIL ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
