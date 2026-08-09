#!/usr/bin/env bash
set -euo pipefail

# test_hook_firing.sh — 止める側のフックの発火記録・trap 収束・#310 の非回帰（#309 / #310）。
#
# 実 tmux もホストのフック配線も不要（スクリプトへ payload を stdin で流すだけ）。
# ツール判別は $0 に依存するので、配備と同じ symlink 構成を作って叩く。
#
# 対象は canonical/hooks/scripts の3本。**3本の共通区間が byte 一致していること**を
# 機械的に確かめるのが本テストの主目的のひとつである。三重化のドリフトを
# 規律ではなく落ちるテストで止める（設計SO の指摘）。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HOOKS_DIR="$REPO_ROOT/canonical/hooks/scripts"
OE_HOOKFIRE="$(cd "$SCRIPT_DIR/.." && pwd)/bin/oe-hookfire"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }

_TMP_DIR="$(mktemp -d)"
cleanup() {
  # FIFO を作るので rm の前に通常ファイル化しておく必要はないが、念のため -f で消す
  chmod -R u+w "$_TMP_DIR" 2>/dev/null || true
  rm -rf "$_TMP_DIR"
}
trap cleanup EXIT

PASS=0
FAIL=0
ck() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $label"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (want=[$expected] got=[$actual])"; FAIL=$((FAIL + 1))
  fi
}

# 配備と同じ形（~/.<tool>/hooks/<name>.sh の symlink）を作る。$0 がここになる。
mk_deploy() {
  local root="$1" tool="$2" f
  mkdir -p "$root/.$tool/hooks"
  for f in block-destructive block-force-push cc-lint; do
    ln -sf "$HOOKS_DIR/$f.sh" "$root/.$tool/hooks/$f.sh"
  done
}

# フックを1回叩いて rc を返す。$3 に PATH、$4 に shopt 前置きを渡せる。
fire() { # fire <deployed-script> <command> [PATH] [dir]
  local script="$1" cmd="$2" path="${3:-$PATH}" dir="${4:-$_TMP_DIR/state}"
  jq -cn --arg c "$cmd" '{tool_input:{command:$c}}' \
    | env PATH="$path" HOOK_FIRING_DIR="$dir" CLAUDE_PROJECT_DIR=/tmp bash "$script" >/dev/null 2>&1 \
    && printf '0' || printf '%s' "$?"
}
fire_out() { # 標準出力だけを返す
  local script="$1" cmd="$2" path="${3:-$PATH}" dir="${4:-$_TMP_DIR/state}"
  jq -cn --arg c "$cmd" '{tool_input:{command:$c}}' \
    | env PATH="$path" HOOK_FIRING_DIR="$dir" CLAUDE_PROJECT_DIR=/tmp bash "$script" 2>/dev/null || true
}

DEPLOY="$_TMP_DIR/home"
mk_deploy "$DEPLOY" claude
mk_deploy "$DEPLOY" cursor
mk_deploy "$DEPLOY" codex
BD="$DEPLOY/.claude/hooks/block-destructive.sh"
FP="$DEPLOY/.claude/hooks/block-force-push.sh"
CL="$DEPLOY/.claude/hooks/cc-lint.sh"

echo "[1] 3本の共通区間が byte 一致する（三重化のドリフト検出）"
sums=""
for f in block-destructive block-force-push cc-lint; do
  s="$(sed -n '/shared begin/,/shared end/p' "$HOOKS_DIR/$f.sh" | shasum | awk '{print $1}')"
  sums="${sums}${s}\n"
done
uniq_n="$(printf "%b" "$sums" | sort -u | grep -c .)"
ck "shared 区間が3本で一致" "1" "$uniq_n"

echo "[2] 判定の非回帰（allow / deny が変わっていない）"
ck "block-destructive allow" "0" "$(fire "$BD" 'echo hello')"
ck "block-destructive safe rm" "0" "$(fire "$BD" 'rm -rf node_modules')"
ck "block-destructive deny"  "2" "$(fire "$BD" 'git reset --hard')"
ck "block-force-push allow"  "0" "$(fire "$FP" 'git push origin main')"
ck "block-force-push lease"  "0" "$(fire "$FP" 'git push --force-with-lease origin x')"
ck "block-force-push deny"   "2" "$(fire "$FP" 'git push --force origin main')"
ck "cc-lint valid CC"        "0" "$(fire "$CL" 'git commit -m "docs: ok"')"
ck "cc-lint non-commit &&"   "0" "$(fire "$CL" 'cd /tmp && ls')"
ck "cc-lint invalid CC"      "2" "$(fire "$CL" 'git commit -m "bad msg"')"

