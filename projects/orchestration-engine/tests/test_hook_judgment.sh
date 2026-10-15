#!/usr/bin/env bash
# shellcheck disable=SC2016  # 表のコマンドは意図して単一引用符の文字列（$HOME 等は展開させない）
set -euo pipefail

# test_hook_judgment.sh — 止める側のフック2本（block-destructive / block-force-push）の
# 判定（allow / deny）を表で固定し、迂回を捕まえる（#429）。
#
# フックには JSON を標準入力で渡して判定だけをさせる。コマンドは1つも実行しない。
# 発火の記録は HOOK_FIRING_DIR を一時ディレクトリに向けて、実物の記録を汚さない。
#
# 群の意味（plan の DJ-10）:
#   A 固定        — 今の判定。変更前でも通る。受入の錨ではない
#   B 迂回の捕捉  — 変更前の master では落ちる。受入の錨
#   C 安全な形    — 今 allow で、変更後も allow のまま。誤検知の見張り
#   D 意図した変更 — 今の過検知を allow に直す。変更前では落ちる
#   E 終わること  — 閉じない構文や深い入れ子でも timeout の下で 0 か 2 に到達する
#
# 実行系: フックを起動する bash は HOOK_BASH（既定はこのテストを動かしている bash）。
#   bash tests/test_hook_judgment.sh        # PATH の bash（5 系）
#   /bin/bash tests/test_hook_judgment.sh   # 3.2
# 変更前のスクリプトに当てるときは HOOKS_DIR で scripts の置き場を差し替える。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HOOKS_DIR="${HOOKS_DIR:-$REPO_ROOT/canonical/hooks/scripts}"
HB="${HOOK_BASH:-$BASH}"
BD="$HOOKS_DIR/block-destructive.sh"
FP="$HOOKS_DIR/block-force-push.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }
command -v timeout >/dev/null 2>&1 || { echo "SKIP: timeout required"; exit 0; }
[[ -f "$BD" && -f "$FP" ]] || { echo "FAIL: hooks not found under $HOOKS_DIR"; exit 1; }

_TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$_TMP_DIR"; }
trap cleanup EXIT
STATE="$_TMP_DIR/state"
mkdir -p "$STATE"

echo "hooks: $HOOKS_DIR"
echo "bash:  $HB ($("$HB" -c 'echo "$BASH_VERSION"'))"

PASS=0; FAIL=0
GN=(A B C D E); GP=(0 0 0 0 0); GF=(0 0 0 0 0)
gidx() { case "$1" in A) echo 0 ;; B) echo 1 ;; C) echo 2 ;; D) echo 3 ;; E) echo 4 ;; *) echo "bad group: $1" >&2; exit 1 ;; esac; }

deny_lines() { [[ -f "$STATE/deny.jsonl" ]] && wc -l < "$STATE/deny.jsonl" | tr -d ' ' || echo 0; }

# t <群> <allow|deny> <bd|fp> <rule または -> <コマンド>
# 1行で rc・permission の JSON・deny.jsonl の rule（deny）／行数が増えないこと（allow）を照合する。
t() {
  local group="$1" expect="$2" hook="$3" rule="$4" cmd="$5"
  local script before after rc out perm last_rule why=""
  case "$hook" in bd) script="$BD" ;; fp) script="$FP" ;; *) echo "bad hook: $hook"; exit 1 ;; esac
  before="$(deny_lines)"
  out="$(jq -cn --arg c "$cmd" '{tool_input:{command:$c}}' \
        | timeout 10 env HOOK_FIRING_DIR="$STATE" CLAUDE_PROJECT_DIR=/tmp "$HB" "$script" 2>/dev/null)" && rc=0 || rc=$?
  after="$(deny_lines)"
  perm="$(printf '%s' "$out" | jq -r '.permission // empty' 2>/dev/null || true)"
  case "$expect" in
    allow)
      [[ "$rc" == 0 ]]        || why="rc=$rc (want 0)"
      [[ "$perm" == allow ]]  || why="${why:+$why; }permission=[$perm] (want allow)"
      [[ "$after" == "$before" ]] || why="${why:+$why; }deny.jsonl grew ($before -> $after)"
      ;;
    deny)
      [[ "$rc" == 2 ]]        || why="rc=$rc (want 2)"
      [[ "$perm" == deny ]]   || why="${why:+$why; }permission=[$perm] (want deny)"
      last_rule="$(tail -1 "$STATE/deny.jsonl" 2>/dev/null | jq -r '.rule // empty' 2>/dev/null || true)"
      [[ "$last_rule" == "$rule" ]] || why="${why:+$why; }rule=[$last_rule] (want $rule)"
      ;;
    *) echo "bad expect: $expect"; exit 1 ;;
  esac
  local shown="${cmd//$'\n'/⏎}" gi
  gi="$(gidx "$group")"
  if [[ -z "$why" ]]; then
    PASS=$((PASS + 1)); GP[gi]=$((GP[gi] + 1))
    echo "  PASS [$group] $hook $expect: $shown"
  else
    FAIL=$((FAIL + 1)); GF[gi]=$((GF[gi] + 1))
    echo "  FAIL [$group] $hook $expect: $shown  -- $why"
  fi
}

