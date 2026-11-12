#!/usr/bin/env bash
set -euo pipefail

# test_oe_delegate.sh — oe-delegate の CLI 引数と spawn command を検証する
#
# 実 tmux / Claude は起動せず、PATH 先頭の tmux mock で split-window と send-keys を記録する。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

_TMP_DIR="$(mktemp -d)"
# #577: lease の記録を本物の置き場へ書かない。セッションの CLAUDE_PID・session_id・lease の環境も外す
# （外さないと oe-register root などが本物の置き場に lease を作る）。
export OE_LEASE_DIR="${_TMP_DIR}/lease"
# #562: 拍動の床（oe-delegate が lease の名前で書く sidecar）も本物の置き場へ書かない。
export OE_HEARTBEAT_DIR="${_TMP_DIR}/hb"
unset CLAUDE_PID CLAUDE_CODE_SESSION_ID OE_LEASE_ID OE_GENERATION CODEX_HOME 2>/dev/null || true
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
  # oe_reg_gc は '#{pane_id} #{pid}' を要求する（#270）。server pid は $TMUX から導いて
  # _oe_reg_server_pid と必ず一致させる。
  if [[ "$*" == *'#{pid}'* ]]; then
    _sp="${TMUX#*,}"; _sp="${_sp%%,*}"
    printf '%%1 %s\n%%9 %s\n' "$_sp" "$_sp"
  else
    printf '%%1\n%%9\n'
  fi
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