echo "[3] #310: inherit_errexit が有効でも 0/2 以外を返さない"
for cmd in 'cd /tmp && ls' 'echo a && echo b' 'make build && make test' 'cd x && git -C . commit -m "bad"'; do
  rc="$(jq -cn --arg c "$cmd" '{tool_input:{command:$c}}' \
        | env HOOK_FIRING_DIR="$_TMP_DIR/state" CLAUDE_PROJECT_DIR=/tmp \
          bash -c "shopt -s inherit_errexit; $(cat "$HOOKS_DIR/cc-lint.sh")" >/dev/null 2>&1 && printf '0' || printf '%s' "$?")"
  case "$rc" in 0|2) ck "inherit_errexit on: [$cmd]" "$rc" "$rc" ;; *) ck "inherit_errexit on: [$cmd]" "0 or 2" "$rc" ;; esac
done

echo "[4] allow と deny の両方が記録される"
ck "allow tally" "1" "$([ -s "$_TMP_DIR/state/tally/claude/block-destructive.allow" ] && echo 1 || echo 0)"
ck "deny tally"  "1" "$([ -s "$_TMP_DIR/state/tally/claude/block-destructive.deny" ] && echo 1 || echo 0)"
ck "deny.jsonl に rule がある" "1" \
  "$(jq -rR 'fromjson? | select(.rule=="git-reset-hard") | 1' "$_TMP_DIR/state/deny.jsonl" 2>/dev/null | head -1)"
ck "deny.jsonl に生コマンドが無い" "0" \
  "$(grep -c 'reset --hard' "$_TMP_DIR/state/deny.jsonl" 2>/dev/null || true)"

echo "[5] ツール判別（\$0 が配備パスなので tool 別に分かれる）"
fire "$DEPLOY/.cursor/hooks/block-destructive.sh" 'echo hello' >/dev/null
fire "$DEPLOY/.codex/hooks/block-destructive.sh" 'echo hello' >/dev/null
for t in claude cursor codex; do
  ck "tally/$t が出来る" "1" "$([ -d "$_TMP_DIR/state/tally/$t" ] && echo 1 || echo 0)"
done

echo "[6] 要求Aとその鏡（記録先が書けなくても判定は変わらない）"
RO="$_TMP_DIR/readonly"; mkdir -p "$RO"; chmod 0500 "$RO"
ck "書けなくても allow は通る" "0" "$(fire "$BD" 'echo hello' "$PATH" "$RO/x")"
ck "書けなくても deny は止める" "2" "$(fire "$BD" 'git reset --hard' "$PATH" "$RO/x")"
chmod 0700 "$RO"

echo "[7] FIFO ガード（記録先を FIFO にしても deny が exit 2 に届く）"
FIFO_DIR="$_TMP_DIR/fifo"; mkdir -p "$FIFO_DIR/tally/claude"
mkfifo "$FIFO_DIR/tally/claude/block-destructive.deny"
rc="$(timeout 10 bash -c "
  jq -cn '{tool_input:{command:\"git reset --hard\"}}' \
    | env HOOK_FIRING_DIR='$FIFO_DIR' CLAUDE_PROJECT_DIR=/tmp bash '$BD' >/dev/null 2>&1; echo \$?" || echo TIMEOUT)"
ck "FIFO でも deny は rc=2" "2" "$rc"
rm -f "$FIFO_DIR/tally/claude/block-destructive.deny"

echo "[8] jq 不在は具体的なメッセージで deny する（trap の汎用文にしない）"
BARE="$_TMP_DIR/bare"; mkdir -p "$BARE"
for b in bash cat printf env grep sed date mkdir; do
  s="$(command -v "$b" 2>/dev/null)" && ln -sf "$s" "$BARE/$b"
done
out="$(fire_out "$BD" 'echo hello' "$BARE" "$_TMP_DIR/state-nojq")"
ck "jq 不在で rc=2" "2" "$(fire "$BD" 'echo hello' "$BARE" "$_TMP_DIR/state-nojq")"
ck "jq 不在のメッセージが具体的" "1" \
  "$(printf '%s' "$out" | grep -c 'jq is required' || true)"

echo "[9] HOME も HOOK_FIRING_DIR も無いなら記録を諦める（/.claude へ書きに行かない）"
rc="$(jq -cn '{tool_input:{command:"echo hello"}}' \
      | env -u HOME -u HOOK_FIRING_DIR CLAUDE_PROJECT_DIR=/tmp bash "$BD" >/dev/null 2>&1 && printf '0' || printf '%s' "$?")"
ck "HOME 無しでも allow は通る" "0" "$rc"
ck "/.claude を作っていない" "0" "$([ -d /.claude ] && echo 1 || echo 0)"

echo "[10] oe-hookfire: サイズ 0 の tally を発火と読まない"
Z="$_TMP_DIR/zero"; mkdir -p "$Z/tally/claude"
: > "$Z/tally/claude/block-destructive.allow"
out="$(HOOK_FIRING_DIR="$Z" bash "$OE_HOOKFIRE" 2>&1 || true)"
ck "サイズ0 は ok にしない" "0" "$(printf '%s' "$out" | grep -c 'ok             fire/claude/block-destructive' || true)"

