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

# フックを起動する実行系。既定はこのテストを動かしている bash（$BASH）。
# 裸の `bash` で起動すると PATH の bash（5 系）になり、外側を /bin/bash（3.2）で
# 回しても対象は 3.2 で試されない（#429 の設計SO の指摘）。
HB="${HOOK_BASH:-$BASH}"

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
    | env PATH="$path" HOOK_FIRING_DIR="$dir" CLAUDE_PROJECT_DIR=/tmp "$HB" "$script" >/dev/null 2>&1 \
    && printf '0' || printf '%s' "$?"
}
fire_out() { # 標準出力だけを返す
  local script="$1" cmd="$2" path="${3:-$PATH}" dir="${4:-$_TMP_DIR/state}"
  jq -cn --arg c "$cmd" '{tool_input:{command:$c}}' \
    | env PATH="$path" HOOK_FIRING_DIR="$dir" CLAUDE_PROJECT_DIR=/tmp "$HB" "$script" 2>/dev/null || true
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
# #429: 行に含まれる各コマンドを取り出す区間（shared-cmd）は、止める側の2本で byte 一致させる。
sums=""
for f in block-destructive block-force-push; do
  s="$(sed -n '/shared-cmd begin/,/shared-cmd end/p' "$HOOKS_DIR/$f.sh" | shasum | awk '{print $1}')"
  sums="${sums}${s}\n"
done
uniq_n="$(printf "%b" "$sums" | sort -u | grep -c .)"
ck "shared-cmd 区間が2本で一致" "1" "$uniq_n"
ck "shared-cmd 区間が空でない" "1" "$(sed -n '/shared-cmd begin/,/shared-cmd end/p' "$HOOKS_DIR/block-destructive.sh" | grep -c 'cmd_analyze()' || true)"

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
if "$HB" -c 'shopt -s inherit_errexit' 2>/dev/null; then
for cmd in 'cd /tmp && ls' 'echo a && echo b' 'make build && make test' 'cd x && git -C . commit -m "bad"'; do
  rc="$(jq -cn --arg c "$cmd" '{tool_input:{command:$c}}' \
        | env HOOK_FIRING_DIR="$_TMP_DIR/state" CLAUDE_PROJECT_DIR=/tmp \
          "$HB" -c "shopt -s inherit_errexit; $(cat "$HOOKS_DIR/cc-lint.sh")" >/dev/null 2>&1 && printf '0' || printf '%s' "$?")"
  case "$rc" in 0|2) ck "inherit_errexit on: [$cmd]" "$rc" "$rc" ;; *) ck "inherit_errexit on: [$cmd]" "0 or 2" "$rc" ;; esac
done
else
  echo "  SKIP: この bash に inherit_errexit が無い（4.4 未満）"
fi

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
    | env HOOK_FIRING_DIR='$FIFO_DIR' CLAUDE_PROJECT_DIR=/tmp '$HB' '$BD' >/dev/null 2>&1; echo \$?" || echo TIMEOUT)"
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
      | env -u HOME -u HOOK_FIRING_DIR CLAUDE_PROJECT_DIR=/tmp "$HB" "$BD" >/dev/null 2>&1 && printf '0' || printf '%s' "$?")"
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
    | env HOOK_FIRING_DIR='$FD' CLAUDE_PROJECT_DIR=/tmp '$HB' '$BD' >/dev/null 2>&1; echo \$?" || echo TIMEOUT)"
ck "deny.jsonl FIFO でも rc=2" "2" "$rc"
rm -f "$FD/deny.jsonl"

echo "[14] diag.jsonl が FIFO + tally 書けない でも allow は通る（要求A）"
GD="$_TMP_DIR/fifo-diag"; mkdir -p "$GD/tally"; chmod 0500 "$GD/tally"; mkfifo "$GD/diag.jsonl"
rc="$(timeout 10 bash -c "
  jq -cn '{tool_input:{command:\"echo hello\"}}' \
    | env HOOK_FIRING_DIR='$GD' CLAUDE_PROJECT_DIR=/tmp '$HB' '$BD' >/dev/null 2>&1; echo \$?" || echo TIMEOUT)"
ck "diag.jsonl FIFO でも allow は rc=0" "0" "$rc"
chmod 0700 "$GD/tally"; rm -f "$GD/diag.jsonl"

