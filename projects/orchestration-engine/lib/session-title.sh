# shellcheck shell=bash
# session-title.sh — 統括のセッション名の「要求」を、session_id ごとに書く（#576・source 専用）
#
# 統括は既定のブランチで動くので、セッション名の hook（canonical/hooks/scripts/session-name.sh）の
# ブランチの道がリポジトリ名を付け、`claude --resume` の一覧で統括を見分けられない。席を取る verb
# （oe-handoff take・oe-register root）が、席を取ったあとにこの lib で名前の要求を書き、hook は次の
# プロンプトでそれを読んで一度だけ改名する。hook が知るのはこの記録の形だけで、lease の形は知らない。
#
# 記録の形（hook との約束・canonical/hooks/README.md の「session-name.sh + wt-pane-issue.sh」節）:
#   ~/.claude/state/session-title/<session_id を英数字以外 _ に直したもの>.json
#   {"format":1,"request_id":"<lease_id>:<generation>","name":"<名前>","requested_at":"<ISO 時刻>"}
#   request_id は同じ席の再試行では同じ値、新しく席を取れば新しい値にする。hook は request_id が
#   前に適用したものと違うときだけ改名し、同じあいだは手で付けた名前を尊重する。
#
# 名前の決まり（plan の DJ-1・H1）: `cockpit <リポジトリ名> gen<N>`。代が分からなければ `cockpit <リポジトリ名>`。
#
# 置き場の env: OE_SESSION_TITLE_DIR（テスト用。hook は ~/.claude/state/session-title だけを読むので、
#   実際の運用では変えない）
#
# 戻り値: 0 書いた / 2 呼び方の誤り・前提の不足（置き場が無い・jq が無い・書けない）

declare -F _oe_home_usable >/dev/null 2>&1 || _oe_home_usable() { case "${HOME:-}" in /|//) return 1;; /*) return 0;; *) return 1;; esac; }
if   [ -n "${OE_SESSION_TITLE_DIR+x}" ]; then :
elif _oe_home_usable; then OE_SESSION_TITLE_DIR="${HOME}/.claude/state/session-title"
else                       OE_SESSION_TITLE_DIR=""
fi

# oe_session_title_supervisor_name <cwd> [<generation>]
# 統括の名前を出す。リポジトリ名は cwd の git のトップのディレクトリ名（git でなければ cwd の名前）。
# worktree の中から呼ばれても、名前は本体のリポジトリの名前にする（git の共通ディレクトリの親）。
oe_session_title_supervisor_name() {
  local cwd="${1:-}" gen="${2:-}" top common repo
  [ -n "$cwd" ] || return 2
  common="$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  if [ -n "$common" ] && [ "$(basename "$common")" = ".git" ]; then
    repo="$(basename "$(dirname "$common")")"
  else
    top="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)"
    repo="$(basename "${top:-$cwd}")"
  fi
  [ -n "$repo" ] || return 2
  case "$gen" in
    ''|*[!0-9]*) printf 'cockpit %s' "$repo" ;;
    *)           printf 'cockpit %s gen%s' "$repo" "$gen" ;;
  esac
}

# oe_session_title_has_request <session_id> <request_id>
# 同じ request_id の「hook が受け付ける」要求がすでにあれば 0。oe-register root が、take の書いた
# 代つきの名前を代なしの名前で上書きしないために使う（take は中で oe-register root を呼ぶ）。
# 判定は hook と同じにする: JSON のオブジェクトがちょうど1つで、request_id と name が文字列で、
# 制御文字を除いても name が残る。hook が無視する壊れた要求を「ある」と扱うと、root を打ち直しても
# 名前を戻せなくなる（Copilot の指摘・PR #599）。
oe_session_title_has_request() {
  local sid="${1:-}" rid="${2:-}" key file obj name
  [ -n "$sid" ] && [ -n "$rid" ] && [ -n "$OE_SESSION_TITLE_DIR" ] || return 1
  key="$(printf '%s' "$sid" | tr -c 'A-Za-z0-9' '_')"
  file="${OE_SESSION_TITLE_DIR}/${key}.json"
  [ -f "$file" ] || return 1
  obj="$(jq -cs 'if length == 1 and (.[0] | type) == "object"
                   and (.[0].request_id | type) == "string" and (.[0].name | type) == "string"
                 then .[0] else empty end' "$file" 2>/dev/null || true)"
  [ -n "$obj" ] || return 1
  [ "$(printf '%s' "$obj" | jq -r '.request_id' 2>/dev/null || true)" = "$rid" ] || return 1
  name="$(printf '%s' "$obj" | jq -r '.name' 2>/dev/null | tr -d '\000-\037\177')"
  [ -n "$name" ]
}

# oe_session_title_request <session_id> <request_id> <name>
# 名前の要求を書く（tmp に書いて mv で置き換える）。同じ request_id でも上書きしてよい（再試行）。
oe_session_title_request() {
  local sid="${1:-}" rid="${2:-}" name="${3:-}" key file tmp now
  [ -n "$sid" ] && [ -n "$rid" ] && [ -n "$name" ] || return 2
  [ -n "$OE_SESSION_TITLE_DIR" ] || return 2
  command -v jq >/dev/null 2>&1 || return 2
  mkdir -p "$OE_SESSION_TITLE_DIR" 2>/dev/null || return 2
  key="$(printf '%s' "$sid" | tr -c 'A-Za-z0-9' '_')"
  file="${OE_SESSION_TITLE_DIR}/${key}.json"
  tmp="${file}.tmp.$$"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  jq -cn --arg r "$rid" --arg n "$name" --arg t "$now" \
    '{format:1, request_id:$r, name:$n, requested_at:$t}' >"$tmp" 2>/dev/null || { rm -f "$tmp"; return 2; }
  mv -f "$tmp" "$file" 2>/dev/null || { rm -f "$tmp"; return 2; }
  return 0
}
