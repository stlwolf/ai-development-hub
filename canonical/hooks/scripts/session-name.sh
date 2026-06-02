#!/usr/bin/env bash
#
# session-name.sh — Claude Code UserPromptSubmit hook.
#
# Gives every session an identifiable name (shown in Claude's UI and written to
# the tmux pane title), so parallel sessions — and the notifications built from
# the pane title (notify.sh) — can be told apart. Two behaviors, in priority:
#
#   1. Active issue worktree: when wt-pane-issue.sh recorded "#<issue> <slug>"
#      for this tmux pane (on `wt switch`), title the session with it. Emitted
#      once per switch (the "pending" flag is consumed) so a later manual
#      /rename is preserved.
#   2. Fallback (unnamed, non-issue): Claude's built-in auto-naming only fires
#      on plan-accept or `/rename`, so a plain session can stay nameless. If the
#      session has no name yet (payload `session_title` empty) and is not in
#      plan mode, derive a simple name from the first prompt. Once named, the
#      payload's session_title is non-empty on later prompts, so this is a
#      natural set-once that respects plan-accept / manual renames.
#
# `sessionTitle` is a documented hookSpecificOutput field for UserPromptSubmit
# (Claude Code hooks reference) and was verified live. UserPromptSubmit stdout
# is injected into the model context, so this emits ONLY a single
# hookSpecificOutput JSON object (built with jq), or nothing. No diagnostics to
# stdout.
#
set -uo pipefail

payload="$(cat 2>/dev/null || true)"

pane="${TMUX_PANE:-}"
home="${HOME:-}"
[ -n "$pane" ] || exit 0
[ -n "$home" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# Emit a sessionTitle and exit. Nothing but this JSON ever reaches stdout; if jq
# fails (e.g. invalid UTF-8 after truncation) emit nothing.
emit_title() {
  local out
  out="$(jq -cn --arg t "$1" \
    '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",sessionTitle:$t}}' 2>/dev/null)" || exit 0
  [ -n "$out" ] && printf '%s' "$out"
  exit 0
}

# --- 1) Active issue worktree (recorded by wt-pane-issue.sh) ---
# Key by tmux server PID + pane id (restart-safe), identical to wt-pane-issue.sh.
server="${TMUX:-}"; server="${server#*,}"; server="${server%%,*}"
key="${server}_${pane}"; key="${key//[^A-Za-z0-9]/_}"
state_file="${home}/.claude/state/pane-issue/${key}"

if [ -f "$state_file" ] && [ "$(jq -r '.pending // false' "$state_file" 2>/dev/null)" = "true" ]; then
  name="$(jq -r '.name // empty' "$state_file" 2>/dev/null)"
  if [ -n "$name" ]; then
    # Consume pending (one-shot per switch). A concurrent `wt switch` between
    # read and write is a rare lost-update; re-emit of the same title is benign.
    tmp="${state_file}.tmp.$$"
    if jq -c '.pending=false' "$state_file" >"$tmp" 2>/dev/null; then
      mv -f "$tmp" "$state_file" 2>/dev/null || rm -f "$tmp" 2>/dev/null
    fi
    emit_title "$name"
  fi
fi

# --- 2) Fallback: name an unnamed, non-issue session from its first prompt ---
# Skip when already named (session_title present) or in plan mode (let
# plan-accept name it from the plan).
[ -z "$(printf '%s' "$payload" | jq -r '.session_title // ""' 2>/dev/null || true)" ] || exit 0
[ "$(printf '%s' "$payload" | jq -r '.permission_mode // ""' 2>/dev/null || true)" != "plan" ] || exit 0

prompt="$(printf '%s' "$payload" | jq -r '.prompt // ""' 2>/dev/null || true)"
# Drop control chars, collapse whitespace; keep multibyte as-is (no ASCII
# slugging — it would erase Japanese prompts). Truncate to ~80 bytes at a valid
# UTF-8 boundary (iconv -c drops a clipped trailing multibyte char).
fallback="$(printf '%s' "$prompt" | tr '\n\r\t' '   ' | tr -d '\000-\037' | sed 's/  */ /g; s/^ *//; s/ *$//')"
fallback="$(printf '%s' "$fallback" | head -c 80 | { iconv -f UTF-8 -t UTF-8 -c 2>/dev/null || cat; })"
fallback="$(printf '%s' "$fallback" | sed 's/ *$//')"
[ -n "$fallback" ] || exit 0
emit_title "$fallback"
