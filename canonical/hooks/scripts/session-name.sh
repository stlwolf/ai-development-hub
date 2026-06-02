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
#      on plan-accept or `/rename`, so a plain session can stay nameless. Name
#      it after the repository directory (payload cwd) — NOT the prompt text:
#      the title propagates to the tmux pane title and OS notifications, so
#      prompt content (which may contain secrets) must not leak there. A
#      per-session marker in a dedicated dir (not touched by wt-pane-issue.sh's
#      pane-issue GC) makes this set-once.
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
# failure emit nothing. jq --arg JSON-escapes the title. With a marker path
# ($2), touch it only on a successful emit so the fallback stays set-once.
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

# --- 2) Fallback: name an unnamed, non-issue session after its repository ---
# Respect an existing name (manual /rename, plan-accept) and plan mode.
[ -z "$(printf '%s' "$payload" | jq -r '.session_title // ""' 2>/dev/null || true)" ] || exit 0
[ "$(printf '%s' "$payload" | jq -r '.permission_mode // ""' 2>/dev/null || true)" != "plan" ] || exit 0

# Don't preempt a manual /rename: skip when the prompt is a slash command. (We
# only inspect the first character; the prompt text is never used as the name.)
case "$(printf '%s' "$payload" | jq -r '.prompt // ""' 2>/dev/null || true)" in /*) exit 0 ;; esac

# Set-once via a per-session marker (session_id keyed) in a DEDICATED dir so the
# pane-issue GC in wt-pane-issue.sh can't delete it. A long-window GC here bounds
# growth without clobbering live sessions.
sid="$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null || true)"
[ -n "$sid" ] || exit 0
named_dir="${home}/.claude/state/session-named"
marker="${named_dir}/$(printf '%s' "$sid" | tr -c 'A-Za-z0-9' '_').named"
# Already fallback-named this session → short-circuit before any dir scan
# (repeat turns when session_title keeps coming through empty hit this).
[ -f "$marker" ] && exit 0

# Name = repository directory (payload cwd is the launch repo root). Using the
# repo name — not prompt text — keeps secrets out of the pane title / OS
# notifications. Strip control chars and keep it short / valid UTF-8.
cwd="$(printf '%s' "$payload" | jq -r '.cwd // ""' 2>/dev/null || true)"
[ -n "$cwd" ] || exit 0
fallback="$(basename "$cwd" 2>/dev/null || true)"
fallback="$(printf '%s' "$fallback" | tr -d '\000-\037' | head -c 80 | { iconv -f UTF-8 -t UTF-8 -c 2>/dev/null || cat; })"
[ -n "$fallback" ] || exit 0

# About to create a marker — run the opportunistic stale-marker GC now (not on
# every prompt; the marker check above already short-circuited repeat turns).
mkdir -p "$named_dir" 2>/dev/null || exit 0
find "$named_dir" -maxdepth 1 -type f -mmin +43200 -delete 2>/dev/null || true
emit_title "$fallback" "$marker"
