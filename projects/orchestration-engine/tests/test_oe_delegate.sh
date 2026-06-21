#!/usr/bin/env bash
set -euo pipefail

# test_oe_delegate.sh — oe-delegate の CLI 引数と spawn command を検証する
#
# 実 tmux / Claude は起動せず、PATH 先頭の tmux mock で split-window と send-keys を記録する。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT
mkdir -p "$_TMP_DIR/bin" "$_TMP_DIR/logs" "$_TMP_DIR/state" "$_TMP_DIR/pane-issue" "$_TMP_DIR/ws/.oe"

cat > "$_TMP_DIR/bin/tmux" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

log_dir="${OE_DELEGATE_TEST_LOG_DIR:?}"

if [[ "${1:-}" == "split-window" ]]; then
  # 全 argv も記録する（targeting=-t の検証用 #203）。最終引数=子コマンドは split-command.log へ。
  printf '%s\n' "$*" >> "${log_dir}/split-argv.log"
  last=""
  while [[ $# -gt 0 ]]; do
    last="$1"
    shift
  done
  printf '%s\n' "$last" >> "${log_dir}/split-command.log"
  printf '%%9\n'
  exit 0
fi

if [[ "${1:-}" == "list-panes" ]]; then
  printf '%%1\n%%9\n'
  exit 0
fi

if [[ "${1:-}" == "send-keys" ]]; then
  printf '%s\n' "$*" >> "${log_dir}/send-keys.log"
  exit 0
fi

if [[ "${1:-}" == "display-message" ]]; then
  printf 'mock-pane\n'
  exit 0
fi

echo "unexpected tmux call: $*" >&2
exit 1
EOF
chmod +x "$_TMP_DIR/bin/tmux"

export PATH="${_TMP_DIR}/bin:${PATH}"
export TMUX="/tmp/mock-tmux,12345,0"
export TMUX_PANE="%1"
export OE_DELEGATE_TEST_LOG_DIR="${_TMP_DIR}/logs"
export OE_DELEGATE_STATE_DIR="${_TMP_DIR}/state"
export OE_PANE_ISSUE_DIR="${_TMP_DIR}/pane-issue"
export OE_DELEGATE_WAIT_SEC=0
export OE_SEND_FINALIZE=0
export OE_SEND_ENTER_DELAY=0

PASS=0
FAIL=0

ck() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (want='$expected' got='$actual')"
    FAIL=$((FAIL + 1))
  fi
}

reset_logs() {
  rm -f "$_TMP_DIR/logs/"*.log
}

run_delegate() {
  bash "$PROJECT_DIR/bin/oe-delegate" "$@" >"${_TMP_DIR}/stdout.log" 2>"${_TMP_DIR}/stderr.log"
}

echo "[1] default spawn command"
reset_logs
run_delegate -w "$_TMP_DIR/ws" --label "#152" "default task"
ck "default child command" "PARENT_TMUX_PANE='%1' claude" "$(cat "$_TMP_DIR/logs/split-command.log")"
ck "task sent to child pane" "yes" "$(grep -q -- 'send-keys -l -t %9 -- default task' "$_TMP_DIR/logs/send-keys.log" && echo yes || echo no)"
ck "Enter sent" "yes" "$(grep -q -- 'send-keys -t %9 Enter' "$_TMP_DIR/logs/send-keys.log" && echo yes || echo no)"

echo "[2] --claude-arg is repeatable and preserves one arg per flag"
reset_logs
run_delegate -w "$_TMP_DIR/ws" --label "#152" --claude-arg --permission-mode --claude-arg auto "arg task"
ck "claude args in child command" "PARENT_TMUX_PANE='%1' claude '--permission-mode' 'auto'" "$(cat "$_TMP_DIR/logs/split-command.log")"

echo "[3] --claude-arg combines with --kickoff add-dir"
reset_logs
kickoff="${_TMP_DIR}/ws/.oe/kickoff.md"
printf '%s\n' '# kickoff' > "$kickoff"
run_delegate -w "$_TMP_DIR/ws" --label "#152" --claude-arg --permission-mode --claude-arg auto --kickoff "$kickoff" "kickoff task"
expected_cmd="PARENT_TMUX_PANE='%1' claude '--permission-mode' 'auto' --add-dir '${_TMP_DIR}/ws/.oe'"
ck "kickoff add-dir follows claude args" "$expected_cmd" "$(cat "$_TMP_DIR/logs/split-command.log")"
ck "kickoff path sent" "yes" "$(grep -qF -- "$kickoff を読んで進めて。 kickoff task" "$_TMP_DIR/logs/send-keys.log" && echo yes || echo no)"

echo "[4] --claude-arg shell-quotes single quotes"
reset_logs
run_delegate -w "$_TMP_DIR/ws" --label "#152" --claude-arg "foo'bar" "quote task"
ck "single quote escaped in child command" "PARENT_TMUX_PANE='%1' claude 'foo'\\''bar'" "$(cat "$_TMP_DIR/logs/split-command.log")"

echo "[5] --claude-arg preserves spaces and shell metacharacters"
reset_logs
meta_arg="a b;"'$'"(x)"
run_delegate -w "$_TMP_DIR/ws" --label "#152" --claude-arg "$meta_arg" "meta task"
ck "spaces/metacharacters quoted in child command" "PARENT_TMUX_PANE='%1' claude 'a b;\$(x)'" "$(cat "$_TMP_DIR/logs/split-command.log")"

echo "[6] --claude-arg requires a value"
reset_logs
rc=0
bash "$PROJECT_DIR/bin/oe-delegate" -w "$_TMP_DIR/ws" --claude-arg >"${_TMP_DIR}/stdout.log" 2>"${_TMP_DIR}/stderr.log" || rc=$?
ck "missing claude arg rc=2" "2" "$rc"
ck "missing claude arg does not split" "no" "$( [[ -e "$_TMP_DIR/logs/split-command.log" ]] && echo yes || echo no )"

echo "[7] --claude-arg rejects LF before spawn"
reset_logs
rc=0
bash "$PROJECT_DIR/bin/oe-delegate" -w "$_TMP_DIR/ws" --claude-arg $'bad\narg' "task" >"${_TMP_DIR}/stdout.log" 2>"${_TMP_DIR}/stderr.log" || rc=$?
ck "LF claude arg rc=2" "2" "$rc"
ck "LF claude arg does not split" "no" "$( [[ -e "$_TMP_DIR/logs/split-command.log" ]] && echo yes || echo no )"

echo "[8] --claude-arg rejects CR before spawn"
reset_logs
rc=0
bash "$PROJECT_DIR/bin/oe-delegate" -w "$_TMP_DIR/ws" --claude-arg $'bad\rarg' "task" >"${_TMP_DIR}/stdout.log" 2>"${_TMP_DIR}/stderr.log" || rc=$?
ck "CR claude arg rc=2" "2" "$rc"
ck "CR claude arg does not split" "no" "$( [[ -e "$_TMP_DIR/logs/split-command.log" ]] && echo yes || echo no )"

echo "[9] --label rejects LF before spawn"
reset_logs
rc=0
bash "$PROJECT_DIR/bin/oe-delegate" -w "$_TMP_DIR/ws" --label $'bad\nlabel' "task" >"${_TMP_DIR}/stdout.log" 2>"${_TMP_DIR}/stderr.log" || rc=$?
ck "LF label rc=2" "2" "$rc"
ck "LF label does not split" "no" "$( [[ -e "$_TMP_DIR/logs/split-command.log" ]] && echo yes || echo no )"

echo "[10] --label rejects CR before spawn"
reset_logs
rc=0
bash "$PROJECT_DIR/bin/oe-delegate" -w "$_TMP_DIR/ws" --label $'bad\rlabel' "task" >"${_TMP_DIR}/stdout.log" 2>"${_TMP_DIR}/stderr.log" || rc=$?
ck "CR label rc=2" "2" "$rc"
ck "CR label does not split" "no" "$( [[ -e "$_TMP_DIR/logs/split-command.log" ]] && echo yes || echo no )"

echo "[11] split-window targets the parent pane (#203)"
reset_logs
run_delegate -w "$_TMP_DIR/ws" --label "#152" "target task"
# TMUX_PANE=%1（親）。split-window argv に親ペイン基準 -t %1 が含まれること（フォーカス中ペイン
# ではなく親ペインを分割する）。子コマンド内の PARENT_TMUX_PANE='%1' とは別トークン（-t %1 で照合）。
ck "split-window includes -t parent pane" "yes" "$(grep -q -- '-t %1' "$_TMP_DIR/logs/split-argv.log" && echo yes || echo no)"
ck "split child command unchanged" "PARENT_TMUX_PANE='%1' claude" "$(cat "$_TMP_DIR/logs/split-command.log")"

echo "=== RESULT: pass=${PASS} fail=${FAIL} ==="
[[ "$FAIL" -eq 0 ]]