NL=$'\n'
TAB=$'\t'

echo "[A] 今の判定を固定する（変更前でも通る）"
t A allow bd - 'echo hello'
t A deny  bd rm-destructive 'rm -rf /'
t A deny  bd rm-destructive 'rm -rf ~'
t A deny  bd rm-destructive 'rm -rf $HOME'
t A deny  bd rm-destructive 'rm -rf ~/'
t A deny  bd rm-destructive 'rm -rf ~/x'
t A deny  bd rm-destructive 'rm -rf $HOME/x'
t A deny  bd rm-destructive 'rm -rf /tmp/x'
t A deny  bd rm-destructive 'rm -rf .'
t A deny  bd rm-destructive 'rm -rf ..'
t A deny  bd rm-destructive 'rm -rf /*'
t A deny  bd rm-destructive 'rm -fr /'
t A deny  bd rm-destructive 'rm -r -f /'
t A deny  bd rm-destructive 'rm --recursive --force /'
t A deny  bd rm-destructive 'rm -rf -- /'
t A deny  bd rm-destructive 'rm -Rf /'
t A deny  bd rm-destructive 'rm -rfv /'
t A deny  bd rm-destructive 'rm -rf node_modules /'
t A deny  bd rm-destructive 'rm -rf / 2>/dev/null'
t A deny  bd rm-destructive 'sudo rm -rf /'
t A deny  bd rm-destructive 'sudo -E rm -rf /'
t A deny  bd rm-destructive 'rm -rf / & true'
t A allow bd - 'rm -rf node_modules'
t A allow bd - 'rm -rf node_modules dist'
t A allow bd - 'rm -rf foo'
t A allow bd - 'rm -rf ../x'
t A allow bd - 'rm -r /'
t A allow bd - 'rm -f /'
t A allow bd - 'rm -rf'
t A deny  bd chmod-recursive-root 'chmod -R 777 /'
t A deny  bd chown-recursive-root 'chown -R u /'
t A deny  bd mkfs 'mkfs.ext4 /dev/sda'
t A deny  bd dd-device 'dd if=/dev/zero of=/dev/sda'
t A deny  bd git-reset-hard 'git reset --hard'
t A deny  bd git-reset-hard 'git reset -q --hard HEAD~1'
t A deny  bd git-clean-fdx 'git clean -fdx'
t A deny  bd git-clean-fdx 'git clean -xfd'
t A deny  bd git-clean-fdx 'git clean -f -d -x'
t A allow bd - 'git clean --force -n'
t A allow bd - 'git clean -fd'
t A allow bd - 'git reset --soft HEAD~1'
t A allow bd - 'git push --force'
t A deny  bd sql-destructive 'psql -c "DROP TABLE x"'
t A deny  bd sql-destructive 'echo "DROP TABLE x"'
t A deny  bd sql-destructive 'cd x && psql -c "drop database x"'
t A deny  bd sql-destructive "cat > f <<'EOF'${NL}TRUNCATE TABLE x${NL}EOF"
t A deny  fp force-push 'git push --force'
t A deny  fp force-push 'git push -f origin x'
t A deny  fp force-push 'git -C x push --force'
t A deny  fp force-push 'git push origin x -f'
t A deny  fp force-push 'git push --force-with-lease --force'
t A deny  fp force-push 'git commit -m x && git push --force'
t A allow fp - 'git push origin main'
t A allow fp - 'git push --force-with-lease origin x'
t A allow fp - 'git push --force-if-includes origin x'
t A allow fp - 'echo hello'
t A allow fp - 'rm -rf /'

