#!/usr/bin/env bash
#
# session-name.sh — Claude Code UserPromptSubmit hook.
#
# Gives every session an identifiable name (shown in Claude's UI and written to
# the tmux pane title), so parallel sessions — and the notifications built from
# the pane title (notify.sh) — can be told apart. Two behaviors, in priority:
#
#   1. Active issue worktree: when wt-pane-issue.sh recorded "#<issue> <slug>"
#      for this tmux pane (on `wt switch`), title the session with it, once per
#      switch (the "pending" flag is consumed). An issue pane is handled here
#      and NEVER falls through to the fallback below (which would clobber it).
#   2. Fallback (unnamed, non-issue): Claude's built-in auto-naming only fires
#      on plan-accept or `/rename`, so a plain session can stay nameless. If the
#      session has no name yet and is not in plan mode, name it from the first
#      prompt (or, if that's empty, the repository directory name). A per-session
#      marker makes this set-once regardless of whether the hook-set title shows
#      up in a later payload, and works with or without tmux.
#
# `sessionTitle` is a documented hookSpecificOutput field for UserPromptSubmit
# (Claude Code hooks reference), verified live. UserPromptSubmit stdout is
# injected into the model context, so this emits ONLY a single hookSpecificOutput
# JSON object (built with jq), or nothing. No diagnostics to stdout.
#
set -uo pipefail

payload="$(cat 2>/dev/null || true)"
home="${HOME:-}"
[ -n "$home" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

state_dir="${home}/.claude/state/pane-issue"

# Emit a sessionTitle and exit. Nothing but this JSON reaches stdout; on jq
# failure emit nothing. The prompt is already control-char-stripped and kept
# valid UTF-8 (iconv), and jq --arg JSON-escapes it. With a marker path ($2),
# touch it only on a successful emit so the fallback stays set-once.
emit_title() {
  local out
  out="$(jq -cn --arg t "$1" \
    '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",sessionTitle:$t}}' 2>/dev/null)" || exit 0
  [ -n "$out" ] || exit 0
  if [ -n "${2:-}" ]; then : > "$2" 2>/dev/null || true; fi
  printf '%s' "$out"
  exit 0
}

# --- 1) Active issue worktree (tmux pane keyed; recorded by wt-pane-issue.sh) ---
pane="${TMUX_PANE:-}"
if [ -n "$pane" ]; then
  server="${TMUX:-}"; server="${server#*,}"; server="${server%%,*}"
  key="${server}_${pane}"; key="${key//[^A-Za-z0-9]/_}"
  state_file="${state_dir}/${key}"
  if [ -f "$state_file" ]; then
    # Issue pane: Path 1 owns naming and must not fall through to the fallback.
    if [ "$(jq -r '.pending // false' "$state_file" 2>/dev/null)" = "true" ]; then
      name="$(jq -r '.name // empty' "$state_file" 2>/dev/null)"
      if [ -n "$name" ]; then
        tmp="${state_file}.tmp.$$"
        if jq -c '.pending=false' "$state_file" >"$tmp" 2>/dev/null; then
          mv -f "$tmp" "$state_file" 2>/dev/null || rm -f "$tmp" 2>/dev/null
        fi
        emit_title "$name"
      fi
    fi
    exit 0
  fi
fi

# --- 2) Fallback: name an unnamed, non-issue session on its first prompt ---
# Respect an existing name (manual /rename, plan-accept) and plan mode.
[ -z "$(printf '%s' "$payload" | jq -r '.session_title // ""' 2>/dev/null || true)" ] || exit 0
[ "$(printf '%s' "$payload" | jq -r '.permission_mode // ""' 2>/dev/null || true)" != "plan" ] || exit 0

# Set-once via a per-session marker (session_id keyed) — independent of payload
# round-trip, and works without tmux.
sid="$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null || true)"
[ -n "$sid" ] || exit 0
mkdir -p "$state_dir" 2>/dev/null || exit 0
marker="${state_dir}/$(printf '%s' "$sid" | tr -c 'A-Za-z0-9' '_').named"
[ -f "$marker" ] && exit 0

prompt="$(printf '%s' "$payload" | jq -r '.prompt // ""' 2>/dev/null || true)"
# Don't name a session after a slash command (e.g. /rename, /clear).
case "$prompt" in /*) exit 0 ;; esac

# Prefer the first prompt: drop control chars, collapse whitespace, keep
# multibyte as-is (no ASCII slugging — it would erase Japanese), truncate to
# ~80 bytes on a UTF-8 boundary (iconv -c trims a clipped trailing char).
fallback="$(printf '%s' "$prompt" | tr '\n\r\t' '   ' | tr -d '\000-\037' | sed 's/  */ /g; s/^ *//; s/ *$//' 2>/dev/null || true)"
fallback="$(printf '%s' "$fallback" | head -c 80 | { iconv -f UTF-8 -t UTF-8 -c 2>/dev/null || cat; })"
fallback="$(printf '%s' "$fallback" | sed 's/ *$//' 2>/dev/null || true)"

# If the prompt yielded nothing usable, fall back to the repo directory name
# (payload cwd is the launch repo root; stable identifier — dotfiles#17 finding).
if [ -z "$fallback" ]; then
  cwd="$(printf '%s' "$payload" | jq -r '.cwd // ""' 2>/dev/null || true)"
  [ -n "$cwd" ] && fallback="$(basename "$cwd" 2>/dev/null || true)"
fi
[ -n "$fallback" ] || exit 0

emit_title "$fallback" "$marker"