echo "[11] oe-hookfire: 内部エラーの窓は行の ts で切る"
W="$_TMP_DIR/win"; mkdir -p "$W/tally/claude"; printf 'x' > "$W/tally/claude/cc-lint.allow"
printf '{"ts":"2020-01-01T00:00:00Z","rule":"internal-error"}\n' > "$W/deny.jsonl"
out="$(HOOK_FIRING_DIR="$W" bash "$OE_HOOKFIRE" 2>&1 || true)"
ck "古い internal-error は broken にしない" "1" \
  "$(printf '%s' "$out" | grep -c 'ok             internal-error' || true)"
printf '{"ts":"%s","rule":"internal-error"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$W/deny.jsonl"
out="$(HOOK_FIRING_DIR="$W" bash "$OE_HOOKFIRE" 2>&1 || true)"
ck "直近の internal-error は broken" "1" \
  "$(printf '%s' "$out" | grep -c 'broken         internal-error' || true)"

echo "[12] oe-hookfire: indeterminate を exit 0 にしない"
E="$_TMP_DIR/empty"
HOOK_FIRING_DIR="$E" bash "$OE_HOOKFIRE" >/dev/null 2>&1 && rc=0 || rc=$?
ck "記録が無いとき exit=2" "2" "$rc"

echo "[13] deny.jsonl が FIFO でも deny は exit 2 に到達する（要求Aの鏡）"
FD="$_TMP_DIR/fifo-deny"; mkdir -p "$FD"; mkfifo "$FD/deny.jsonl"
rc="$(timeout 10 bash -c "
  jq -cn '{tool_input:{command:\"git reset --hard\"}}' \
    | env HOOK_FIRING_DIR='$FD' CLAUDE_PROJECT_DIR=/tmp bash '$BD' >/dev/null 2>&1; echo \$?" || echo TIMEOUT)"
ck "deny.jsonl FIFO でも rc=2" "2" "$rc"
rm -f "$FD/deny.jsonl"

echo "[14] diag.jsonl が FIFO + tally 書けない でも allow は通る（要求A）"
GD="$_TMP_DIR/fifo-diag"; mkdir -p "$GD/tally"; chmod 0500 "$GD/tally"; mkfifo "$GD/diag.jsonl"
rc="$(timeout 10 bash -c "
  jq -cn '{tool_input:{command:\"echo hello\"}}' \
    | env HOOK_FIRING_DIR='$GD' CLAUDE_PROJECT_DIR=/tmp bash '$BD' >/dev/null 2>&1; echo \$?" || echo TIMEOUT)"
ck "diag.jsonl FIFO でも allow は rc=0" "0" "$rc"
chmod 0700 "$GD/tally"; rm -f "$GD/diag.jsonl"

echo "[15] malformed payload は deny へ収束し、記録も残る"
MP="$_TMP_DIR/malformed"
rc="$(printf 'not json\n' | env HOOK_FIRING_DIR="$MP" CLAUDE_PROJECT_DIR=/tmp bash "$BD" >/dev/null 2>&1 && printf '0' || printf '%s' "$?")"
ck "malformed payload で rc=2" "2" "$rc"
ck "malformed でも記録が残る" "1" "$([ -s "$MP/tally/claude/block-destructive.deny" ] && echo 1 || echo 0)"

echo "[16] oe-hookfire --days に値が無くても無限ループしない"
timeout 5 bash "$OE_HOOKFIRE" --days >/dev/null 2>&1 && rc=0 || rc=$?
ck "--days 値なしで 124(timeout) にならない" "1" "$([ "$rc" != 124 ] && echo 1 || echo 0)"

echo "[17] oe-hookfire: ツールが丸ごと欠けていたら indeterminate にする"
ONE="$_TMP_DIR/onetool"; mkdir -p "$ONE/tally/claude"
for h in block-destructive block-force-push cc-lint; do printf 'x' > "$ONE/tally/claude/$h.allow"; done
HOOK_FIRING_DIR="$ONE" bash "$OE_HOOKFIRE" >/dev/null 2>&1 && rc=0 || rc=$?
ck "cursor/codex 欠落なら exit 0 にしない" "1" "$([ "$rc" != 0 ] && echo 1 || echo 0)"
out="$(HOOK_FIRING_DIR="$ONE" bash "$OE_HOOKFIRE" 2>&1 || true)"
n_missing="$(printf '%s\n' "$out" | grep -c 'fire/cursor\|fire/codex' || true)"
ck "欠落した cursor / codex が行として出る" "2" "$n_missing"

echo "=== RESULT: pass=${PASS} fail=${FAIL} ==="
[[ "$FAIL" -eq 0 ]]
