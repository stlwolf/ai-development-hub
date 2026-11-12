#!/usr/bin/env bash
set -uo pipefail

# test_agent.sh — lib/agent.sh（#562）の検査。bash 5 と bash 3.2（/bin/bash）の両方で回す。
#   T-2 の一部（既定の引数・モードの上書き）・T-3 の一部（権限のモードと elevated）・T-4 の一部（許す名前の集合）・
#   T-6（oe_agent_self・mock の ps で親をたどる）・T-7 の一部（復帰の案内の1行）

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=../lib/agent.sh
. "$PROJECT_DIR/lib/agent.sh"

_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$_TMP_DIR"' EXIT

PASS=0; FAIL=0
ck() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then echo "  PASS: $label"; PASS=$((PASS+1));
  else echo "  FAIL: $label (want=[$expected] got=[$actual])"; FAIL=$((FAIL+1)); fi
}
rc_of() { "$@" >/dev/null 2>&1; echo $?; }

echo "[1] 名前の集合"
ck "claude is valid" 0 "$(rc_of oe_agent_valid claude)"
ck "codex is valid" 0 "$(rc_of oe_agent_valid codex)"
ck "cursor is not valid (yet)" 1 "$(rc_of oe_agent_valid cursor)"
ck "empty is not valid" 1 "$(rc_of oe_agent_valid '')"

echo "[2] lease の binding で許すコマンド名（basename の完全一致）"
ck "claude allowed" 0 "$(rc_of oe_agent_comm_allowed claude)"
ck "codex allowed" 0 "$(rc_of oe_agent_comm_allowed codex)"
ck "absolute path is reduced to basename" 0 "$(rc_of oe_agent_comm_allowed /opt/homebrew/bin/codex)"
ck "bash is refused" 1 "$(rc_of oe_agent_comm_allowed bash)"
ck "partial match (codexd) is refused" 1 "$(rc_of oe_agent_comm_allowed codexd)"
ck "empty is refused" 1 "$(rc_of oe_agent_comm_allowed '')"

echo "[3] 既定の引数: claude は空（Claude の1行は変えない・受入 A-1）"
ck "claude default args are empty" "" "$(oe_agent_default_args claude)"
ck "claude default args stay empty with user args" "" "$(oe_agent_default_args claude --permission-mode auto)"

echo "[4] 既定の引数: codex は --no-daemon・更新の確認なし・--approve-for-me・developer の指示"
out="$(oe_agent_default_args codex | tr '\n' ' ')"
ck "codex has --no-daemon" yes "$([[ "$out" == *'--no-daemon '* ]] && echo yes || echo no)"
ck "codex disables the update check" yes "$([[ "$out" == *'-c check_for_update_on_startup=false '* ]] && echo yes || echo no)"
ck "codex has --approve-for-me by default" yes "$([[ "$out" == *'--approve-for-me '* ]] && echo yes || echo no)"
ck "codex carries developer_instructions" yes "$([[ "$out" == *'developer_instructions="'* ]] && echo yes || echo no)"
ck "developer_instructions text matches the constant" yes "$([[ "$out" == *"${OE_AGENT_CODEX_DEVELOPER_INSTRUCTIONS}"* ]] && echo yes || echo no)"
ck "developer_instructions has no newline" yes "$([[ "$OE_AGENT_CODEX_DEVELOPER_INSTRUCTIONS" != *$'\n'* ]] && echo yes || echo no)"
ck "developer_instructions has no double quote" yes "$([[ "$OE_AGENT_CODEX_DEVELOPER_INSTRUCTIONS" != *'"'* ]] && echo yes || echo no)"
ck "order: --no-daemon comes first" yes "$([[ "$out" == '--no-daemon '* ]] && echo yes || echo no)"

echo "[5] 承認のモードの上書き: 利用者が -a / -s / bypass / --yolo / --approve-for-me を渡したら既定の --approve-for-me を外す"
for a in "-a never" "--ask-for-approval never" "-s workspace-write" "--sandbox read-only" "--dangerously-bypass-approvals-and-sandbox" "--yolo" "--approve-for-me" "--sandbox=read-only" "--ask-for-approval=never"; do
  # shellcheck disable=SC2086
  out="$(oe_agent_default_args codex $a | tr '\n' ' ')"
  ck "override [$a] drops --approve-for-me" no "$([[ "$out" == *'--approve-for-me '* ]] && echo yes || echo no)"
  # shellcheck disable=SC2086
  ck "override [$a] keeps --no-daemon" yes "$([[ "$out" == *'--no-daemon '* ]] && echo yes || echo no)"
