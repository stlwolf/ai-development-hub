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

echo "[16] --print-approval prints a digest and does NOT spawn (#262)"
reset_logs
run_delegate -w "$_TMP_DIR/ws" --label "#262" --claude-arg --permission-mode --claude-arg auto --reason "本番隣接 deploy" --print-approval "elevated task"
ck "print-approval does not spawn" "no" "$( [[ -e "$_TMP_DIR/logs/split-command.log" ]] && echo yes || echo no )"
ck "print-approval prints 16-hex digest" "yes" "$(grep -qE '承認ダイジェスト: [0-9a-f]{16}' "$_TMP_DIR/stdout.log" && echo yes || echo no)"
ck "print-approval echoes --approved-digest" "yes" "$(grep -q -- '--approved-digest' "$_TMP_DIR/stdout.log" && echo yes || echo no)"

echo "[17] --approved-digest matching -> spawns; binding holds (#262)"
digest="$(bash "$PROJECT_DIR/bin/oe-delegate" -w "$_TMP_DIR/ws" --label "#262" --claude-arg --permission-mode --claude-arg auto --print-approval "bind task" 2>/dev/null | sed -n 's/.*承認ダイジェスト: //p' | tr -d ' ')"
reset_logs
run_delegate -w "$_TMP_DIR/ws" --label "#262" --claude-arg --permission-mode --claude-arg auto --approved-digest "$digest" "bind task"
ck "matching digest spawns child" "PARENT_TMUX_PANE='%1' claude '--permission-mode' 'auto'" "$(cat "$_TMP_DIR/logs/split-command.log")"

echo "[18] --approved-digest mismatch -> rc=3 and no spawn (#262)"
reset_logs
rc=0
bash "$PROJECT_DIR/bin/oe-delegate" -w "$_TMP_DIR/ws" --label "#262" --claude-arg --permission-mode --claude-arg auto --approved-digest "deadbeefdeadbeef" "bind task" >"${_TMP_DIR}/stdout.log" 2>"${_TMP_DIR}/stderr.log" || rc=$?
ck "mismatch rc=3" "3" "$rc"
ck "mismatch does not spawn" "no" "$( [[ -e "$_TMP_DIR/logs/split-command.log" ]] && echo yes || echo no )"

echo "[19] --reason is excluded from the digest (annotation, not execution) (#262)"
d1="$(bash "$PROJECT_DIR/bin/oe-delegate" -w "$_TMP_DIR/ws" --claude-arg --permission-mode --claude-arg auto --reason "r1" --print-approval "same task" 2>/dev/null | sed -n 's/.*承認ダイジェスト: //p' | tr -d ' ')"
d2="$(bash "$PROJECT_DIR/bin/oe-delegate" -w "$_TMP_DIR/ws" --claude-arg --permission-mode --claude-arg auto --reason "r2 different" --print-approval "same task" 2>/dev/null | sed -n 's/.*承認ダイジェスト: //p' | tr -d ' ')"
ck "reason change -> digest stable" "yes" "$( [[ -n "$d1" && "$d1" == "$d2" ]] && echo yes || echo no )"
d3="$(bash "$PROJECT_DIR/bin/oe-delegate" -w "$_TMP_DIR/ws" --claude-arg --permission-mode --claude-arg auto --print-approval "DIFFERENT task" 2>/dev/null | sed -n 's/.*承認ダイジェスト: //p' | tr -d ' ')"
ck "task change -> digest differs" "yes" "$( [[ "$d1" != "$d3" ]] && echo yes || echo no )"

echo "[20] relative --workspace is normalized to absolute in the package (#262 D1)"
reset_logs
expected_ws="$(cd "$_TMP_DIR/ws" && pwd)"
absout="$(cd "$_TMP_DIR/ws" && bash "$PROJECT_DIR/bin/oe-delegate" -w . --print-approval "abs task" 2>/dev/null)"
ck "relative -w shown as absolute" "yes" "$(printf '%s\n' "$absout" | grep -qF "作業ディレクトリ: ${expected_ws}" && echo yes || echo no)"

echo "[21] empty --approved-digest still verifies (no skip) -> refuse (#262 D2)"
reset_logs
rc=0
bash "$PROJECT_DIR/bin/oe-delegate" -w "$_TMP_DIR/ws" --claude-arg --permission-mode --claude-arg auto --approved-digest "" "t" >/dev/null 2>"${_TMP_DIR}/stderr.log" || rc=$?
ck "empty digest rc=3" "3" "$rc"
ck "empty digest no spawn" "no" "$( [[ -e "$_TMP_DIR/logs/split-command.log" ]] && echo yes || echo no )"

echo "[22] --elevated without --approved-digest is refused (#262 D3)"
reset_logs
rc=0
bash "$PROJECT_DIR/bin/oe-delegate" -w "$_TMP_DIR/ws" --elevated --claude-arg --permission-mode --claude-arg auto "t" >/dev/null 2>"${_TMP_DIR}/stderr.log" || rc=$?
ck "elevated no-digest rc=3" "3" "$rc"
ck "elevated no-digest no spawn" "no" "$( [[ -e "$_TMP_DIR/logs/split-command.log" ]] && echo yes || echo no )"