echo "[15] malformed payload は deny へ収束し、記録も残る"
MP="$_TMP_DIR/malformed"
rc="$(printf 'not json\n' | env HOOK_FIRING_DIR="$MP" CLAUDE_PROJECT_DIR=/tmp "$HB" "$BD" >/dev/null 2>&1 && printf '0' || printf '%s' "$?")"
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

echo "[18] exit 契約: help と呼び方の誤りを broken（1）の帯から外す（#309 残件）"
# **これは「全部の判定帯から切り離した」ではない。** 2 はいまも indeterminate の帯で
# あり、呼び方の誤りはそこへ相乗りする（共有は承知のうえの妥協で、分離は #301 待ち）。
# 下の assertion もそう読むこと。2 を期待している行は「broken ではない」までしか
# 言っておらず、「indeterminate と区別できる」とは言っていない。
# **番号を表として固定する。** 分離が #301 で決まったとき何が動くのかを機械で分かる
# 形にしておく。
OE_SELFCHECK="$(cd "$SCRIPT_DIR/.." && pwd)/bin/oe-selfcheck"
rc_of() { # rc_of <script> [args...] — exit code だけを返す
  bash "$@" >/dev/null 2>&1 && printf '0' || printf '%s' "$?"
}
for v in "$OE_HOOKFIRE" "$OE_SELFCHECK"; do
  n="$(basename "$v")"
  [[ -x "$v" ]] || { echo "  SKIP: $n 不在"; continue; }
  ck "$n --help は 0（成功であって broken ではない）" "0" "$(rc_of "$v" --help)"
  ck "$n -h は 0"                              "0" "$(rc_of "$v" -h)"
  ck "$n unknown option は 2"                  "2" "$(rc_of "$v" --bogus)"
  ck "$n 余分な位置引数は 2"                    "2" "$(rc_of "$v" extra)"
  # 位置引数の後ろの option が読まれずに判定へ進む経路を塞いだことの確認。
  ck "$n 位置引数の後ろに --help があっても 2"  "2" "$(rc_of "$v" extra --help)"
done
ck "oe-hookfire --days 値なしは 2" "2" "$(rc_of "$OE_HOOKFIRE" --days)"
ck "oe-hookfire --days 非整数は 2" "2" "$(rc_of "$OE_HOOKFIRE" --days xyz)"
# indeterminate の帯（2）は据え置き（#301 へ保留した争点）。[12] が indeterminate→2 を
# 固定しており、ここではそれが CLI 衛生の変更で動いていないことだけを見る。
# **この行が 2 を期待するのと、上で呼び方の誤りが 2 を期待するのは、同じ番号である。**
# それが共有された帯の実体で、区別が要るなら stderr か --json を読む必要がある。
E2="$_TMP_DIR/empty-contract"; mkdir -p "$E2"
ck "oe-hookfire 記録なし（indeterminate）は 2 のまま" "2" \
   "$(HOOK_FIRING_DIR="$E2" bash "$OE_HOOKFIRE" >/dev/null 2>&1 && printf '0' || printf '%s' "$?")"

echo "[19] oe-hookfire: diag.jsonl・deny.jsonl を読めないときに「0 件」で ok にしない（#530）"
# 中身は今日の ts の失敗と internal-error を1行ずつ。読めれば broken になる内容なので、
# ok が出たら「読めなかった」が 0 件に化けている。期待は ok でも broken でもなく indeterminate。
# 起動は $HB で行う（外側を /bin/bash で回したときに対象も 3.2 で試すため）。
hf_row() { # hf_row <dir> <name> — その検査の判定（ok / broken / indeterminate）を返す
  HOOK_FIRING_DIR="$1" "$HB" "$OE_HOOKFIRE" --json 2>/dev/null \
    | jq -r --arg n "$2" '.[] | select(.name == $n) | .verdict'
}
UR="$_TMP_DIR/unreadable"; mkdir -p "$UR/tally/claude"; printf 'x' > "$UR/tally/claude/cc-lint.allow"
now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '{"ts":"%s","err":"x"}\n' "$now" > "$UR/diag.jsonl"
printf '{"ts":"%s","rule":"internal-error"}\n' "$now" > "$UR/deny.jsonl"
ck "読めれば record-health は broken（fixture の確認）" "broken" "$(hf_row "$UR" record-health)"
ck "読めれば internal-error は broken（fixture の確認）" "broken" "$(hf_row "$UR" internal-error)"
if [ "$(id -u)" = "0" ]; then
  echo "  SKIP: root では chmod 000 でも読めるので権限の場合を作れない"