done
out="$(oe_agent_default_args codex -m gpt-5 | tr '\n' ' ')"
ck "unrelated user arg keeps --approve-for-me" yes "$([[ "$out" == *'--approve-for-me '* ]] && echo yes || echo no)"

echo "[6] 権限のモードの読み方と elevated"
ck "claude default" default "$(oe_agent_permission_mode claude)"
ck "claude --permission-mode auto" auto "$(oe_agent_permission_mode claude --permission-mode auto)"
ck "claude --permission-mode=plan" plan "$(oe_agent_permission_mode claude --permission-mode=plan)"
ck "claude bypass" bypassPermissions "$(oe_agent_permission_mode claude --dangerously-skip-permissions)"
ck "codex default is approve-for-me" approve-for-me "$(oe_agent_permission_mode codex)"
ck "codex -a never" never "$(oe_agent_permission_mode codex -a never)"
ck "codex --ask-for-approval=on-request" on-request "$(oe_agent_permission_mode codex --ask-for-approval=on-request)"
ck "codex -s workspace-write" sandbox:workspace-write "$(oe_agent_permission_mode codex -s workspace-write)"
ck "codex -s danger-full-access is elevated" bypassPermissions "$(oe_agent_permission_mode codex -s danger-full-access)"
ck "codex --sandbox=danger-full-access is elevated" bypassPermissions "$(oe_agent_permission_mode codex --sandbox=danger-full-access)"
ck "codex bypass flag is elevated" bypassPermissions "$(oe_agent_permission_mode codex --dangerously-bypass-approvals-and-sandbox)"
ck "codex --yolo is elevated" bypassPermissions "$(oe_agent_permission_mode codex --yolo)"
ck "codex -a never -s danger-full-access is elevated" bypassPermissions "$(oe_agent_permission_mode codex -a never -s danger-full-access)"
ck "codex -s danger-full-access -a never stays elevated" bypassPermissions "$(oe_agent_permission_mode codex -s danger-full-access -a never)"
ck "elevated predicate: bypassPermissions" 0 "$(rc_of oe_agent_mode_is_elevated bypassPermissions)"
ck "elevated predicate: never is not elevated" 1 "$(rc_of oe_agent_mode_is_elevated never)"
ck "elevated predicate: auto is not elevated" 1 "$(rc_of oe_agent_mode_is_elevated auto)"

echo "[7] 画面: 入力欄の記号と補完の文"
ck "claude prompt chars" '❯' "$(oe_agent_prompt_chars claude)"
ck "codex prompt chars include › and »" '❯›»' "$(oe_agent_prompt_chars codex)"
ck "unknown falls back to claude" '❯' "$(oe_agent_prompt_chars '')"
ck "codex placeholder includes Ask Codex" yes "$(oe_agent_placeholder_re codex | grep -qF 'Ask Codex to do anything' && echo yes || echo no)"
ck "claude placeholder has no Ask Codex" no "$(oe_agent_placeholder_re claude | grep -qF 'Ask Codex' && echo yes || echo no)"

echo "[8] oe_agent_self: claude の環境"
# shellcheck disable=SC2016
out="$(env -u CODEX_THREAD_ID CLAUDE_PID=4242 CLAUDE_CODE_SESSION_ID=sid-1 bash -c '. "$0"; oe_agent_self && printf "%s %s %s" "$OE_AGENT_SELF" "$OE_AGENT_SELF_PID" "$OE_AGENT_SELF_SID"' "$PROJECT_DIR/lib/agent.sh")"
ck "claude self" "claude 4242 sid-1" "$out"

