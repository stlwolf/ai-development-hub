#!/usr/bin/env bash
# shellcheck disable=SC2016  # BASH_VERSION は起動した bash の中で展開させる
set -euo pipefail

# test_session_name.sh — セッション名の hook（canonical/hooks/scripts/session-name.sh）が
# 出す sessionTitle を、payload と記録の組み合わせで固定する（#576）。
#
# hook には UserPromptSubmit の payload を標準入力で渡し、stdout を見る。stdout に出してよいのは
# jq で組んだ hookSpecificOutput の JSON 1つだけか、何も出さないかである（モデルの文脈に入るため）。
# HOME は一時ディレクトリにして、実物の ~/.claude/state を汚さない。
#
# 群の意味（plan の「確かめ方」）:
#   A 固定   — 今の hook の動き（T1〜T5）。変更の前でも後でも通る
#   B 統括   — 統括の名前の要求（T6〜T11）。変更の前の hook では落ちる
#
# 実行系: hook を起動する bash は HOOK_BASH（既定はこのテストを動かしている bash）。
#   bash tests/test_session_name.sh        # PATH の bash（5 系）
#   /bin/bash tests/test_session_name.sh   # 3.2
# 変更前のスクリプトに当てるときは HOOKS_DIR で scripts の置き場を差し替える。

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HOOKS_DIR="${HOOKS_DIR:-$REPO_ROOT/canonical/hooks/scripts}"
HB="${HOOK_BASH:-$BASH}"
SN="$HOOKS_DIR/session-name.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq required"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git required"; exit 0; }
[[ -f "$SN" ]] || { echo "FAIL: hook not found: $SN"; exit 1; }

_TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$_TMP_DIR"; }
trap cleanup EXIT
H="$_TMP_DIR/home"
mkdir -p "$H"

echo "hook: $SN"
echo "bash: $HB ($("$HB" -c 'echo "$BASH_VERSION"'))"

PASS=0; FAIL=0
GN=(A B); GP=(0 0); GF=(0 0)
gidx() { case "$1" in A) echo 0 ;; B) echo 1 ;; *) echo "bad group: $1" >&2; exit 1 ;; esac; }

ok() {
  local i; i="$(gidx "$1")"
  PASS=$((PASS + 1)); GP[i]=$((GP[i] + 1)); echo "  ok   [$1] $2"
}
ng() {
  local i; i="$(gidx "$1")"
  FAIL=$((FAIL + 1)); GF[i]=$((GF[i] + 1)); echo "  FAIL [$1] $2 — $3"
}

# 作業用のリポジトリ（名前は myrepo・既定のブランチは master）
REPO="$_TMP_DIR/myrepo"
git init -q "$REPO"
git -C "$REPO" symbolic-ref HEAD refs/heads/master
git -C "$REPO" -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m init

# tmux の記録の鍵（hook と wt-pane-issue.sh の決まり: <server の pid>_<pane> を英数字以外 _ に）
TMUX_VAL="/tmp/tmux-test/default,4242,0"
PANE="%77"
PANE_KEY="4242__77"

# hook を1回走らせる。
# run <session_id> <cwd> <今の session_title> [pane: 空なら tmux の外] [permission_mode] [prompt]
# 出力: 変数 OUT に stdout、RC に終了コード
run() {
  local sid="$1" cwd="$2" title="$3" pane="${4:-}" mode="${5:-default}" prompt="${6:-hello}"
  local payload
  payload="$(jq -cn --arg s "$sid" --arg c "$cwd" --arg t "$title" --arg m "$mode" --arg p "$prompt" \
    '{session_id:$s, cwd:$c, session_title:$t, permission_mode:$m, prompt:$p, hook_event_name:"UserPromptSubmit"}')"
  if [[ -n "$pane" ]]; then
    OUT="$(printf '%s' "$payload" | env -u CLAUDE_CODE_SESSION_ID HOME="$H" TMUX="$TMUX_VAL" TMUX_PANE="$pane" "$HB" "$SN" 2>/dev/null)" && RC=0 || RC=$?
  else
    OUT="$(printf '%s' "$payload" | env -u TMUX -u TMUX_PANE -u CLAUDE_CODE_SESSION_ID HOME="$H" "$HB" "$SN" 2>/dev/null)" && RC=0 || RC=$?
  fi
}