else
  chmod 000 "$UR/diag.jsonl" "$UR/deny.jsonl"
  ck "chmod 000 の diag.jsonl で record-health は indeterminate" "indeterminate" "$(hf_row "$UR" record-health)"
  ck "chmod 000 の deny.jsonl で internal-error は indeterminate" "indeterminate" "$(hf_row "$UR" internal-error)"
  chmod 600 "$UR/diag.jsonl" "$UR/deny.jsonl"
fi
DL="$_TMP_DIR/dangling"; mkdir -p "$DL/tally/claude"; printf 'x' > "$DL/tally/claude/cc-lint.allow"
ln -s "$_TMP_DIR/no-such-file" "$DL/diag.jsonl"; ln -s "$_TMP_DIR/no-such-file" "$DL/deny.jsonl"
ck "壊れた symlink の diag.jsonl で record-health は indeterminate" "indeterminate" "$(hf_row "$DL" record-health)"
ck "壊れた symlink の deny.jsonl で internal-error は indeterminate" "indeterminate" "$(hf_row "$DL" internal-error)"
ck "壊れた symlink を「無い」と書かない" "0" \
  "$(HOOK_FIRING_DIR="$DL" "$HB" "$OE_HOOKFIRE" 2>/dev/null | grep -c 'deny.jsonl が無い\|記録されていない' || true)"
# 置き場のディレクトリに検索権限が無いと -e が偽になり、「無い」に落ちる（実装SO の指摘）。
if [ "$(id -u)" != "0" ]; then
  NX="$_TMP_DIR/noexec"; mkdir -p "$NX/tally/claude"; printf 'x' > "$NX/tally/claude/cc-lint.allow"
  printf '{"ts":"%s","err":"x"}\n' "$now" > "$NX/diag.jsonl"
  chmod 0600 "$NX"
  ck "置き場を辿れないとき record-health は indeterminate" "indeterminate" "$(hf_row "$NX" record-health)"
  chmod 0700 "$NX"
  # 直上でなく祖先を辿れないときも同じ（Copilot の指摘）。
  NA="$_TMP_DIR/noexec-ancestor"; mkdir -p "$NA/fire/tally/claude"
  printf '{"ts":"%s","err":"x"}\n' "$now" > "$NA/fire/diag.jsonl"
  chmod 0600 "$NA"
  ck "祖先を辿れないとき record-health は indeterminate" "indeterminate" "$(hf_row "$NA/fire" record-health)"
  chmod 0700 "$NA"
fi
# 置き場そのものが無いときは「無い」のまま（record-health は ok）。
ck "置き場が無いときの record-health は ok のまま" "ok" "$(hf_row "$_TMP_DIR/no-such-fire-dir" record-health)"
# ファイルが無いときの判定は変えていない（record-health は ok・internal-error は indeterminate）。
NL="$_TMP_DIR/nologs"; mkdir -p "$NL/tally/claude"; printf 'x' > "$NL/tally/claude/cc-lint.allow"
ck "diag.jsonl が無いときの record-health は ok のまま" "ok" "$(hf_row "$NL" record-health)"
ck "deny.jsonl が無いときの internal-error は indeterminate のまま" "indeterminate" "$(hf_row "$NL" internal-error)"

echo "[20] oe-hookfire: unknown の記録は窓で切る（古い1件で永久に broken にしない・#529）"
UK="$_TMP_DIR/unknown-window"; mkdir -p "$UK/tally/claude" "$UK/tally/unknown"
for h in block-destructive block-force-push cc-lint; do printf 'x' > "$UK/tally/claude/$h.allow"; done
printf 'x' > "$UK/tally/unknown/block-destructive.allow"
touch -t 202601010000 "$UK/tally/unknown/block-destructive.allow"
ck "窓の外の unknown だけなら tool-attribution は ok" "ok" "$(hf_row "$UK" tool-attribution)"
out="$(HOOK_FIRING_DIR="$UK" "$HB" "$OE_HOOKFIRE" 2>/dev/null || true)"
ck "窓の外でも累計の件数を表に出す" "1" \
  "$(printf '%s\n' "$out" | grep -c 'tool-attribution.*累計 1 ファイル・計 1 件' || true)"