echo "[B] 迂回の捕捉（変更前の master では落ちる・受入の錨）"
# issue 本文の3つの形
t B deny bd rm-destructive 'cd /tmp && rm -rf /'
t B deny bd rm-destructive 'true; rm -rf ~'
t B deny bd rm-destructive 'bash -c "rm -rf /"'
# 族1: 区切り
t B deny bd rm-destructive "sh -c 'rm -rf /'"
t B deny bd rm-destructive 'bash -lc "rm -rf /"'
t B deny bd rm-destructive "bash -c -- 'rm -rf /'"
t B deny bd rm-destructive "bash -o errexit -c 'rm -rf /'"
t B deny bd rm-destructive "zsh -c 'rm -rf /'"
t B deny bd rm-destructive 'cd x || rm -rf /'
t B deny bd rm-destructive 'ls | rm -rf /'
t B deny bd rm-destructive '(rm -rf /)'
t B deny bd rm-destructive '{ rm -rf /; }'
t B deny bd rm-destructive '$(rm -rf /)'
t B deny bd rm-destructive 'echo $(rm -rf /)'
t B deny bd rm-destructive 'echo "$(rm -rf /)"'
t B deny bd rm-destructive 'echo `rm -rf /`'
t B deny bd rm-destructive 'eval "rm -rf /"'
t B deny bd rm-destructive 'eval rm -rf /'
t B deny bd rm-destructive "true${NL}rm -rf /"
t B deny bd rm-destructive 'rm -rf node_modules && rm -rf /'   # 変更前でも deny（先頭が rm で / が対象に混ざる）。錨に数えない
t B deny bd git-reset-hard 'rm -rf node_modules && git reset --hard'
t B deny bd rm-destructive "cat <<EOF${NL}\$(rm -rf /)${NL}EOF"
t B deny bd rm-destructive "cat <<EOF${NL}\`rm -rf /\`${NL}EOF"
t B deny bd rm-destructive 'if true; then rm -rf /; fi'
t B deny bd rm-destructive 'case x in x) rm -rf /;; esac'
# 族2: 前置き
t B deny bd rm-destructive ' rm -rf /'
t B deny bd rm-destructive '\rm -rf /'
t B deny bd rm-destructive '/bin/rm -rf /'
t B deny bd rm-destructive 'env rm -rf /'
t B deny bd rm-destructive 'env -u git rm -rf /'
t B deny bd rm-destructive 'command rm -rf /'
t B deny bd rm-destructive 'exec rm -rf /'
t B deny bd rm-destructive 'nohup rm -rf /'
t B deny bd rm-destructive 'time rm -rf /'
t B deny bd rm-destructive 'timeout 10 rm -rf /'
t B deny bd rm-destructive 'FOO=1 rm -rf /'
t B deny bd rm-destructive '>/dev/null rm -rf /'
t B deny bd rm-destructive '! rm -rf /'
t B deny bd rm-destructive 'sudo -u root rm -rf /'
# 族3: 対象の書き方
t B deny bd rm-destructive 'rm -rf "/"'
t B deny bd rm-destructive "rm -rf '/'"
t B deny bd rm-destructive 'rm -rf "~"'
t B deny bd rm-destructive 'rm -rf "$HOME"'
t B deny bd rm-destructive 'rm -rf ${HOME}'
t B deny bd rm-destructive 'rm -rf "${HOME}"/x'
t B deny bd rm-destructive 'rm -rf ./'
t B deny bd rm-destructive 'rm -rf ~user'
t B deny bd rm-destructive 'rm -rf "/my dir"'
t B deny bd rm-destructive "\$'rm' -rf /"
t B deny bd rm-destructive 'r\m -rf /'
t B deny bd rm-destructive "r\\${NL}m -rf /"
t B deny bd rm-destructive "rm -r\\${NL}f /"
# ほかの検査（同じ型の抜け）
t B deny bd chmod-recursive-root 'cd x && chmod -R 777 /'
t B deny bd chown-recursive-root 'cd x && chown -R u /'
t B deny bd mkfs 'cd x && mkfs.ext4 /dev/sda'
t B deny bd dd-device 'cd x && dd if=/dev/zero of=/dev/sda'
t B deny bd git-reset-hard 'cd x && git reset --hard'
t B deny bd git-reset-hard 'git -C x reset --hard'
t B deny bd git-reset-hard 'git stash; git reset --hard'
t B deny bd git-clean-fdx 'cd x && git clean -fdx'
t B deny bd git-clean-fdx 'git -C x clean -fdx'
# 意図した deny（DJ-3 の境界の固定）
t B deny bd rm-destructive 'echo rm -rf /'
t B deny bd rm-destructive 'git rm -rf .'
# 入れ子の上限（9段で nesting-limit）
t B deny bd nesting-limit 'eval eval eval eval eval eval eval eval eval echo x'
# force-push
t B deny fp force-push 'cd x && git push --force'
t B deny fp force-push 'true; git push -f'
t B deny fp force-push 'bash -c "git push --force"'
t B deny fp force-push 'sudo git push --force'
t B deny fp force-push 'eval "git push --force"'