echo "[23] bypassPermissions is treated as elevated -> requires approval (#262 D3)"
reset_logs
rc=0
bash "$PROJECT_DIR/bin/oe-delegate" -w "$_TMP_DIR/ws" --claude-arg --permission-mode --claude-arg bypassPermissions "t" >/dev/null 2>"${_TMP_DIR}/stderr.log" || rc=$?
ck "bypass no-digest rc=3" "3" "$rc"
ck "bypass no-digest no spawn" "no" "$( [[ -e "$_TMP_DIR/logs/split-command.log" ]] && echo yes || echo no )"

echo "[24] --elevated with matching digest spawns (#262 D3 positive)"
edig="$(bash "$PROJECT_DIR/bin/oe-delegate" -w "$_TMP_DIR/ws" --elevated --claude-arg --permission-mode --claude-arg auto --print-approval "el task" 2>/dev/null | sed -n 's/.*承認ダイジェスト: //p' | tr -d ' ')"
reset_logs
run_delegate -w "$_TMP_DIR/ws" --elevated --claude-arg --permission-mode --claude-arg auto --approved-digest "$edig" "el task"
ck "elevated + matching digest spawns" "PARENT_TMUX_PANE='%1' claude '--permission-mode' 'auto'" "$(cat "$_TMP_DIR/logs/split-command.log")"

echo "[25] --workspace with control chars is rejected before spawn (#262 D4/R2)"
reset_logs
rc=0
bash "$PROJECT_DIR/bin/oe-delegate" -w $'/tmp\nfake' --print-approval "t" >/dev/null 2>"${_TMP_DIR}/stderr.log" || rc=$?
ck "newline workspace rc=2" "2" "$rc"
ck "newline workspace no spawn" "no" "$( [[ -e "$_TMP_DIR/logs/split-command.log" ]] && echo yes || echo no )"
rc=0
bash "$PROJECT_DIR/bin/oe-delegate" -w $'/tmp\x1b[2Kfake' --print-approval "t" >/dev/null 2>"${_TMP_DIR}/stderr.log" || rc=$?
ck "ESC workspace rc=2" "2" "$rc"

echo "[26] --elevated is bound in the digest — no escalation/downgrade via flag tamper (#262 R2)"
nedig="$(bash "$PROJECT_DIR/bin/oe-delegate" -w "$_TMP_DIR/ws" --claude-arg --permission-mode --claude-arg auto --print-approval "esc task" 2>/dev/null | sed -n 's/.*承認ダイジェスト: //p' | tr -d ' ')"
reset_logs
rc=0
bash "$PROJECT_DIR/bin/oe-delegate" -w "$_TMP_DIR/ws" --elevated --claude-arg --permission-mode --claude-arg auto --approved-digest "$nedig" "esc task" >/dev/null 2>"${_TMP_DIR}/stderr.log" || rc=$?
ck "escalation (add --elevated) rc=3" "3" "$rc"
ck "escalation no spawn" "no" "$( [[ -e "$_TMP_DIR/logs/split-command.log" ]] && echo yes || echo no )"
eldig="$(bash "$PROJECT_DIR/bin/oe-delegate" -w "$_TMP_DIR/ws" --elevated --claude-arg --permission-mode --claude-arg auto --print-approval "esc task" 2>/dev/null | sed -n 's/.*承認ダイジェスト: //p' | tr -d ' ')"
reset_logs
rc=0
bash "$PROJECT_DIR/bin/oe-delegate" -w "$_TMP_DIR/ws" --claude-arg --permission-mode --claude-arg auto --approved-digest "$eldig" "esc task" >/dev/null 2>"${_TMP_DIR}/stderr.log" || rc=$?
ck "downgrade (drop --elevated) rc=3" "3" "$rc"
ck "elevated toggles digest" "yes" "$( [[ "$nedig" != "$eldig" ]] && echo yes || echo no )"

echo "[27] exit 帯（#309）: help=0 / 呼び方の誤り=2。spawn には至らない"
reset_logs
rc=0; bash "$PROJECT_DIR/bin/oe-delegate" --help >/dev/null 2>&1 || rc=$?
ck "--help は 0" "0" "$rc"
rc=0; bash "$PROJECT_DIR/bin/oe-delegate" -h >/dev/null 2>&1 || rc=$?
ck "-h は 0" "0" "$rc"
rc=0; bash "$PROJECT_DIR/bin/oe-delegate" --bogus >/dev/null 2>&1 || rc=$?
ck "unknown option は 2" "2" "$rc"
rc=0; bash "$PROJECT_DIR/bin/oe-delegate" -w "$_TMP_DIR/ws" >/dev/null 2>&1 || rc=$?
ck "task と --brief がどちらも無いのは 2" "2" "$rc"
# クォート忘れ（複数の位置引数）は、切り詰めた task で spawn せず 2 で止める
rc=0; bash "$PROJECT_DIR/bin/oe-delegate" -w "$_TMP_DIR/ws" my task here >/dev/null 2>&1 || rc=$?
ck "余分な位置引数は 2" "2" "$rc"
ck "上記のいずれも spawn しない" "no" "$( [[ -e "$_TMP_DIR/logs/split-command.log" ]] && echo yes || echo no )"

echo "=== RESULT: pass=${PASS} fail=${FAIL} ==="
[[ "$FAIL" -eq 0 ]]