ck "fire/unknown/* の行を出さない" "0" "$(printf '%s\n' "$out" | grep -c 'fire/unknown' || true)"
ck "cross-check/unknown の行を出さない" "0" "$(printf '%s\n' "$out" | grep -c 'cross-check/unknown' || true)"
touch "$UK/tally/unknown/block-destructive.allow"
ck "窓の中の unknown があれば broken" "broken" "$(hf_row "$UK" tool-attribution)"
# サイズ 0 は記録ではない（2節と同じ）。窓の中で 0 なら truncate か書き込みの失敗なので、
# broken にも ok にもしない。
: > "$UK/tally/unknown/block-destructive.allow"
ck "窓の中でサイズ 0 だけなら indeterminate" "indeterminate" "$(hf_row "$UK" tool-attribution)"
if [ "$(id -u)" != "0" ]; then
  printf 'x' > "$UK/tally/unknown/block-destructive.allow"
  chmod 000 "$UK/tally/unknown"
  ck "unknown を読めないときは indeterminate（0 件に潰さない）" "indeterminate" "$(hf_row "$UK" tool-attribution)"
  chmod 700 "$UK/tally/unknown"
fi
# 窓で切ると、数え方の取りこぼしが ok に化ける（変更前は在るだけで broken だった）。実装SO の指摘。
UK2="$_TMP_DIR/unknown-paths"; mkdir -p "$UK2/tally/claude"
for h in block-destructive block-force-push cc-lint; do printf 'x' > "$UK2/tally/claude/$h.allow"; done
mkdir -p "$UK2/tally/unknown"
ck "空の unknown ディレクトリは ok" "ok" "$(hf_row "$UK2" tool-attribution)"
# ファイル名に改行を含む最近の記録
printf 'x' > "$UK2/tally/unknown/a
b.allow"
ck "改行を含むファイル名の最近の記録で broken" "broken" "$(hf_row "$UK2" tool-attribution)"
rm -f "$UK2/tally/unknown/a
b.allow"
# symlink の先へ追記された最近の記録（ファイルの symlink・ディレクトリの symlink）
mkdir -p "$UK2/real"; printf 'x' > "$UK2/real/cc-lint.allow"
ln -s "$UK2/real/cc-lint.allow" "$UK2/tally/unknown/cc-lint.allow"
ck "ファイルの symlink の先の最近の記録で broken" "broken" "$(hf_row "$UK2" tool-attribution)"
rm -rf "$UK2/tally/unknown"; ln -s "$UK2/real" "$UK2/tally/unknown"
ck "ディレクトリの symlink の先の最近の記録で broken" "broken" "$(hf_row "$UK2" tool-attribution)"
rm -f "$UK2/tally/unknown"; ln -s "$UK2/no-such-dir" "$UK2/tally/unknown"
ck "壊れた symlink の unknown は indeterminate" "indeterminate" "$(hf_row "$UK2" tool-attribution)"
rm -f "$UK2/tally/unknown"
# unknown の下の tally が壊れた symlink（Copilot の指摘）。-L でも辿れず数えられない。
mkdir -p "$UK2/tally/unknown"; ln -s "$UK2/no-such-file" "$UK2/tally/unknown/cc-lint.allow"
ck "unknown の下の壊れた symlink は indeterminate" "indeterminate" "$(hf_row "$UK2" tool-attribution)"
rm -rf "$UK2/tally/unknown"
if [ "$(id -u)" != "0" ]; then
  mkdir -p "$UK2/tally/unknown"; printf 'x' > "$UK2/tally/unknown/cc-lint.allow"
  chmod 600 "$UK2/tally"
  ck "unknown の祖先を辿れないときは indeterminate" "indeterminate" "$(hf_row "$UK2" tool-attribution)"
  chmod 700 "$UK2/tally"
fi

echo "=== RESULT: pass=${PASS} fail=${FAIL} ==="
[[ "$FAIL" -eq 0 ]]