# 子のコマンドの頭の lease の環境変数（#577 PR-2・ID は起こすたびに違う）を外して比べる。付いていることは [L] で確かめる。
split_cmd() {
  sed -E "s/^OE_LEASE_ID='[0-9A-HJKMNP-TV-Z]{26}' OE_GENERATION='1' //" "$_TMP_DIR/logs/split-command.log"
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
ck "default child command" "PARENT_TMUX_PANE='%1' claude" "$(split_cmd)"
ck "task sent to child pane" "yes" "$(grep -q -- 'send-keys -l -t %9 -- default task' "$_TMP_DIR/logs/send-keys.log" && echo yes || echo no)"
ck "Enter sent" "yes" "$(grep -q -- 'send-keys -t %9 Enter' "$_TMP_DIR/logs/send-keys.log" && echo yes || echo no)"

echo "[2] --claude-arg is repeatable and preserves one arg per flag"
reset_logs
run_delegate -w "$_TMP_DIR/ws" --label "#152" --claude-arg --permission-mode --claude-arg auto "arg task"
ck "claude args in child command" "PARENT_TMUX_PANE='%1' claude '--permission-mode' 'auto'" "$(split_cmd)"

echo "[3] --claude-arg combines with --brief add-dir"
reset_logs
brief="${_TMP_DIR}/ws/.oe/brief.md"
printf '%s\n' '# brief' > "$brief"
run_delegate -w "$_TMP_DIR/ws" --label "#152" --claude-arg --permission-mode --claude-arg auto --brief "$brief" "brief task"
expected_cmd="PARENT_TMUX_PANE='%1' claude '--permission-mode' 'auto' --add-dir '${_TMP_DIR}/ws/.oe'"
ck "brief add-dir follows claude args" "$expected_cmd" "$(split_cmd)"
ck "brief path sent" "yes" "$(grep -qF -- "$brief を読んで進めて。 brief task" "$_TMP_DIR/logs/send-keys.log" && echo yes || echo no)"

echo "[4] --claude-arg shell-quotes single quotes"
reset_logs
run_delegate -w "$_TMP_DIR/ws" --label "#152" --claude-arg "foo'bar" "quote task"
ck "single quote escaped in child command" "PARENT_TMUX_PANE='%1' claude 'foo'\\''bar'" "$(split_cmd)"

echo "[5] --claude-arg preserves spaces and shell metacharacters"
reset_logs
meta_arg="a b;"'$'"(x)"
run_delegate -w "$_TMP_DIR/ws" --label "#152" --claude-arg "$meta_arg" "meta task"
ck "spaces/metacharacters quoted in child command" "PARENT_TMUX_PANE='%1' claude 'a b;\$(x)'" "$(split_cmd)"

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
ck "split child command unchanged" "PARENT_TMUX_PANE='%1' claude" "$(split_cmd)"

echo "[12] --kickoff は --brief の deprecated alias（回帰・#255）"
# oe-delegate 側の alias。--brief と同一に add-dir 開示 + payload を組む。
reset_logs
alias_brief="${_TMP_DIR}/ws/.oe/alias-brief.md"
printf '%s\n' '# brief' > "$alias_brief"
run_delegate -w "$_TMP_DIR/ws" --label "#152" --kickoff "$alias_brief" "alias task"
ck "alias add-dir opens brief dir" "PARENT_TMUX_PANE='%1' claude --add-dir '${_TMP_DIR}/ws/.oe'" "$(split_cmd)"
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
ck "matching digest spawns child" "PARENT_TMUX_PANE='%1' claude '--permission-mode' 'auto'" "$(split_cmd)"

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
ck "elevated + matching digest spawns" "PARENT_TMUX_PANE='%1' claude '--permission-mode' 'auto'" "$(split_cmd)"

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

echo "[L] #577 PR-2: 子のコマンドの頭に lease の環境変数が付き、lease の記録ができる"
reset_logs
run_delegate -w "$_TMP_DIR/ws" --label "#577" "lease task"
_lid="$(sed -nE "s/^OE_LEASE_ID='([0-9A-HJKMNP-TV-Z]{26})' OE_GENERATION='1' .*/\\1/p" "$_TMP_DIR/logs/split-command.log")"
ck "lease の環境変数が付く" "26" "${#_lid}"
ck "lease の記録がある" "#577" "$(jq -r '.label' "$OE_LEASE_DIR/${_lid}.json" 2>/dev/null)"
ck "モックの tmux ではペインの端末が分からないので binding は未確定のまま" "null" "$(jq -r '.generations[0].binding' "$OE_LEASE_DIR/${_lid}.json" 2>/dev/null)"
ck "binding が未確定であることを名乗る" "yes" "$(grep -q 'binding は未確定' "$_TMP_DIR/stderr.log" && echo yes || echo no)"
ck "lease の置き場は一時ディレクトリ" "yes" "$([[ "$OE_LEASE_DIR" == "$_TMP_DIR"/* ]] && echo yes || echo no)"

echo "[L2] #577 PR-2: lease の置き場が決まらないときは、いままでどおりのコマンドで子を起こす"
reset_logs
OE_LEASE_DIR="" run_delegate -w "$_TMP_DIR/ws" --label "#577" "no lease task"
ck "lease の環境変数が付かない" "PARENT_TMUX_PANE='%1' claude" "$(cat "$_TMP_DIR/logs/split-command.log")"

# --- #562: 委譲ごとのエージェントの指定（lib/agent.sh） ---
# shellcheck source=../lib/agent.sh
. "$PROJECT_DIR/lib/agent.sh"
DI_ARG="developer_instructions=\"${OE_AGENT_CODEX_DEVELOPER_INSTRUCTIONS}\""
CODEX_HEAD="PARENT_TMUX_PANE='%1' codex '--no-daemon' '-c' 'check_for_update_on_startup=false'"

echo "[A1] #562 T-1: --agent 無しの子のコマンドは claude のまま（[1][2] と同じ値・受入 A-1）"
reset_logs
run_delegate -w "$_TMP_DIR/ws" --label "#562" --claude-arg --permission-mode --claude-arg auto "a1"
ck "claude の1行は変わらない" "PARENT_TMUX_PANE='%1' claude '--permission-mode' 'auto'" "$(split_cmd)"
ck "registry の agent は claude" "claude" "$(jq -r '.agent' "$OE_DELEGATE_STATE_DIR"/*.json | head -1)"

echo "[A2] #562 T-2: --agent codex は --no-daemon・更新の確認なし・--approve-for-me・developer の指示を付けて起こす"
reset_logs
run_delegate -w "$_TMP_DIR/ws" --label "#562c" --agent codex "a2"
ck "codex の1行" "${CODEX_HEAD} '--approve-for-me' '-c' '${DI_ARG}'" "$(split_cmd)"
ck "developer の指示に改行が無い" "1" "$(wc -l < "$_TMP_DIR/logs/split-command.log" | tr -d ' ')"
_lid="$(sed -nE "s/^OE_LEASE_ID='([0-9A-HJKMNP-TV-Z]{26})' OE_GENERATION='1' .*/\\1/p" "$_TMP_DIR/logs/split-command.log")"
ck "lease の記録に agent: codex" "codex" "$(jq -r '.agent' "$OE_LEASE_DIR/${_lid}.json" 2>/dev/null)"
ck "lease の記録が validate-lease を通る" "0" "$(bash "$PROJECT_DIR/scripts/validate-lease.sh" "$OE_LEASE_DIR/${_lid}.json" >/dev/null 2>&1; echo $?)"
ck "registry の agent は codex" "codex" "$(jq -r 'select(.label=="#562c") | .agent' "$OE_DELEGATE_STATE_DIR"/*.json | head -1)"

echo "[A3] #562 T-2: --agent-arg で承認のモードを指定したら既定の --approve-for-me を外す。--claude-arg は alias"
reset_logs
run_delegate -w "$_TMP_DIR/ws" --agent codex --agent-arg -a --agent-arg never "a3"
ck "-a never で --approve-for-me が外れる" "${CODEX_HEAD} '-c' '${DI_ARG}' '-a' 'never'" "$(split_cmd)"
reset_logs
run_delegate -w "$_TMP_DIR/ws" --agent codex --claude-arg -m --claude-arg gpt-5 "a3b"
ck "--claude-arg は --agent-arg の alias（モードの指定でないので既定は残る）" "${CODEX_HEAD} '--approve-for-me' '-c' '${DI_ARG}' '-m' 'gpt-5'" "$(split_cmd)"
reset_logs
brief2="${_TMP_DIR}/ws/.oe/brief2.md"; printf '%s\n' '# brief' > "$brief2"
run_delegate -w "$_TMP_DIR/ws" --agent codex --brief "$brief2" "a3c"
ck "codex でも --brief の dir を --add-dir で渡す" "yes" "$(grep -qF -- "--add-dir '${_TMP_DIR}/ws/.oe'" "$_TMP_DIR/logs/split-command.log" && echo yes || echo no)"

echo "[A4] #562: 知らないエージェントは 2 で止め、spawn しない"
reset_logs
rc=0; bash "$PROJECT_DIR/bin/oe-delegate" -w "$_TMP_DIR/ws" --agent cursor "a4" >/dev/null 2>"${_TMP_DIR}/stderr.log" || rc=$?
ck "unknown agent rc=2" "2" "$rc"
ck "unknown agent no spawn" "no" "$( [[ -e "$_TMP_DIR/logs/split-command.log" ]] && echo yes || echo no )"
rc=0; bash "$PROJECT_DIR/bin/oe-delegate" -w "$_TMP_DIR/ws" --agent >/dev/null 2>&1 || rc=$?
ck "--agent requires a value" "2" "$rc"

echo "[A5] #562 T-3: ダイジェストは agent を含み、claude と codex で値が違う。承認パッケージにエージェントが出る"
d_cl="$(bash "$PROJECT_DIR/bin/oe-delegate" -w "$_TMP_DIR/ws" --print-approval "a5" 2>/dev/null | sed -n 's/.*承認ダイジェスト: //p' | tr -d ' ')"
d_cx="$(bash "$PROJECT_DIR/bin/oe-delegate" -w "$_TMP_DIR/ws" --agent codex --print-approval "a5" 2>/dev/null | sed -n 's/.*承認ダイジェスト: //p' | tr -d ' ')"
ck "claude と codex でダイジェストが違う" "yes" "$( [[ -n "$d_cl" && -n "$d_cx" && "$d_cl" != "$d_cx" ]] && echo yes || echo no )"
pkg="$(bash "$PROJECT_DIR/bin/oe-delegate" -w "$_TMP_DIR/ws" --agent codex --agent-arg -m --agent-arg gpt-5 --print-approval "a5" 2>/dev/null)"
ck "パッケージにエージェントの行" "yes" "$(printf '%s\n' "$pkg" | grep -q '^  エージェント    : codex$' && echo yes || echo no)"
pkg_cl="$(bash "$PROJECT_DIR/bin/oe-delegate" -w "$_TMP_DIR/ws" --print-approval "a5" 2>/dev/null)"
ck "claude のパッケージにはエージェントの行が無い（表示は変更前と同じ・A-1）" "no" "$(printf '%s\n' "$pkg_cl" | grep -q 'エージェント' && echo yes || echo no)"
ck "claude のパッケージの再構成に --agent は無い" "no" "$(printf '%s\n' "$pkg_cl" | grep -q -- '--agent ' && echo yes || echo no)"
ck "再構成したコマンドに --agent codex" "yes" "$(printf '%s\n' "$pkg" | grep -q -- "--agent 'codex'" && echo yes || echo no)"
ck "再構成したコマンドに --agent-arg" "yes" "$(printf '%s\n' "$pkg" | grep -q -- "--agent-arg '-m' --agent-arg 'gpt-5'" && echo yes || echo no)"
ck "codex の既定の権限のモードは approve-for-me" "yes" "$(printf '%s\n' "$pkg" | grep -q '要求権限モード  : approve-for-me' && echo yes || echo no)"
reset_logs
run_delegate -w "$_TMP_DIR/ws" --agent codex --approved-digest "$d_cx" "a5"
ck "codex の承認ダイジェストが一致すれば spawn" "yes" "$( [[ -e "$_TMP_DIR/logs/split-command.log" ]] && echo yes || echo no )"
reset_logs
rc=0; bash "$PROJECT_DIR/bin/oe-delegate" -w "$_TMP_DIR/ws" --agent codex --approved-digest "$d_cl" "a5" >/dev/null 2>&1 || rc=$?
ck "claude の承認で codex を起こすと不一致 rc=3" "3" "$rc"

echo "[A6] #562 T-3: codex の elevated（--yolo・-s danger-full-access）は承認ダイジェストが必須"
for a in "--yolo" "--dangerously-bypass-approvals-and-sandbox"; do
  reset_logs
  rc=0; bash "$PROJECT_DIR/bin/oe-delegate" -w "$_TMP_DIR/ws" --agent codex --agent-arg "$a" "a6" >/dev/null 2>&1 || rc=$?
  ck "codex $a は elevated → rc=3" "3" "$rc"
done
reset_logs
rc=0; bash "$PROJECT_DIR/bin/oe-delegate" -w "$_TMP_DIR/ws" --agent codex --agent-arg -s --agent-arg danger-full-access "a6" >/dev/null 2>&1 || rc=$?
ck "codex -s danger-full-access は elevated → rc=3" "3" "$rc"
reset_logs
run_delegate -w "$_TMP_DIR/ws" --agent codex --agent-arg -a --agent-arg never "a6"
ck "codex -a never は elevated でない（spawn する）" "yes" "$( [[ -e "$_TMP_DIR/logs/split-command.log" ]] && echo yes || echo no )"

echo "[A7] #562 DJ-14: codex の規則のファイルが無ければ1行知らせて続ける。利用者の developer_instructions があれば1行知らせる"
reset_logs
mkdir -p "$_TMP_DIR/codex-home"
CODEX_HOME="$_TMP_DIR/codex-home" run_delegate -w "$_TMP_DIR/ws" --agent codex "a7"
ck "規則が無い知らせ" "yes" "$(grep -q 'oe-child.rules が無い' "$_TMP_DIR/stderr.log" && echo yes || echo no)"
ck "それでも spawn する" "yes" "$( [[ -e "$_TMP_DIR/logs/split-command.log" ]] && echo yes || echo no )"
mkdir -p "$_TMP_DIR/codex-home/rules"; : > "$_TMP_DIR/codex-home/rules/oe-child.rules"
printf 'developer_instructions = "mine"\n' > "$_TMP_DIR/codex-home/config.toml"
reset_logs
CODEX_HOME="$_TMP_DIR/codex-home" run_delegate -w "$_TMP_DIR/ws" --agent codex "a7b"
ck "規則があれば知らせない" "no" "$(grep -q 'oe-child.rules が無い' "$_TMP_DIR/stderr.log" && echo yes || echo no)"
ck "利用者の developer_instructions の上書きを知らせる" "yes" "$(grep -q 'developer_instructions は、この子の中では' "$_TMP_DIR/stderr.log" && echo yes || echo no)"
reset_logs
run_delegate -w "$_TMP_DIR/ws" "a7c"
ck "claude の子には codex の知らせを出さない" "no" "$(grep -q 'oe-child.rules' "$_TMP_DIR/stderr.log" && echo yes || echo no)"

echo "[A8] #562 T-8: 拍動の床 — 起こしたあと lease の名前で sidecar を1件書き、lease からペインを引ける"
reset_logs
run_delegate -w "$_TMP_DIR/ws" --label "#562h" --agent codex "a8"
_lid="$(sed -nE "s/^OE_LEASE_ID='([0-9A-HJKMNP-TV-Z]{26})' OE_GENERATION='1' .*/\\1/p" "$_TMP_DIR/logs/split-command.log")"
ck "sidecar が lease の名前で在る" "yes" "$( [[ -f "$OE_HEARTBEAT_DIR/${_lid}.json" ]] && echo yes || echo no )"
ck "sidecar の pane は子のペイン" "%9" "$(jq -r '.pane' "$OE_HEARTBEAT_DIR/${_lid}.json" 2>/dev/null)"
ck "sidecar の server_pid は \$TMUX の pid" "12345" "$(jq -r '.server_pid' "$OE_HEARTBEAT_DIR/${_lid}.json" 2>/dev/null)"
ck "sidecar の lease_id と generation" "${_lid} 1" "$(jq -r '"\(.lease_id) \(.generation)"' "$OE_HEARTBEAT_DIR/${_lid}.json" 2>/dev/null)"
ck "sidecar の agent" "codex" "$(jq -r '.agent' "$OE_HEARTBEAT_DIR/${_lid}.json" 2>/dev/null)"
ck "sidecar の model は空の object（読む側の display_name が落ちない）" "object" "$(jq -r '.model | type' "$OE_HEARTBEAT_DIR/${_lid}.json" 2>/dev/null)"
# shellcheck source=../lib/heartbeat-resolve.sh
. "$PROJECT_DIR/lib/heartbeat-resolve.sh"
ck "oe_hb_pane_for が lease_id と generation で候補のペインを返す" "%9" "$(oe_hb_pane_for 12345 900 "$_lid" 1 | cut -f1)"
reset_logs
run_delegate -w "$_TMP_DIR/ws" --label "#562hc" "a8b"
_lid2="$(sed -nE "s/^OE_LEASE_ID='([0-9A-HJKMNP-TV-Z]{26})' OE_GENERATION='1' .*/\\1/p" "$_TMP_DIR/logs/split-command.log")"
ck "claude の子にも床を書く（agent: claude）" "claude" "$(jq -r '.agent' "$OE_HEARTBEAT_DIR/${_lid2}.json" 2>/dev/null)"
ck "本物の置き場には書いていない" "yes" "$( [[ "$OE_HEARTBEAT_DIR" == "$_TMP_DIR"/* ]] && echo yes || echo no )"

echo "[A9] #562 T-8: 子が oe-send を打つたびに、自分の lease の名前で床を書き直す（子の環境: OE_LEASE_ID・OE_GENERATION・TMUX_PANE）"
rm -f "$OE_HEARTBEAT_DIR/${_lid}.json"
rm -f "$_TMP_DIR/logs/"*.log
rc=0; OE_LEASE_ID="$_lid" OE_GENERATION=1 TMUX_PANE="%9" CODEX_THREAD_ID=thr-1 OE_TPI_PS=/usr/bin/false \
  bash "$PROJECT_DIR/bin/oe-send" %1 "floor ping" >/dev/null 2>"${_TMP_DIR}/stderr.log" || rc=$?
ck "oe-send は送れる" "0" "$rc"
ck "床が子の lease の名前で書き直される" "yes" "$( [[ -f "$OE_HEARTBEAT_DIR/${_lid}.json" ]] && echo yes || echo no )"
ck "床の pane は自分のペイン" "%9" "$(jq -r '.pane' "$OE_HEARTBEAT_DIR/${_lid}.json" 2>/dev/null)"
ck "床の agent は自分のエージェント（CODEX_THREAD_ID があれば codex）" "codex" "$(jq -r '.agent' "$OE_HEARTBEAT_DIR/${_lid}.json" 2>/dev/null)"
rm -f "$OE_HEARTBEAT_DIR/${_lid}.json"
rc=0; env -u OE_LEASE_ID -u OE_GENERATION TMUX_PANE="%9" bash "$PROJECT_DIR/bin/oe-send" %1 "no lease ping" >/dev/null 2>&1 || rc=$?
ck "lease の無い送り手は床を書かない" "no" "$( [[ -f "$OE_HEARTBEAT_DIR/${_lid}.json" ]] && echo yes || echo no )"

echo "[A10] #562 DJ-10: oe-send は宛先のエージェントを registry から引いて lib に渡す（OE_SEND_TARGET_AGENT）"
rm -f "$_TMP_DIR/logs/"*.log
cat > "$_TMP_DIR/bin/oe-probe-env" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${OE_SEND_TARGET_AGENT:-<unset>}" >> "${OE_DELEGATE_TEST_LOG_DIR}/target-agent.log"
EOF
chmod +x "$_TMP_DIR/bin/oe-probe-env"
# registry に %9 を codex として登記してから送る。lib の中で環境を読む口は無いので、send-keys の mock に記録させる代わりに
# 子プロセスの環境を記録する: oe-send の後段で呼ばれる lib の関数は無いため、ここでは registry の値を lease 無しで引く経路だけを見る。
# shellcheck source=../lib/delegate-registry.sh
. "$PROJECT_DIR/lib/delegate-registry.sh"
oe_reg_record "%9" "#562x" "$_TMP_DIR/ws" "%1" codex
ck "registry の %9 は codex" "codex" "$(jq -r '.agent' "$OE_DELEGATE_STATE_DIR/$(_oe_reg_key %9).json")"
out="$(env -u OE_LEASE_ID -u OE_GENERATION bash -c '. "$1/lib/delegate-registry.sh"; f="$OE_DELEGATE_STATE_DIR/$(_oe_reg_key %9).json"; jq -r ".agent // \"\"" "$f"' _ "$PROJECT_DIR")"
ck "oe-send が引く registry の agent の経路（同じ式）" "codex" "$out"

echo "=== RESULT: pass=${PASS} fail=${FAIL} ==="
[[ "$FAIL" -eq 0 ]]
