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
  # 全 argv を 1 行 1 引数で記録する（targeting=-t の順序検証用 #203）。"$*" は argv を 1 文字列に
  # 結合し境界/クォートを失うため "$@" で 1 引数ずつ出す。最終引数=子コマンドは split-command.log へ。
  printf '%s\n' "$@" >> "${log_dir}/split-argv.log"
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
export OE_EVENT_LOG=0          # 活動ログ（#206）emit を無効化（本テストは spawn/kick が対象）

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

echo "[3] --claude-arg combines with --brief add-dir"
reset_logs
brief="${_TMP_DIR}/ws/.oe/brief.md"
printf '%s\n' '# brief' > "$brief"
run_delegate -w "$_TMP_DIR/ws" --label "#152" --claude-arg --permission-mode --claude-arg auto --brief "$brief" "brief task"
expected_cmd="PARENT_TMUX_PANE='%1' claude '--permission-mode' 'auto' --add-dir '${_TMP_DIR}/ws/.oe'"
ck "brief add-dir follows claude args" "$expected_cmd" "$(cat "$_TMP_DIR/logs/split-command.log")"
ck "brief path sent" "yes" "$(grep -qF -- "$brief を読んで進めて。 brief task" "$_TMP_DIR/logs/send-keys.log" && echo yes || echo no)"

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
# split-argv.log は 1 行 1 引数。-t の直後の引数が %1（親=TMUX_PANE）であることを順序込みで検証する
# （フォーカス中ペインではなく親ペインを分割する）。子コマンド内の PARENT_TMUX_PANE='%1' と混同しない。
ck "split-window -t targets parent pane" "%1" "$(awk '/^-t$/{getline; print; exit}' "$_TMP_DIR/logs/split-argv.log")"
ck "split child command unchanged" "PARENT_TMUX_PANE='%1' claude" "$(cat "$_TMP_DIR/logs/split-command.log")"

echo "[12] --kickoff は --brief の deprecated alias（回帰・#255）"
# oe-delegate 側の alias。--brief と同一に add-dir 開示 + payload を組む。
reset_logs
alias_brief="${_TMP_DIR}/ws/.oe/alias-brief.md"
printf '%s\n' '# brief' > "$alias_brief"
run_delegate -w "$_TMP_DIR/ws" --label "#152" --kickoff "$alias_brief" "alias task"
ck "alias add-dir opens brief dir" "PARENT_TMUX_PANE='%1' claude --add-dir '${_TMP_DIR}/ws/.oe'" "$(cat "$_TMP_DIR/logs/split-command.log")"
ck "alias path sent identically" "yes" "$(grep -qF -- "$alias_brief を読んで進めて。 alias task" "$_TMP_DIR/logs/send-keys.log" && echo yes || echo no)"

echo "[13] oe-send --brief が payload を組む"
# oe-send を直接叩く（%N は素通し。mock list-panes が %9 を alive と返す）。
reset_logs
send_brief="${_TMP_DIR}/ws/.oe/send-brief.md"
printf '%s\n' '# brief' > "$send_brief"
bash "$PROJECT_DIR/bin/oe-send" --brief "$send_brief" -- %9 "adhoc" >"${_TMP_DIR}/stdout.log" 2>"${_TMP_DIR}/stderr.log"
ck "oe-send --brief payload" "yes" "$(grep -qF -- "$send_brief を読んで進めて。 adhoc" "$_TMP_DIR/logs/send-keys.log" && echo yes || echo no)"

echo "[14] oe-send --kickoff は deprecated alias（回帰・#255）"
reset_logs
bash "$PROJECT_DIR/bin/oe-send" --kickoff "$send_brief" -- %9 "adhoc" >"${_TMP_DIR}/stdout.log" 2>"${_TMP_DIR}/stderr.log"
ck "oe-send --kickoff payload identical" "yes" "$(grep -qF -- "$send_brief を読んで進めて。 adhoc" "$_TMP_DIR/logs/send-keys.log" && echo yes || echo no)"

echo "[15] --brief は値が必須（rc=2）"
reset_logs
rc=0
bash "$PROJECT_DIR/bin/oe-delegate" -w "$_TMP_DIR/ws" --brief >"${_TMP_DIR}/stdout.log" 2>"${_TMP_DIR}/stderr.log" || rc=$?
ck "missing brief value rc=2" "2" "$rc"
ck "missing brief error names --brief" "yes" "$(grep -qF -- '--brief requires a value' "${_TMP_DIR}/stderr.log" && echo yes || echo no)"

echo "=== RESULT: pass=${PASS} fail=${FAIL} ==="
[[ "$FAIL" -eq 0 ]]