# 出した名前（何も出さなければ空）。stdout が空でも JSON 1つでもない形なら壊れとする
title_of() {
  [[ -z "$OUT" ]] && { printf ''; return 0; }
  printf '%s' "$OUT" | jq -er '.hookSpecificOutput | select(.hookEventName == "UserPromptSubmit") | .sessionTitle' 2>/dev/null \
    || printf '<<malformed>>'
}

# expect <群> <説明> <期待する名前（空 = 何も出さない）>
expect() {
  local group="$1" desc="$2" want="$3" got
  got="$(title_of)"
  if [[ "$RC" -ne 0 ]]; then ng "$group" "$desc" "rc=$RC"; return; fi
  if [[ "$got" == "$want" ]]; then ok "$group" "$desc"
  else ng "$group" "$desc" "want='${want}' got='${got}'"; fi
}

checkout() { git -C "$REPO" checkout -q -B "$1"; }

# same <群> <説明> <期待> <実際>
same() { if [[ "$4" == "$3" ]]; then ok "$1" "$2"; else ng "$1" "$2" "want='$3' got='$4'"; fi; }

echo "=== A: 今の hook の動き ==="

# T1: 要求も pane の記録も無い master のセッションは、リポジトリ名になる
checkout master
run sid-t1 "$REPO" ""
expect A "T1 名前の無い master のセッションはリポジトリ名" "myrepo"
run sid-t1 "$REPO" "myrepo"
expect A "T1 同じ名前なら何も出さない（冪等）" ""

# T2: pane の記録があるセッションは #<issue> <slug>。ずれたら毎回取り戻す
mkdir -p "$H/.claude/state/pane-issue"
printf '{"name":"#12 add-export"}' > "$H/.claude/state/pane-issue/$PANE_KEY"
run sid-t2 "$REPO" "" "$PANE"
expect A "T2 pane の記録の名前を付ける" "#12 add-export"
run sid-t2 "$REPO" "#12 add-export" "$PANE"
expect A "T2 同じ名前なら何も出さない" ""
run sid-t2 "$REPO" "my manual name" "$PANE"
expect A "T2 手で付けた名前からも取り戻す（sticky）" "#12 add-export"
run sid-t2 "$REPO" "" "$PANE" plan
expect A "T2 plan mode でも pane の記録の名前を付ける" "#12 add-export"
rm -f "$H/.claude/state/pane-issue/$PANE_KEY"

# T3: issue のブランチは #<issue> <slug>、それ以外のブランチはブランチ名
checkout 'feature/#34_add_thing'
run sid-t3a "$REPO" ""
expect A "T3 issue のブランチ" "#34 add-thing"
checkout 'topic-x'
run sid-t3b "$REPO" ""
expect A "T3 それ以外のブランチはブランチ名" "topic-x"

# T4: ブランチが変わったら改名する（手で付けた名前も上書き）
checkout master
run sid-t4 "$REPO" ""
expect A "T4 最初は master のリポジトリ名" "myrepo"
checkout 'feature/#56_next'
run sid-t4 "$REPO" "manual"
expect A "T4 ブランチが変わったら手で付けた名前も上書き" "#56 next"

# T5: 同じブランチで手で付けた名前は残す。plan mode と / で始まるプロンプトでは命名しない
checkout master
run sid-t5 "$REPO" ""
expect A "T5 最初の命名" "myrepo"
run sid-t5 "$REPO" "my manual name"
expect A "T5 同じブランチで手で付けた名前は残す" ""
run sid-t5b "$REPO" "" "" plan
expect A "T5 plan mode では命名しない" ""
run sid-t5c "$REPO" "" "" default "/rename foo"
expect A "T5 / で始まるプロンプトでは命名しない" ""
run sid-t5d "$REPO" "already named"
expect A "T5 初めて見る名前付きのセッションは名前を残す" ""

echo "=== B: 統括の名前の要求 ==="

# 書く側は engine の lib を使う（hook との約束の形を両側から確かめる）
# shellcheck source=../lib/session-title.sh
OE_SESSION_TITLE_DIR="$H/.claude/state/session-title" . "$SCRIPT_DIR/../lib/session-title.sh"
req() { OE_SESSION_TITLE_DIR="$H/.claude/state/session-title" oe_session_title_request "$1" "$2" "$3"; }