echo "[9] oe_agent_self: codex の環境（mock の ps で親をたどる）"
cat > "$_TMP_DIR/ps" <<'EOF'
#!/usr/bin/env bash
# mock: ps -o ppid= -p <pid> / ps -o comm= -p <pid>。連鎖: 500(bash) -> 400(bash) -> 300(codex) -> 1
case "$*" in
  *"-o ppid= -p 500"*) echo " 400" ;;
  *"-o ppid= -p 400"*) echo " 300" ;;
  *"-o ppid= -p 300"*) echo " 1" ;;
  *"-o comm= -p 400"*) echo "/opt/homebrew/bin/bash" ;;
  *"-o comm= -p 300"*) echo "/opt/homebrew/Caskroom/codex/0.167.2/bin/codex" ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$_TMP_DIR/ps"
# 本物の関数は自分の pid（$$）から始めるので、mock の最初の段を呼び出すシェルの pid に合わせる（bash -c の中で書き換える）。
# shellcheck disable=SC2016  # $0 / $$ は子のシェルで展開させる
out="$(env -u CLAUDE_PID -u CLAUDE_CODE_SESSION_ID CODEX_THREAD_ID=thr-9 OE_TPI_PS="$_TMP_DIR/ps" bash -c 'sed -i.bak "s/-p 500\"/-p $$\"/" "$1"; . "$0"; oe_agent_self && printf "%s %s %s" "$OE_AGENT_SELF" "$OE_AGENT_SELF_PID" "$OE_AGENT_SELF_SID"' "$PROJECT_DIR/lib/agent.sh" "$_TMP_DIR/ps")"
ck "codex self via oe_agent_self (ancestor walk through mock ps)" "codex 300 thr-9" "$out"
# shellcheck disable=SC2016
out="$(env -u CLAUDE_PID -u CLAUDE_CODE_SESSION_ID CODEX_THREAD_ID=thr-9 OE_TPI_PS=/usr/bin/false bash -c '. "$0"; oe_agent_self; echo "rc=$? sid=$OE_AGENT_SELF_SID pid=[$OE_AGENT_SELF_PID]"' "$PROJECT_DIR/lib/agent.sh")"
ck "codex self without a reachable codex pid fails but keeps the session id" "rc=1 sid=thr-9 pid=[]" "$out"
# CLAUDE_* が tmux の環境から引き継がれていても、CODEX_THREAD_ID があれば自分は codex である
# shellcheck disable=SC2016
out="$(CLAUDE_PID=1 CLAUDE_CODE_SESSION_ID=leaked CODEX_THREAD_ID=thr-9 OE_TPI_PS=/usr/bin/false bash -c '. "$0"; oe_agent_self; echo "$OE_AGENT_SELF $OE_AGENT_SELF_SID"' "$PROJECT_DIR/lib/agent.sh")"
ck "CODEX_THREAD_ID wins over leaked CLAUDE_* env" "codex thr-9" "$out"
# shellcheck disable=SC2016
out="$(env -u CLAUDE_PID -u CLAUDE_CODE_SESSION_ID -u CODEX_THREAD_ID bash -c '. "$0"; oe_agent_self; echo "rc=$?"' "$PROJECT_DIR/lib/agent.sh")"
ck "no env -> rc 1" "rc=1" "$out"

echo "[10] 復帰の案内の1行"
out="$(oe_agent_resume_hint claude /tmp/ws 01KZ1VQA1979K4S2MMH5YY24ZJ 2 abc-123)"
ck "claude hint" "cd /tmp/ws && OE_LEASE_ID=01KZ1VQA1979K4S2MMH5YY24ZJ OE_GENERATION=2 claude --resume abc-123" "$out"
out="$(oe_agent_resume_hint codex /tmp/ws 01KZ1VQA1979K4S2MMH5YY24ZJ 1 abc-123)"
ck "codex hint starts with cd and codex --no-daemon" yes "$([[ "$out" == 'cd /tmp/ws && OE_LEASE_ID=01KZ1VQA1979K4S2MMH5YY24ZJ OE_GENERATION=1 codex --no-daemon -c check_for_update_on_startup=false -c '* ]] && echo yes || echo no)"
ck "codex hint ends with resume <sid>" yes "$([[ "$out" == *' resume abc-123' ]] && echo yes || echo no)"
ck "codex hint carries developer_instructions" yes "$([[ "$out" == *'developer_instructions='* ]] && echo yes || echo no)"

echo
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