echo "[C] 安全な形の守り（今 allow・変更後も allow）"
t C allow bd - "echo 'rm -rf /'"
t C allow bd - 'echo "rm -rf /"'
t C allow bd - 'git commit -m "fix: deny cd /tmp && rm -rf /"'
t C allow bd - "grep -n 'rm -rf /' file"
t C allow bd - "printf '%s\\n' 'cd /tmp && rm -rf /' > f"
t C allow bd - "python3 -c \"print('rm -rf /')\""
t C allow bd - "cat > f <<'EOF'${NL}rm -rf /${NL}EOF"
t C allow bd - "cat > f <<EOF${NL}rm -rf /${NL}EOF"
t C allow bd - "cat > f <<\"EOF\"${NL}rm -rf /${NL}EOF"
t C allow bd - "cat > f <<-'EOF'${NL}${TAB}rm -rf /${NL}${TAB}EOF"
t C allow bd - "cat <<A <<B${NL}A${NL}rm -rf /${NL}B"
t C allow bd - "cat > f <<'EOF'${NL}rm -rf /${NL}EOF${NL}echo done"
t C allow bd - 'cd x && rm -rf node_modules'
t C allow bd - 'rm -rf node_modules > "/tmp/log"'
t C allow bd - 'rm -rf node_modules >/tmp/log'
t C allow bd - 'rm -rf node_modules 2>/tmp/err'
t C allow bd - 'rm -rf tmp && git status'
t C allow bd - 'command -v mkfs.ext4'
t C allow bd - 'type mkfs.ext4'
t C allow bd - 'ls -l /sbin/mkfs.ext4'
t C allow bd - 'test -x /sbin/mkfs.ext4'
t C allow bd - 'which rm'
t C allow bd - 'man rm'
t C allow bd - "printf '%s\\n' \"mk\\fs.ext4\""
t C allow bd - 'git commit -m "reset --hard"'
t C allow bd - 'git log --grep "clean -fdx"'
t C allow bd - 'git commit -m "chore: run git clean -fdx"'
t C allow bd - 'git rm -r --cached .'
t C allow bd - 'echo "$HOME"'
t C allow bd - 'cd / && ls'
t C allow bd - 'docker run --rm -it img sh'
t C allow bd - "printf '%s\\n' \${v:-rm -rf /}"
t C allow bd - 'echo $((1<<2))'
t C allow bd - 'echo foo # rm -rf /'
t C allow fp - 'git push origin main'
t C allow fp - 'git commit -m "git push --force" && git push origin x'
t C allow fp - 'echo "git push --force"'
t C allow fp - 'git log --oneline | grep push'

echo "[D] 意図した判定の変更（今の過検知を allow に直す・変更前では落ちる）"
t D allow bd - 'git clean -fd xdir'
t D allow bd - 'git clean -fdxn'
t D allow bd - 'git clean -fdx --dry-run'
t D allow bd - 'rm -rf node_modules # /'
t D allow bd - 'rm -rf node_modules >> /tmp/log 2>&1'
t D allow bd - 'rm -rf node_modules &> /tmp/log'
t D allow bd - 'mkfs.ext4'
t D allow fp - 'git push --force-with-lease # --force'

echo "[E] 終わること（閉じない構文・深い入れ子でも 0 か 2 に到達する）"
t E allow bd - 'echo "unclosed'
t E deny  bd rm-destructive 'rm -rf / "'
t E allow bd - 'echo $(true'
t E allow bd - "cat <<EOF${NL}no terminator here"
deep=''; i=0
while (( i < 300 )); do deep="($deep"; i=$((i + 1)); done
deep="${deep}echo x"; i=0
while (( i < 300 )); do deep="$deep)"; i=$((i + 1)); done
t E allow bd - "$deep"
many='rm -rf node_modules'; i=0
while (( i < 257 )); do many="$many \$(true)"; i=$((i + 1)); done
t E allow bd - "$many"
t E allow bd - 'eval eval eval eval eval eval eval eval echo x'

echo "=== RESULT: pass=${PASS} fail=${FAIL} ==="
i=0
while (( i < 5 )); do
  echo "  group ${GN[i]}: pass=${GP[i]} fail=${GF[i]}"
  i=$((i + 1))
done
[[ "$FAIL" -eq 0 ]]