# 名前の決まり（DJ-1・H1）
checkout master
got="$(oe_session_title_supervisor_name "$REPO" 23)"
same B "名前: 代があれば cockpit <repo> gen<N>" "cockpit myrepo gen23" "$got"
got="$(oe_session_title_supervisor_name "$REPO" "")"
same B "名前: 代が無ければ cockpit <repo>" "cockpit myrepo" "$got"
git -C "$REPO" worktree add -q "$_TMP_DIR/myrepo.wt" -b wt-branch 2>/dev/null
got="$(oe_session_title_supervisor_name "$_TMP_DIR/myrepo.wt" 5)"
same B "名前: worktree の中からでも本体のリポジトリ名" "cockpit myrepo gen5" "$got"

# T6: 要求があるセッションは要求の名前になる。pane の記録が残っていても Path1 に戻らない
printf '{"name":"#12 add-export"}' > "$H/.claude/state/pane-issue/$PANE_KEY"
run sid-t6 "$REPO" "" "$PANE"
expect B "T6 前置き: 要求が無ければ pane の記録の名前" "#12 add-export"
req sid-t6 "LEASEA:1" "cockpit myrepo gen23"
run sid-t6 "$REPO" "#12 add-export" "$PANE"
expect B "T6 要求の名前に改名する" "cockpit myrepo gen23"
# T7: 同じ要求なら何もしない（pane の記録にも戻さない）
run sid-t6 "$REPO" "cockpit myrepo gen23" "$PANE"
expect B "T7 同じ要求なら何も出さない" ""
rm -f "$H/.claude/state/pane-issue/$PANE_KEY"

# T8: 同じ要求の ID のあいだは手で付けた名前を残す。新しい要求の ID が来たら改名する
req sid-t8 "LEASEB:1" "cockpit myrepo gen23"
run sid-t8 "$REPO" "myrepo"
expect B "T8 master のリポジトリ名から要求の名前へ" "cockpit myrepo gen23"
run sid-t8 "$REPO" "my manual name"
expect B "T8 同じ要求のあいだは手で付けた名前を残す" ""
req sid-t8 "LEASEB:2" "cockpit myrepo gen23"
run sid-t8 "$REPO" "my manual name"
expect B "T8 新しい要求の ID（同じ名前）で改名する" "cockpit myrepo gen23"
st="$(jq -r '.last_branch' "$H/.claude/state/session-branch/sid_t8.json" 2>/dev/null || echo '?')"
same B "T8 state の last_branch を残す" "master" "$st"

# T9: plan mode と / で始まるプロンプトでは改名せず、要求も消費しない
req sid-t9 "LEASEC:1" "cockpit myrepo gen7"
run sid-t9 "$REPO" "myrepo" "" plan
expect B "T9 plan mode では改名しない" ""
run sid-t9 "$REPO" "myrepo" "" default "/clear"
expect B "T9 / で始まるプロンプトでは改名しない" ""
run sid-t9 "$REPO" "myrepo"
expect B "T9 次の普通のプロンプトで改名する" "cockpit myrepo gen7"

# T10: 壊れた要求は無視して今の動きになる
mkdir -p "$H/.claude/state/session-title"
printf 'not json' > "$H/.claude/state/session-title/sid_t10a.json"
run sid-t10a "$REPO" ""
expect B "T10 JSON でない要求は無視（Path2）" "myrepo"
printf '{"format":1,"request_id":"X:1","name":""}' > "$H/.claude/state/session-title/sid_t10b.json"
run sid-t10b "$REPO" ""
expect B "T10 name が空の要求は無視（Path2）" "myrepo"
printf '{"format":1,"request_id":7,"name":"cockpit x"}' > "$H/.claude/state/session-title/sid_t10c.json"
run sid-t10c "$REPO" ""
expect B "T10 request_id が文字列でない要求は無視（Path2）" "myrepo"

# T11: 名前の制御文字は除かれる
req sid-t11 "LEASED:1" "$(printf 'cockpit\033[31m my\nrepo')"
run sid-t11 "$REPO" ""
expect B "T11 制御文字を除く" "cockpit[31m myrepo"

# 要求の書き手は、足りない引数で書かない
if req "" "X:1" "n"; then ng B "書き手: session_id が空なら書かない" "rc=0"; else ok B "書き手: session_id が空なら書かない"; fi

echo "=== RESULT: pass=${PASS} fail=${FAIL} ==="
i=0
while (( i < 2 )); do
  echo "  group ${GN[i]}: pass=${GP[i]} fail=${GF[i]}"
  i=$((i + 1))
done
[[ "$FAIL" -eq 0 ]]
